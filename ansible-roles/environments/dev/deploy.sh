#!/bin/bash
set -euo pipefail

echo "=== 1. Verifying Ansible Inventory ==="
ansible-inventory --graph

echo "=== 2. Testing Host Connectivity ==="
if ! ansible all -m ping; then
  echo "ERROR: One or more hosts are unreachable. Aborting deployment."
  exit 1
fi

echo "=== 3. Running Kubernetes Playbook ==="
ansible-playbook ../../playbooks/site.yml

