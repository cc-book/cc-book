# Lab 2: CoCo Without Confidential Hardware

This lab runs the full Confidential Containers stack on any Linux VM — no TEE required. A **sample verifier** replaces hardware attestation, letting you exercise VM isolation, guest-pull images, and secret delivery from KBS.

## Prerequisites

- Ubuntu 26.04, minimum 8 GB RAM, 4 vCPUs (any cloud or bare-metal VM)
- Run all steps inside the VM via SSH

## Estimated Cost

| Resource | Size | Approx. cost |
|----------|------|-------------|
| `coco-vm` | Standard_D4s_v3 | ~$0.19/hr |
| **2-hour lab session** | | **~$0.38** |

## Step 1: Provision Infrastructure

If you don't have an Ubuntu 26.04 VM available, create one now. `Standard_D4s_v3` (4 vCPU, 16 GB RAM) gives comfortable headroom for the CoCo stack.

```bash
export LOCATION="eastus"
export RG="coco-lab"

az group create --name $RG --location $LOCATION

az vm create \
  --resource-group $RG \
  --name coco-vm \
  --image "Canonical:ubuntu-26_04-lts:server:latest" \
  --size Standard_D4s_v3 \
  --location $LOCATION \
  --admin-username azureuser \
  --generate-ssh-keys \
  --output table

export VM_IP=$(az vm show -g $RG -n coco-vm --query publicIps -d -o tsv)
echo "VM IP: $VM_IP"
ssh azureuser@$VM_IP
```

## Step 2: Set Up a Single-Node Kubernetes Cluster

```bash
# Set up Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

# Configure containerd with SystemdCgroup (required by kubeadm)
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd && sudo systemctl enable containerd

# --- kubeadm 1.36.1 / kubelet / kubectl ---
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=1.36.1-1.1 kubeadm=1.36.1-1.1 kubectl=1.36.1-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# --- pre-flight ---
sudo swapoff -a
sudo modprobe br_netfilter overlay
printf "net.bridge.bridge-nf-call-iptables = 1\nnet.ipv4.ip_forward = 1\n" | \
  sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system

# --- bootstrap ---
sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version=1.36.1

mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown "$USER:$USER" ~/.kube/config

# Allow pods on the control-plane node (single-node cluster)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true

# Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# Wait for node Ready (~60s)
kubectl wait --for=condition=Ready node --all --timeout=120s
kubectl get nodes
```

## Step 3: Install helm and cococtl

```bash
# helm
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# cococtl
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[ "$ARCH" = "x86_64" ] && ARCH="amd64"

COCOCTL_VER=$(curl -s https://api.github.com/repos/confidential-devhub/cococtl/releases/latest | grep tag_name | cut -d'"' -f4)
curl -fLO "https://github.com/confidential-devhub/cococtl/releases/download/${COCOCTL_VER}/cococtl-${OS}-${ARCH}"

sudo install -m 0755 cococtl-${OS}-${ARCH} /usr/local/bin/cococtl

# Setup kubectl plugin
sudo ln -sf /usr/local/bin/cococtl /usr/local/bin/kubectl-coco
sudo ln -sf /usr/local/bin/cococtl /usr/local/bin/kubectl_complete-coco


kubectl coco --version
```

## Step 4: Label the Node for the CoCo DaemonSet

```bash
kubectl label node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" \
  "node.kubernetes.io/worker="
```

## Step 5: Install CoCo

```bash
helm install coco \
  oci://ghcr.io/confidential-containers/charts/confidential-containers \
  --version 0.21.0 \
  --namespace coco-system \
  --create-namespace \
  --wait \
  --timeout 10m

kubectl get runtimeclasses
# kata-qemu-coco-dev, kata-qemu-snp, kata-qemu-tdx, ...
```

## Step 6: Run Your First Confidential Pod

```{code-block} yaml
:caption: coco-demo.yaml
cat > coco-demo.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: coco-demo
spec:
  runtimeClassName: kata-qemu-coco-dev
  containers:
    - name: busybox
      image: quay.io/prometheus/busybox:latest
      imagePullPolicy: Always
      command: [sleep, "infinity"]
  restartPolicy: Never
EOF
```

```bash
kubectl apply -f coco-demo.yaml
kubectl wait --for=condition=Ready pod/coco-demo --timeout=120s
```

Verify the container runs inside an isolated VM with its own kernel:

```bash
kubectl exec coco-demo -- uname -r   # Kata kernel (e.g., 6.18.28)
uname -r                             # Host kernel (e.g., 7.0.0-1004-azure)
```

The kernels will differ, confirming the container runs inside a separate VM managed by Kata Containers.

## Step 7: Deploy Trustee and Store a Secret

Deploy Trustee (KBS + Attestation Service + RVPS) into the cluster.
Pass `--runtime-class kata-qemu-coco-dev` for non-hardware testing. Without this flag, cococtl auto-detects and may select a hardware-specific class (SNP/TDX):

```bash
kubectl coco init --runtime-class kata-qemu-coco-dev
```

This deploys Trustee and writes `~/.kube/coco-config.toml`. Extract the KBS URL:

```bash
# TOML uses single quotes — use single-quote delimiter in awk
export KBS_URL=$(grep trustee_server ~/.kube/coco-config.toml | awk -F"'" '{print $2}')
echo "KBS URL: ${KBS_URL}"
```

Store a secret:

```bash
echo -n "MySuperSecret" > secret.txt
kubectl-coco kbs populate --path default/secret/1 --resource-file secret.txt
```

## Step 8: Retrieve a Secret Inside a CoCo Pod

The Attestation Agent inside the Kata VM needs to know the KBS URL. Pass it via the kernel command line annotation:

```{code-block} yaml
:caption: coco-secret-pod.yaml
# Unquoted EOF so ${KBS_URL} is expanded into the manifest
cat > coco-secret-pod.yaml << EOF
apiVersion: v1
kind: Pod
metadata:
  name: coco-secret-test
  annotations:
    io.katacontainers.config.hypervisor.kernel_params: "agent.aa_kbc_params=cc_kbc::${KBS_URL}"
spec:
  runtimeClassName: kata-qemu-coco-dev
  containers:
    - name: busybox
      image: quay.io/prometheus/busybox:latest
      imagePullPolicy: Always
      command: [sleep, "infinity"]
  restartPolicy: Never
EOF
```

```bash
kubectl apply -f coco-secret-pod.yaml
kubectl wait --for=condition=Ready pod/coco-secret-test --timeout=120s
```

Inside the pod, fetch the secret through CDH:

```bash
kubectl exec coco-secret-test -- wget -qO- http://127.0.0.1:8006/cdh/resource/default/secret/1
# MySuperSecret
```

## Key Concepts Exercised

| Concept | Mechanism |
|---------|-----------|
| VM isolation | QEMU/KVM via Kata Containers (`kata-qemu-coco-dev`) |
| Image privacy | Pulled inside guest VM, not on host |
| Secret delivery | CDH at `127.0.0.1:8006` → KBS attestation |
| Non-TEE testing | Sample verifier replaces hardware attestation |

## Cleanup

```bash
az group delete --name coco-lab --yes --no-wait
az group show --name coco-lab 2>/dev/null && echo "Still deleting..." || echo "Deleted."
```
