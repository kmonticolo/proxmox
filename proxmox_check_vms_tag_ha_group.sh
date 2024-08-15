#!/bin/bash
TAG="carp"
# Wyniki pierwszej komendy (numery VM)
vm_numbers=$(grep -Rilw "$TAG" /etc/pve/nodes/pve*|xargs basename -a | sed 's/.conf//')

groups=$(ha-manager groupconfig | sed -e 's/^[ \t]*//')

# Wyniki trzeciej komendy (VM -> węzeł)
services=$(ha-manager status)

# Krok 1: Mapowanie numerów VM na węzły
declare -A vm_to_node

while IFS= read -r line; do
  if [[ $line =~ service\ vm:([0-9]+)\ \(([^,]+),\ started\) ]]; then
    vm="${BASH_REMATCH[1]}"
    node="${BASH_REMATCH[2]}"
    vm_to_node["$vm"]="$node"
  fi
done <<< "$services"

# Zbieranie węzłów dla VM z pierwszej komendy
nodes=()
while IFS= read -r vm; do
  if [[ -n "${vm_to_node[$vm]}" ]]; then
    nodes+=("${vm_to_node[$vm]}")
  else
    echo "Nie znaleziono węzła dla VM $vm"
    exit 1
  fi
done <<< "$vm_numbers"

# Krok 2: Tworzenie mapy grup do węzłów
declare -A group_to_nodes
declare -A node_to_group
current_group=""

while IFS= read -r line; do
  if [[ $line == group:* ]]; then
    current_group=$(echo "$line" | awk '{print $2}')
  elif [[ $line == nodes* ]]; then
    nodes_list=$(echo "$line" | awk '{print $2}' | tr ',' ' ')
    group_to_nodes["$current_group"]="${nodes_list[@]}"
  for node in ${nodes_list}; do
    node_to_group["$node"]="$current_group"
  done
  fi
done <<< "$groups"

## Krok 3: Sprawdzanie, czy węzły należą do tej samej grupy
same_group="no"

for group in "${!group_to_nodes[@]}"; do
  group_nodes_list=(${group_to_nodes[$group]})

  
  # Sprawdzenie, czy oba węzły są w tej samej grupie
  if [[ " ${group_nodes_list[@]} " =~ " ${nodes[0]} " && " ${group_nodes_list[@]} " =~ " ${nodes[1]} " ]]; then
    same_group="yes"
    break
  fi
done

group1="${node_to_group[${nodes[0]}]}"
group2="${node_to_group[${nodes[1]}]}"

# Wynik
if [ "$same_group" == "yes" ]; then
  echo "UWAGA: Węzły ${nodes[0]} i ${nodes[1]} należą do tej samej grupy: $group1."
  exit 1
else
  echo "OK: Węzły ${nodes[0]} i ${nodes[1]} należą do różnych grup. Wszystko jest w porządku."
fi
