# Self-Hosted Kubernetes on AWS — Terraform Infrastructure Guide

This repository provisions the underlying AWS cloud infrastructure required to run a self-hosted Kubernetes cluster (with AWS Cloud Controller Manager and EBS CSI Driver integration).

It is organized into reusable modules and supports two isolated environments:
* **`Development`:** Single control-plane node + worker nodes + bastion workstation.
* **`Production`:** Multi-master High Availability (HA) control plane fronted by an internal AWS Network Load Balancer (NLB) + worker nodes + bastion workstation.

---

## Directory Structure

```text
terraform-infra/
├── README.md                              # Project documentation (this file)
├── environments/                          # Isolated environment root modules
│   ├── dev/                               # Single-master development infrastructure
│   │   ├── main.tf                        # Wires vpc, subnets, security_groups, iam, and servers modules
│   │   ├── outputs.tf                     # Exposes master/worker private IPs and workstation public IP
│   │   ├── providers.tf                   # AWS provider and Terraform version constraints
│   │   ├── terraform.tfvars               # Dev environment values (CIDRs, counts, AZ, key pair)
│   │   └── variables.tf                   # Input variable declarations for dev
│   └── prod-ha/                           # Multi-master High Availability (HA) infrastructure
│       ├── main.tf                        # Wires shared modules with 3+ control-plane nodes
│       ├── nlb.tf                         # Internal AWS Network Load Balancer (TCP 6443) for API server HA
│       ├── outputs.tf                     # Exposes NLB control_plane_endpoint DNS + node IPs
│       ├── providers.tf                   # AWS provider and Terraform version constraints
│       ├── terraform.tfvars               # Prod HA values (control_plane_count = 3, CIDRs, key pair)
│       └── variables.tf                   # Input variable declarations for prod-ha
└── modules/                               # Reusable infrastructure building blocks
    ├── aws-ccm-policy.json                # IAM policy JSON for AWS Cloud Controller Manager
    ├── policies.json                      # IAM policy JSON for EBS CSI Driver and node permissions
    ├── vpc/                               # VPC (`192.168.0.0/16`) and Internet Gateway
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── subnets/                           # Public workstation/ELB subnet, private control/data subnets, NAT GW & routes
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── security_groups/                   # Control-plane, data-plane (incl. NodePorts 30000–32767), and workstation SGs
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    ├── iam/                               # IAM roles, policies, and EC2 instance profiles for cluster nodes
    │   ├── main.tf
    │   ├── outputs.tf
    │   └── variables.tf
    └── servers/                           # Ubuntu 24.04 EC2 instances (workstation, master-01..N, node-01..N)
        ├── main.tf
        ├── outputs.tf
        └── variables.tf
```

---

## Architecture & Module Overview

| Module | Resources Created | Kubernetes Integration Details |
| :--- | :--- | :--- |
| **`vpc`** | VPC (`192.168.0.0/16`) + Internet Gateway | Provides isolated private networking with DNS hostnames/resolution enabled. |
| **`subnets`** | 3 Subnets (`control-plane`, `data-plane`, `workstation`), NAT Gateway, Route Tables | Tags public subnet with `kubernetes.io/role/elb = 1` and private subnets with `kubernetes.io/cluster/kubernetes = owned` so AWS CCM places LoadBalancers accurately. |
| **`security_groups`** | 3 Security Groups + intra-cluster ingress rules | Opens API server (`6443`), `etcd` (`2379–2380`), `kubelet` (`10250`), Calico BGP (`179`), and external NodePorts (`30000–32767`). |
| **`iam`** | IAM Role, Policy Attachments, Instance Profile | Grants EC2 instances permissions to manage ELBs/NLBs (AWS CCM) and EBS volumes (EBS CSI). |
| **`servers`** | Ubuntu 24.04 EC2 Instances | Tags all cluster instances with `"kubernetes.io/cluster/kubernetes" = "owned"` and `"kubernetes.io/role/internal-elb" = "1"`. |
| **`nlb.tf`** *(prod-ha)* | Internal AWS NLB, TCP `6443` Listener, IP Target Group | Load-balances Kubernetes API traffic across `master-01`, `master-02`, and `master-03`. |

---

## Prerequisites

1. **Terraform CLI (`>= 1.5`)** installed on your local machine or bastion host.
2. **AWS Credentials** configured via `aws configure`, environment variables (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`), or an attached IAM role.
3. **EC2 Key Pair** created in your target AWS region (e.g., `newgen` in `us-west-2`), with the matching `.pem` file saved locally (`~/.ssh/newgen.pem`).

---

## Deployment Guide: `dev` Environment (Single Master)

Use `environments/dev` to provision a single control-plane node (`master-01`), worker nodes (`node-01..N`), and a public bastion workstation.

### 1. Review & Customize `environments/dev/terraform.tfvars`

```hcl
aws_region            = "us-west-2"
availability_zone     = "us-west-2a"
key_pair              = "newgen"
private_key_path      = "~/.ssh/newgen.pem"

vpc_name              = "newgent-dev-network"
vpc_cidr              = "192.168.0.0/16"
control_plane_cidr    = "192.168.1.0/24"
data_plane_cidr       = "192.168.2.0/24"
workstation_cidr      = "192.168.3.0/24"

control_plane_count   = 1
data_plane_count      = 4
```

*(Note: Keep `workstation` and `data_plane` in the same `availability_zone`—or attach public ELB subnets in every AZ where workers run—so single-AZ internet-facing NLBs route cleanly to worker NodePorts.)*

### 2. Provision Infrastructure

```bash
cd environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Capture Outputs for Ansible

Once `terraform apply` completes, retrieve the generated IP addresses to populate `ansible-roles/environments/dev/inventory.ini`:

```bash
terraform output
```

---

## Deployment Guide: `prod-ha` Environment (Multi-Master HA)

Use `environments/prod-ha` to provision **3 control-plane nodes** (`master-01`, `master-02`, `master-03`), worker nodes, and an **AWS Network Load Balancer (`nlb.tf`)** fronting TCP port `6443`.

### 1. Review & Customize `environments/prod-ha/terraform.tfvars`

Set `control_plane_count = 3` (must be an odd number—`3` or `5`—to maintain `etcd` quorum):

```hcl
aws_region            = "us-west-2"
availability_zone     = "us-west-2a"
key_pair              = "newgen"
private_key_path      = "~/.ssh/newgen.pem"

vpc_name              = "newgent-prod-network"
vpc_cidr              = "192.168.0.0/16"
control_plane_cidr    = "192.168.1.0/24"
data_plane_cidr       = "192.168.2.0/24"
workstation_cidr      = "192.168.3.0/24"

control_plane_count   = 3
data_plane_count      = 4
```

### 2. Provision HA Infrastructure & NLB

```bash
cd environments/prod-ha
terraform init
terraform plan
terraform apply
```

### 3. Capture Outputs for Ansible (`prod-ha`)

Retrieve the node private IPs and the NLB API endpoint DNS name:

```bash
terraform output
```

Copy these outputs into your Ansible `prod-ha` configuration before running `playbooks/ha.yml`:
* **`control_plane_private_ips` & `worker_nodes_private_ips`** → `ansible-roles/environments/prod-ha/inventory.ini`
* **`control_plane_endpoint`** (`<nlb-dns>:6443`) → `ansible-roles/environments/prod-ha/group_vars/all.yml`

---

## Day-2 Operations: Scaling & Teardown

### Scaling Worker Nodes
To add or remove worker nodes, update `data_plane_count` in `environments/<env>/terraform.tfvars` and apply:

```bash
cd environments/dev   # or environments/prod-ha
terraform apply
```

### Destroying an Environment
Before running `terraform destroy`, delete any Kubernetes `Service` of `type: LoadBalancer` and any dynamic `PersistentVolumeClaim` resources from the cluster so AWS removes CCM-managed LoadBalancers and EBS volumes cleanly (avoiding VPC dependency conflicts):

```bash
# 1. On the cluster: remove AWS CCM LoadBalancers & dynamic EBS volumes
kubectl delete svc --all-namespaces --field-selector spec.type=LoadBalancer
kubectl delete pvc --all --all-namespaces

# 2. In Terraform: destroy the AWS infrastructure
cd environments/dev   # or environments/prod-ha
terraform destroy
```
