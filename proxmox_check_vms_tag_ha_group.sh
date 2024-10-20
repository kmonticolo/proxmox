#!/bin/bash
# kmonticolo 15.8.24
# The script detects by the given tag in proxmox hosts that should be in separate HA groups.
# VMs are distributed on nodes and the script detects when hosts are placed in the same HA group
# can be used as a ha script to move vmks with the same tag to separate groups

TAG="carp"
# First command results (VM numbers)
vm_numbers=$(grep -Rilw "$TAG" /etc/pve/nodes/pve*|xargs basename -a | sed 's/.conf//')

groups=$(ha-manager groupconfig | sed -e 's/^[ \t]*//')

# Results of the third command (VM -> node)
services=$(ha-manager status)

# Step 1: Map VM numbers to nodes
declare -A vm_to_node

while IFS= read -r line; do
  if [[ $line =~ service\ vm:([0-9]+)\ \(([^,]+),\ started\) ]]; then
    vm="${BASH_REMATCH[1]}"
    node="${BASH_REMATCH[2]}"
    vm_to_node["$vm"]="$node"
  fi
done <<< "$services"

# Gathering nodes for VM from the first command
nodes=()
while IFS= read -r vm; do
  if [[ -n "${vm_to_node[$vm]}" ]]; then
    nodes+=("${vm_to_node[$vm]}")
  else
    echo "Nie znaleziono węzła dla VM $vm"
    exit 1
  fi
done <<< "$vm_numbers"

# Step 2: Create a map of groups to nodes
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

# Step 3: Checking whether the nodes belong to the same group.
same_group="no"

for group in "${!group_to_nodes[@]}"; do
  group_nodes_list=(${group_to_nodes[$group]})

# Checking whether both nodes are in the same group
  if [[ " ${group_nodes_list[@]} " =~ " ${nodes[0]} " && " ${group_nodes_list[@]} " =~ " ${nodes[1]} " ]]; then
    same_group="yes"
    break
  fi
done

group1="${node_to_group[${nodes[0]}]}"
group2="${node_to_group[${nodes[1]}]}"

# Result
if [ "$same_group" == "yes" ]; then
  echo "UWAGA: Węzły ${nodes[0]} i ${nodes[1]} należą do tej samej grupy: $group1."
  exit 1
else
  echo "OK: Węzły ${nodes[0]} i ${nodes[1]} należą do różnych grup. Wszystko jest w porządku."
fi
