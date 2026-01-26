# On-Premise Kubernetes Cluster Setup Guide
## AlmaLinux 9.6 - Kubeadm Installation

**System Specifications:**
- OS: AlmaLinux 9.6 (Sage Margay)
- Kernel: 5.14.0-570.12.1.el9_6.x86_64
- Storage: 70GB root, 122GB home
- RAM: ~7.6GB
- Architecture: x86_64

**Cluster Configuration:**
- 1 Master Node (Control Plane)
- Worker Node 01 
- Worker Node 02 

---

## Quick Start Overview

**Execution Order:**

1. **On ALL 3 nodes**:
   - Prerequisites: System updates, firewall, SELinux, kernel parameters
   - Install containerd
   - Install kubeadm, kubelet, kubectl
   - Set hostnames
   - Configure /etc/hosts

2. **On MASTER node ONLY** :
   - Initialize Kubernetes cluster
   - Configure kubectl
   - Install CNI (Flannel or Calico)

3. **On WORKER nodes** :
   - Run the join command from master init output

4. **Verify** on master node:
   - Check all nodes are Ready
   - Test with a sample deployment

---

## Prerequisites (All Nodes)

### 1. System Updates and Basic Packages

```bash
# Update system packages
sudo dnf update -y

# Install required packages
sudo dnf install -y iproute-tc wget curl vim

# Disable swap (Kubernetes requirement)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# Verify swap is disabled
free -h
```

### 2. Configure Firewall Rules

**On Master Node:**
```bash
# Control plane ports
sudo firewall-cmd --permanent --add-port=6443/tcp          # Kubernetes API server
sudo firewall-cmd --permanent --add-port=2379-2380/tcp     # etcd server client API
sudo firewall-cmd --permanent --add-port=10250/tcp         # Kubelet API
sudo firewall-cmd --permanent --add-port=10251/tcp         # kube-scheduler
sudo firewall-cmd --permanent --add-port=10252/tcp         # kube-controller-manager
sudo firewall-cmd --permanent --add-port=10255/tcp         # Read-only Kubelet API

# Flannel/Calico CNI (if using)
sudo firewall-cmd --permanent --add-port=8472/udp          # Flannel VXLAN
sudo firewall-cmd --permanent --add-port=4789/udp          # Calico VXLAN

# Reload firewall
sudo firewall-cmd --reload
```

**On Worker Nodes:**
```bash
# Worker node ports
sudo firewall-cmd --permanent --add-port=10250/tcp         # Kubelet API
sudo firewall-cmd --permanent --add-port=30000-32767/tcp   # NodePort Services
sudo firewall-cmd --permanent --add-port=8472/udp          # Flannel VXLAN
sudo firewall-cmd --permanent --add-port=4789/udp          # Calico VXLAN

# Reload firewall
sudo firewall-cmd --reload
```

### 3. Disable SELinux (or set to permissive)

```bash
# Set SELinux to permissive mode
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# Verify
getenforce
```

### 4. Configure Kernel Parameters

```bash
# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl parameters
sudo sysctl --system

# Verify
lsmod | grep br_netfilter
lsmod | grep overlay
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

---

## Step 1: Install Container Runtime (All Nodes)

### Install containerd

```bash
# Install containerd
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Enable SystemdCgroup
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
sudo systemctl status containerd
```

---

## Step 2: Install Kubeadm, Kubelet, and Kubectl (All Nodes)

```bash
# Add Kubernetes repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

# Install Kubernetes components
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable kubelet service
sudo systemctl enable --now kubelet
```

**Note:** Using Kubernetes v1.29 (stable). Check https://kubernetes.io/releases/ for latest stable version.

---

## Step 3: Initialize Master Node (Master Node Only)

### Set Hostname

```bash
# On master node (192.168.108.101)
sudo hostnamectl set-hostname k8s-master

# On worker01 (192.168.108.102)
sudo hostnamectl set-hostname k8s-worker01

# On worker02 (192.168.108.103)
sudo hostnamectl set-hostname k8s-worker02
```

### Configure /etc/hosts

Add entries on **all nodes**:

```bash
# Edit /etc/hosts on all nodes
sudo vi /etc/hosts

# Add these lines at the end of the file:
192.168.108.101  k8s-master
192.168.108.102  k8s-worker01
192.168.108.103  k8s-worker02
```

Save and exit (press `ESC`, then type `:wq` and press `ENTER`)

### Initialize Kubernetes Cluster

```bash
# Initialize the master node
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --apiserver-advertise-address=192.168.108.101
```

**Important:** Save the `kubeadm join` command output! You'll need it to join worker nodes.

The output will look like:
```
kubeadm join 192.168.108.101:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

**SAVE THIS COMMAND!** You will need it to join the worker nodes.

### Configure kubectl for Regular User

```bash
# For regular user
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# For root user (if needed)
export KUBECONFIG=/etc/kubernetes/admin.conf
echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> ~/.bashrc
```

### Verify Master Node

```bash
kubectl get nodes
kubectl get pods -A
```

---

## Step 4: Install Pod Network Add-on (Master Node Only)

Choose one CNI (Container Network Interface):

### Option A: Flannel (Recommended for beginners)

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for flannel pods to be ready
kubectl get pods -n kube-flannel
```

### Option B: Calico (Better for production)

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml

# Wait for calico pods to be ready
kubectl get pods -n calico-system
```

### Verify Network

```bash
# Check all system pods are running
kubectl get pods -A

# Check node status (should show Ready)
kubectl get nodes
```

---

## Step 5: Join Worker Nodes (Worker Nodes Only)

### On Each Worker Node :

```bash
# Use the EXACT join command from kubeadm init output on master node
# It will look like this:
sudo kubeadm join <ip>:6443 --token <token> \
    --discovery-token-ca-cert-hash sha256:<hash>
```

**Note:** Replace `<token>` and `<hash>` with the actual values from your master node output.

### If Token Expired

On master node:

```bash
# Generate new token
kubeadm token create --print-join-command

# This will output the complete join command to run on worker nodes
```

### Verify Worker Nodes Joined

On master node:

```bash
kubectl get nodes

# You should see all three nodes (wait 1-2 minutes for STATUS to become Ready):
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master     Ready    control-plane   10m   v1.29.x
# k8s-worker01   Ready    <none>          5m    v1.29.x
# k8s-worker02   Ready    <none>          5m    v1.29.x
```

---

## Step 6: Verify Cluster Setup

### Check Cluster Components

```bash
# Check all nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -A

# Check cluster info
kubectl cluster-info

# Check component status
kubectl get componentstatuses

# Check namespaces
kubectl get namespaces
```

### Deploy Test Application

```bash
# Create a test deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Check deployment
kubectl get deployments
kubectl get pods -o wide
kubectl get svc

# Get the NodePort (will be shown in the PORT column, e.g., 80:32XXX/TCP)
# Test access from any node using the NodePort
curl http://192.168.108.101:<nodeport>
# or
curl http://192.168.108.102:<nodeport>
# or
curl http://192.168.108.103:<nodeport>
```

### Cleanup Test Application

```bash
kubectl delete service nginx
kubectl delete deployment nginx
```

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Node Not Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
sudo journalctl -u kubelet -f

# Restart kubelet
sudo systemctl restart kubelet
```

#### 2. Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

#### 3. Network Issues

```bash
# Check CNI pods
kubectl get pods -n kube-flannel  # or kube-system for calico

# Check iptables
sudo iptables -L -n -v

# Check routes
ip route show
```

#### 4. Reset Cluster (if needed)

```bash
# On all nodes
sudo kubeadm reset -f
sudo rm -rf /etc/cni/net.d
sudo rm -rf $HOME/.kube/config
sudo systemctl restart containerd
```

---

## Cluster Maintenance

### Add Labels to Nodes

```bash
# Label worker nodes
kubectl label node k8s-worker01 node-role.kubernetes.io/worker=worker
kubectl label node k8s-worker02 node-role.kubernetes.io/worker=worker
```

### Drain Node for Maintenance

```bash
# Drain node
kubectl drain k8s-worker01 --ignore-daemonsets --delete-emptydir-data

# Make node schedulable again
kubectl uncordon k8s-worker01
```

### Remove Node from Cluster

```bash
# On master
kubectl drain k8s-worker01 --ignore-daemonsets --force --delete-emptydir-data
kubectl delete node k8s-worker01

# On worker node
sudo kubeadm reset
```

---

## Security Considerations

### 1. Enable RBAC (Role-Based Access Control)

RBAC is enabled by default in kubeadm.

### 2. Use Network Policies

```yaml
# Example network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### 3. Regular Updates

```bash
# Check for updates
sudo dnf check-update

# Update Kubernetes components (plan carefully)
sudo dnf update kubelet kubeadm kubectl --disableexcludes=kubernetes
```

---

## Useful Commands

```bash
# View cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
kubectl get all -A

# View logs
kubectl logs <pod-name> -n <namespace>
sudo journalctl -u kubelet -f

# Execute commands in pod
kubectl exec -it <pod-name> -- /bin/bash

# Get resource usage
kubectl top nodes
kubectl top pods -A

# View configurations
kubectl config view
kubectl config get-contexts

# Create resources from file
kubectl apply -f <file.yaml>

# Delete resources
kubectl delete -f <file.yaml>
kubectl delete pod <pod-name>
```

---

---

## Additional Resources

- Official Kubernetes Documentation: https://kubernetes.io/docs/
- Kubeadm Installation Guide: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
- AlmaLinux Documentation: https://wiki.almalinux.org/
- Kubernetes Community: https://kubernetes.io/community/
