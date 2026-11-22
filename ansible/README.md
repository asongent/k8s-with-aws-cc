# Self-Hosted Kubernetes on AWS with Cloud Controller Manager(CCM) Integration

This repository automates the end-to-end provisioning and configuration of a self-hosted Kubernetes cluster on AWS EC2 using `kubeadm`, Calico CNI, the external AWS `CCM`, and the AWS `EBS CSI Driver`.

It supports two distinct topologies out of the box:
* **`Development` (`playbooks/site.yml`):** Single `control-plane node + worker nodes`.
* **`Production` (`playbooks/ha.yml`):** Highly available `multi-master control plane` behind an AWS Network Load Balancer (NLB) + worker nodes.

---

## Directory Structure

```text
ansible/
├── README.md                              # Project documentation (this file)
├── environments/                          # Environment-specific configurations & inventories
│   ├── dev/                               # Single-master development cluster
│   │   ├── ansible.cfg                    # Dev SSH key, user, inventory, and roles_path settings
│   │   ├── deploy.sh                      # Pre-flight connectivity check + playbook runner
│   │   ├── group_vars/
│   │   │   └── all.yml                    # Kubernetes, Calico, and CIDR variables
│   │   └── inventory.ini                  # Single master + worker host definitions
│   └── prod-ha/                           # Multi-master High Availability (HA) cluster
│       ├── ansible.cfg                    # Prod SSH key, user, inventory, and roles_path settings
│       ├── deploy.md                      # Prod deployment runbook / notes
│       ├── group_vars/
│       │   └── all.yml                    # Cluster variables + AWS NLB control_plane_endpoint
│       └── inventory.ini                  # 3+ masters + worker host definitions
├── playbooks/                             # Top-level orchestration playbooks
│   ├── site.yml                           # Single-master cluster lifecycle playbook
│   └── ha.yml                             # Multi-master HA cluster lifecycle playbook
└── roles/                                 # Modular, reusable Ansible roles
    ├── common/                            # OS prep: hostnames, swapoff, kernel modules, sysctl, base packages
    │   └── tasks/main.yml
    ├── containerd/                        # Containerd runtime installation & systemd cgroup setup
    │   ├── handlers/main.yml
    │   └── tasks/main.yml
    ├── k8s-binaries/                      # Kubernetes APT repo + cri-tools, kubelet, kubeadm, kubectl (held)
    │   ├── handlers/main.yml
    │   └── tasks/main.yml
    ├── control-plane/                     # Bootstraps primary master, Calico CNI, Helm CLI, and AWS CCM
    │   ├── tasks/main.yml
    │   └── templates/kubeadm.yml.j2
    ├── ha/                                # Joins secondary control-plane nodes (master[1:]) using uploaded certs
    │   ├── tasks/main.yml
    │   └── templates/kubeadm-master-join.yml.j2
    ├── worker-nodes/                      # Generates join token on primary master & joins workers with EC2 provider-id
    │   └── tasks/main.yml
    └── storage/                           # Installs AWS EBS CSI Driver via Helm & creates default gp3 StorageClass
        └── tasks/main.yml
```

---

## Prerequisites

Before running either deployment, ensure the following are in place on your `bastion/control machine`:

1. **AWS Infrastructure Provisioned (via Terraform):**
   * VPC with private subnets for control-plane/worker nodes and public subnet(s) tagged `kubernetes.io/role/elb = 1` for internet-facing LoadBalancers.
   * EC2 instances tagged with `"kubernetes.io/cluster/kubernetes" = "owned"` and attached to IAM roles granting EC2, ELB, and EBS permissions.
   * Security Groups allowing internal cluster traffic, `30000–32767` NodePort traffic on workers, and TCP `6443` on control-plane nodes.
   * *(For `prod-ha` only)* An AWS Network Load Balancer (NLB) listening on TCP `6443` forwarding to all control-plane nodes.

2. **Ansible Control Node Dependencies:**

   ```bash
   ansible-galaxy collection install kubernetes.core community.general
   pip install kubernetes PyYAML jsonpatch
   ```
3. **SSH Key Access:** Your private key (e.g., `~/.ssh/newgen.pem`) is present with `chmod 400` permissions.

---

## Execution Lifecycle Overview

Both playbooks execute in strict dependency order so that networking and AWS cloud integration are active before nodes join or storage drivers deploy:

| Stage | Playbook Target | Role(s) | Purpose |
| :--- | :--- | :--- | :--- |
| **1. OS Prep** | `all` | `common` | Sets hostnames, disables swap, loads `overlay`/`br_netfilter`, applies `sysctl` rules. |
| **2. Runtime & Tools** | `kubernetes` | `containerd`, `k8s-binaries` | Configures `containerd` (`SystemdCgroup = true`) and installs `kubelet`, `kubeadm`, `kubectl`. |
| **3. Primary Control Plane** | `master[0]` | `control-plane` | Runs `kubeadm init`, installs Calico CNI, installs Helm, and deploys AWS CCM (`hostNetwork: true`). |
| **4. HA Masters** *(HA only)* | `master[1:]` | `ha` | Uploads control-plane certs on `master[0]` and joins secondary masters to the control plane. |
| **5. Worker Registration** | `workers` | `worker-nodes` | Fetches EC2 `provider-id`, generates join token on `master[0]`, and runs `kubeadm join`. |
| **6. Cluster Storage** | `master[0]` | `storage` | Deploys AWS EBS CSI Driver via Helm and creates default `ebs-sc` (`gp3`) `StorageClass`. |

---

## Deployment Guide: `dev` Environment (Single Master)

Use the `dev` environment for single-master clusters where the API server endpoint defaults directly to the primary master's private IP (`<master-ip>:6443`).

### 1. Configure Inventory (`environments/dev/inventory.ini`)
Populate the private IP addresses of your master and worker EC2 instances:

```ini
[master]
control-plane ansible_host=192.168.1.10 hostname=control-plane

[workers]
node-01 ansible_host=192.168.2.11 hostname=node-01
node-02 ansible_host=192.168.2.12 hostname=node-02

[kubernetes:children]
master
workers
```

### 2. Review Variables (`environments/dev/group_vars/all.yml`)
Update the [Kubernetes repository, Kubernetes](https://kubernetes.io/releases/), and [Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises) versions here if needed. Keep the default `pod_subnet` and `service_subnet` CIDRs as-is unless they conflict with your AWS VPC CIDR. This `192.168.0.0/16` is network CIDR used in this deployment

```yaml
k8s_repo_version: "v1.36"
k8s_version: "v1.36.4"
pod_subnet: "10.244.0.0/16"
service_subnet: "10.96.0.0/12"
calico_version: "v3.33.1"
```


### 3. Run the Deployment
Navigate into `environments/dev` so Ansible automatically loads the local `ansible.cfg`:

```bash
cd environments/dev
chmod +x deploy.sh
./deploy.sh
```

*(Alternatively, run the commands manually:)*
```bash
cd environments/dev
ansible-inventory --graph
ansible all -m ping
ansible-playbook ../../playbooks/site.yml
```

---

## Deployment Guide: `prod-ha` Environment (Multi-Master HA)

Use the `prod-ha` environment when deploying **3 or more control-plane nodes** behind an AWS Network Load Balancer.

### 1. Configure Inventory (`environments/prod-ha/inventory.ini`)
List all control-plane nodes under `[master]`. Ansible treats the first host (`master[0]`) as the primary bootstrap node and `master[1:]` as secondary HA masters:

```ini
[master]
master-01 ansible_host=192.168.1.10 hostname=master-01
master-02 ansible_host=192.168.1.11 hostname=master-02
master-03 ansible_host=192.168.1.12 hostname=master-03

[workers]
node-01 ansible_host=192.168.2.11 hostname=node-01
node-02 ansible_host=192.168.2.12 hostname=node-02
node-03 ansible_host=192.168.2.13 hostname=node-03

[kubernetes:children]
master
workers
```

### 2. Configure the Load Balancer Endpoint (`environments/prod-ha/group_vars/all.yml`)
Review and update [Kubernetes repository, Kubernetes](https://kubernetes.io/releases/), and [Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/self-managed-onprem/onpremises) versions here if needed. Keep the default `pod_subnet` and `service_subnet` CIDRs as-is unless they conflict with your AWS VPC CIDR. This `192.168.0.0/16` is network CIDR used in this deployment.
Set `control_plane_endpoint` to your AWS NLB DNS name and port `6443`:

```yaml
k8s_repo_version: "v1.36"
k8s_version: "v1.36.4"
pod_subnet: "10.244.0.0/16"
service_subnet: "10.96.0.0/12"
calico_version: "v3.33.1"

# Required for HA: AWS NLB DNS routing TCP 6443 to all control-plane nodes
control_plane_endpoint: "://amazonaws.com"
```

### 3. Run the HA Deployment
Navigate into `environments/prod-ha` so Ansible loads the production `ansible.cfg` and `group_vars`:

```bash
cd environments/prod-ha
ansible-inventory --graph
ansible all -m ping
ansible-playbook ../../playbooks/ha.yml
```

---

## Post-Deployment Verification

SSH into your primary master node (or run via Ansible ad-hoc commands) to verify cluster health:

```bash
# 1. Verify all control-plane and worker nodes are Ready (AWS CCM removed uninitialized taints)
kubectl get nodes -o wide

# 2. Verify system pods (Calico, CoreDNS, AWS CCM, EBS CSI Controller/Node) are Running
kubectl get pods -n kube-system

# 3. Verify the default gp3 StorageClass is active
kubectl get sc
```

---

## Day-2 Operations: Scaling Worker Nodes

To add new worker instances to an existing cluster:
1. Provision the new EC2 instance(s) in your data-plane subnet.
2. Add the new host entry under `[workers]` in `environments/<env>/inventory.ini`.
3. Run the playbook limited to the new host(s) (or re-run the full playbook safely, as all roles are idempotent):
   ```bash
   cd environments/dev   # or environments/prod-ha
   ansible-playbook ../../playbooks/site.yml --limit node-05
   ```





<!-- ### Using Role Approach

This playbook breaks down cleanly into 4 modular Ansible roles (common, containerd, Control-plane, and Data-plane) plus a site.yml master playbook. Splitting it this way separates host-level OS prep from runtime configuration, control plane initialization, and CNI/CSI add-ons—making it easy to add worker nodes later without re-running master tasks.

1. Recommended Directory Structure

Below is recommended folder ftructure. 

```bash
ansible/
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


 -->
