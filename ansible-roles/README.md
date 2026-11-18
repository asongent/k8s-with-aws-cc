### Using Role Approach

This playbook breaks down cleanly into 4 modular Ansible roles (common, containerd, Control-plane, and Data-plane) plus a site.yml master playbook. Splitting it this way separates host-level OS prep from runtime configuration, control plane initialization, and CNI/CSI add-ons—making it easy to add worker nodes later without re-running master tasks.

1. Recommended Directory Structure

Below is recommended folder ftructure. 

```bash
ansible-roles/
├── site.yml
├── group_vars/
│   └── all.yml
└── roles/
    ├── common/          # OS prep, swap, kernel modules, sysctl
    ├── containerd/      # Container runtime & systemd cgroups
    ├── k8s-binaries/    # kubelet, kubeadm, kubectl (renamed from data-plane for clarity)
    ├── control-plane/   # kubeadm init, Calico CNI, AWS Cloud Controller Manager
    ├── worker-nodes/    # Fetch join token & join workers to the cluster
    └── storage/         # AWS EBS CSI Driver & ebs-sc StorageClass
```
2.  (`site.yml`) & Variables (`group_vars/all.yml)` are Master Playbook.  `group_vars/all.yml`  holsds centralize versions and CIDRs so you don't hunt through tasks later. 

3. `roles/common/tasks/main.yml` handles `hostnames`, `swap`, `kernel modules`, `sysctl parameters`, and base APT packages.

4. `roles/containerd/tasks/main.yml` and `roles/containerd/handlers/main.yml` isolates the container runtime installation and systemd cgroup configuration.

5. `roles/data-plane/tasks/main.yml` and `roles/data-plane/handlers/main.yml` installs kubelet, kubeadm, and kubectl on both master and worker nodes.

5. `roles/control-plane/tasks/main.yml` and 5. `roles/control-plane/templates/kubeadm.yml.j2` move the kubeadm config into a clean Jinja2 template and initializes the control plane. *(Note: Your pasted snippet truncated right at - nam after downloading Calico—you can drop your Calico apply, AWS CCM, and your EBS CSI Driver + ebs-sc StorageClass tasks right at the bottom of tasks/main.yml.)*



