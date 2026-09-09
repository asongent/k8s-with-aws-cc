### Kubernetes v1.36 AWS Cluster Setup

This Ansible playbook automates the installation and configuration of a Kubernetes v1.36.4 cluster on AWS EC2 instances.

It performs the following major tasks:

[1] Configures hostnames.
[2] Prepares all Kubernetes nodes.
[3] Installs and configures containerd, kubelet, kubeadm, and kubectl.
[4] Initializes the Kubernetes control-plane/master node.
[5] Installs the Calico CNI.
[6] Installs and configures the AWS Cloud Controller Manager.
[7] Generates a kubeadm join command.
[8] Joins worker nodes to the Kubernetes cluster.

1. **Set Hostnames**
```
- name: Set hostnames
  hosts: all
```

This play runs against all servers in the Ansible inventory.

It uses the Ansible hostname module to set each machine's hostname from the variable:

```yaml
{{ hostname }}
```

For example:
```
hostname: worker-01
```

would configure the server hostname as:

worker-01

2. **Install Dependencies and Base Kubernetes Setup**
- name: Install Dependencies and Base Setup
```
  hosts: kubernetes
```


This section prepares every Kubernetes node, including the master and workers.
```
Disable Swap
swapoff -a
```


Kubernetes requires swap to be disabled for this configuration.

The playbook also modifies /etc/fstab so that swap does not automatically come back after reboot.

```
swap enabled
     ↓
swapoff
     ↓
swap disabled permanently
```
Load Kubernetes Kernel Modules

The following Linux kernel modules are loaded:

```bash
overlay
br_netfilter
```

overlay is required by container runtimes, while br_netfilter allows Kubernetes networking traffic to interact correctly with iptables.

Configure Linux Networking

The playbook creates:

```
/etc/sysctl.d/kubernetes.conf
```


with:

```
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
```

These settings enable the Linux networking functionality Kubernetes networking requires.

The settings are then applied with:

```
sysctl --system
```
3. **Install System Dependencies**

The following packages are installed:

```bash
apt-transport-https
ca-certificates
curl
gnupg
lsb-release
gpg
python3-kubernetes
python3-jsonpatch
```

These provide the utilities and Python libraries required by the Ansible Kubernetes modules and package repositories.

4. Configure Docker's APT Repository

The Docker GPG key is downloaded to:

```
/etc/apt/keyrings/docker.asc
```

Then the Docker Ubuntu repository is added.

The repository is used primarily to obtain:

```
containerd.io
```

The playbook does not install Docker Engine. It installs the containerd runtime directly.

5. **Configure Kubernetes APT Repository**

The Kubernetes [repository](https://pkgs.k8s.io/core:/stable:/v1.36/deb/)for v1.36 is configured: You can update to your desired [Kubernetes release](https://kubernetes.io/releases/)




The repository signing key is stored at:

```
/etc/apt/keyrings/kubernetes-apt-keyring.asc
```
6. **Install Kubernetes Components**

The following packages are installed:

```
containerd.io
cri-tools
kubelet
kubeadm
kubectl
```

Their roles are:

| Component | Purpose |
| --- | --- |
| containerd | Runs containers |
| cri-tools | Provides CRI/container troubleshooting tools |
| kubelet | Kubernetes agent running on every node |
| kubeadm | Creates and joins Kubernetes clusters |
| kubectl | Kubernetes command-line client |

The Kubernetes packages are also placed on hold:
```
kubelet
kubeadm
kubectl
```

This prevents them from being automatically upgraded by APT.

7. **Configure containerd**

The playbook generates the default containerd configuration:

```
/etc/containerd/config.toml
```

It changes:

```
SystemdCgroup = false
```


to:

SystemdCgroup = true


This configures containerd to use the systemd cgroup driver, which matches the kubelet configuration later in the playbook.

containerd is then restarted.

8. **Configure Kubelet for AWS**

The file:

```
/etc/default/kubelet
```

is created with:

```
KUBELET_EXTRA_ARGS="--cloud-provider=external --node-ip=<node-ip>"
```


This tells kubelet that AWS cloud functionality will be provided by an external Cloud Controller Manager rather than by the Kubernetes core components.

9. **Configure crictl**

The playbook configures `etc/crictl.yaml` to communicate with containerd through `/run/containerd/containerd.sock`

This allows commands such as:
```
crictl ps
crictl images
```

to inspect containers managed by containerd.

10. **Flush Stale BIRD Routes**
The following command is executed:
```
ip route flush proto bird
```

This removes stale routes associated with the BIRD routing protocol from the kernel routing table.

This is particularly relevant when previous Calico/BIRD networking configuration has left stale routes behind.

11. Bootstrap the Master Node

The master/control-plane play runs against:
```
hosts: master
```


The purpose of this section is to create the Kubernetes control plane.

- *11.1 Obtain AWS EC2 Metadata*

The playbook communicates with the AWS EC2 Instance Metadata Service (IMDSv2).

It first requests an IMDSv2 token:
```
http://169.254.169.254/latest/api/token
```

It then uses that token to retrieve:
```
EC2 Instance ID
EC2 Availability Zone
```
For example: 
Instance ID:`i-0123456789abcdef`
Availability Zone:`eu-west-1a`


These values are used to construct the Kubernetes AWS provider ID.

12. **Create kubeadm Configuration**

The playbook generates:

```
/tmp/kubeadm.yaml
```
This contains three Kubernetes configuration objects:

- *InitConfiguration*
- *ClusterConfiguration*
- *KubeletConfiguration*


The important settings include:

| Setting | Value |
| --- | --- |
| Kubernetes version | v1.36.4 |
| Pod network | 10.244.0.0/16 |
| Service network | 10.96.0.0/12 |
| Container runtime | containerd |
| Cgroup driver | systemd |
| Cloud provider | external |


The control-plane endpoint is `<master-ip>:6443`

13. **Initialize Kubernetes**

The cluster is initialized with:
```
kubeadm init --config /tmp/kubeadm.yaml
```

This creates the Kubernetes control plane.The resulting administration configuration is:

```
/etc/kubernetes/admin.conf
```

14. **Configure kubectl**

The playbook creates `~/.kube/` for the administrator/user and copies `/etc/kubernetes/admin.conf` to `~/.kube/config`

This allows the user to run the following without explicitly specifying the kubeconfig file.
```
kubectl get nodes
kubectl get pods -A
kubectl get namespaces
etc...
```
15. **Install Calico CNI**

The playbook downloads Calico and modifies its default pod CIDR.
The default(`192.168.0.0/16`) is changed to `10.244.0.0/16`. This matches the pod network configured in kubeadm. The modified Calico manifest is then applied to Kubernetes. Calico provides the cluster's Container Network Interface (CNI) and therefore enables communication between Kubernetes pods.

16. **Install Helm**

The official Helm installation script is downloaded and executed.
This installs:

helm

which is then used to deploy the AWS Cloud Controller Manager.

17. **Install AWS Cloud Controller Manager**

The [AWS Cloud Controller Manager Helm repository](https://kubernetes.github.io/cloud-provider-aws) is added and later then installed in `kube-system` namespace. Its purpose is to integrate Kubernetes with AWS. It handles AWS-specific functionality such as, 
- *Node/provider identification*
- *AWS node lifecycle integration*
- *AWS cloud-provider functionality*

Kubernetes resources that depend on AWS infrastructure explicitly configures `--cloud-provider=aws`  and    `--configure-cloud-routes=false`

18. **Configure AWS Cloud Controller Manager Networking**

The deployed AWS Cloud Controller Manager DaemonSet is patched to use `ostNetwork: true`. It is also given explicit `DNS servers`

```
8.8.8.8
1.1.1.1
```
Using hostNetwork means that the AWS Cloud Controller Manager uses the host's network namespace instead of the normal Kubernetes pod network.

19. **Generate Worker Join Information**

The master creates a temporary Kubernetes bootstrap token using the `kubeadm token create --print-join-command` command. 

The resulting command looks conceptually like:
```
kubeadm join <master-ip>:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash <hash>
```


The bellow information is extracted 

```
join_token
join_hash
apiserver_endpoint
```
These values are made available to the `worker-node` only.

20. **Prepare Worker Nodes**

The worker play runs against:

hosts: workers


It first disables the Ubuntu UFW firewall.

UFW
 ↓
stopped
 ↓
disabled


The task deliberately does not fail the play if UFW does not exist.

21. Obtain Worker AWS Metadata

Each worker also queries EC2 IMDSv2 to obtain:

EC2 Instance ID
Availability Zone


These are used to construct the worker's AWS provider ID.

For example:

aws:///eu-west-1a/i-0123456789abcdef

22. Create Worker kubeadm Join Configuration

Each worker gets:

/tmp/kubeadm-join.yaml


The file contains:

JoinConfiguration


and specifies:

API server endpoint
Bootstrap token
CA certificate hash
Cloud provider
AWS provider ID
Worker node IP


This allows the worker to identify and authenticate with the Kubernetes control plane.

23. Join Workers to Kubernetes

Finally, each worker executes:

kubeadm join --config /tmp/kubeadm-join.yaml


This registers the worker with the Kubernetes cluster.

The playbook uses:

creates: /etc/kubernetes/kubelet.conf


so the join command is skipped if the node has already successfully joined.

Overall Architecture

The resulting architecture is essentially:

```text
                        AWS
                         ▲
                      AWS API
                         │
           ┌─────────────┴─────────────┐
           │ AWS Cloud Controller      │
           │ Manager (kube-system)     │
           │ DaemonSet, hostNetwork    │
           └─────────────┬─────────────┘
                         │ 
                   Kubernetes API
                         ▼
               ┌─────────────────────┐
               │ Kubernetes Master   │
               │ kube-apiserver      │
               │ kube-controller     │
               │ scheduler           │
               │ etcd                │
               │ kubelet             │
               │ containerd          │
               └──────────┬──────────┘
                          │
                    ubernetes API
                          │
            ┌─────────────┴─────────────┐
            │                           │
            ▼                           ▼
     ┌───────────────┐           ┌───────────────┐
     │ Worker Node 1 │           │ Worker Node 2 │
     │               │           │               │
     │ kubelet       │           │ kubelet       │
     │ containerd    │           │ containerd    │
     │ Calico        │           │ Calico        │
     └───────────────┘           └───────────────┘
            │                            │
            └──────────────┬─────────────┘
                           │
                           ▼
                     Pod Network
                     10.244.0.0/16
      ```