# Hands-On Labs

This chapter provides practical exercises to complement the concepts covered in previous chapters. The labs are designed to be independent — you can work through them in order or jump to the one most relevant to your environment.

| Lab | What you'll do | Hardware needed |
|-----|---------------|-----------------|
| [Lab 1: CVM Attestation on Azure](#lab-1-cvm-attestation-on-azure) | Provision two Azure VMs (Trustee + SEV-SNP CVM), run hardware attestation end-to-end, retrieve a secret | Azure account |
| [Lab 2: CoCo Without Confidential Hardware](#lab-2-coco-without-confidential-hardware) | Deploy CoCo on a standard Kubernetes cluster using the sample verifier | Any Linux VM |
| [Lab 3: CoCo-fy a Workload with cococtl](#lab-3-coco-fy-a-workload-with-cococtl) | Transform an existing Kubernetes app into a confidential workload with one command | Any Linux VM |
| [Lab 4: CoCo on a Real CVM via Peer-Pods (BYOM)](#lab-4-coco-on-a-real-cvm-via-peer-pods-byom) | Run a CoCo pod on a real Azure SEV-SNP CVM using cloud-api-adaptor's BYOM provider | Azure account |

## Component Versions

All labs in this chapter use the following pinned versions:

| Component | Version |
|-----------|---------|
| Ubuntu (VMs and CVMs) | 26.04 LTS |
| Kubernetes | 1.36.1 |
| CoCo helm chart (Labs 2 & 3) | 0.21.0 |
| Peerpods helm chart (Lab 4) | 0.3.0 (CAA v0.21.0) |
| Kata Containers | 3.31.0 |
| Trustee | v0.20.0 |
| guest-components | v0.20.0 |

---

## Lab 1: CVM Attestation on Azure

This lab demonstrates the core attestation loop on a real Confidential VM. You will provision two Azure VMs — a standard Ubuntu VM hosting Trustee (KBS) and a hardware-backed Confidential VM running the guest-components stack — then retrieve a secret from Trustee via hardware attestation. This is the same flow described conceptually in the [Confidential Virtual Machines](07_confidential_vms.md) and [Trustee](11_trustee.md) chapters.

```{figure} ../images/cvm.png
:alt: CVM attestation overview
:align: center
```

### Prerequisites

- An Azure subscription with vCPU quota for Confidential VM sizes in a supported region. Check and request quota before starting:

  ```bash
  # Check current quota for DCasv5 (AMD SEV-SNP) in East US
  az vm list-usage --location eastus --output table | grep -i "DC.*v5\|standard DC"

  # Or for West Europe
  az vm list-usage --location westeurope --output table | grep -i "DC.*v5\|standard DC"
  ```

  Confidential VM sizes are available in select regions. Verified supported regions include **East US**, **West US**, **West Europe**, **North Europe**, and **Southeast Asia**. If your nearest region lacks quota, request an increase via the Azure portal under *Subscriptions → Usage + quotas*.

- The [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in (`az login`)

### Choose Your TEE Platform

This lab supports two hardware paths. Pick one and use those commands throughout:

| | AMD SEV-SNP | Intel TDX |
|--|-------------|-----------|
| **VM size** | `Standard_DC2as_v5` | `Standard_DC2es_v5` |
| **Azure series** | DCasv5 | DCesv5 |
| **vCPU / RAM** | 2 / 8 GB | 2 / 16 GB |
| **Approx. cost** | ~$0.10 / hr | ~$0.15 / hr |

### Step 1: Provision Infrastructure

Set your region and TEE choice as variables first, then run the common provisioning commands.

```bash
az login
az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# Set your preferred region (eastus or westeurope)
export LOCATION="eastus"

# Set CVM size: AMD SEV-SNP or Intel TDX (pick one)
export CVM_SIZE="Standard_DC2as_v5"   # AMD SEV-SNP
# export CVM_SIZE="Standard_DC2es_v5"   # Intel TDX

az group create --name cvm-lab --location "${LOCATION}"
```

Find the latest Ubuntu 26.04 CVM-compatible image for your region:

```bash
az vm image list \
  --publisher Canonical \
  --offer ubuntu-26_04-lts \
  --sku pro-server-cvm \
  --location "${LOCATION}" \
  --all \
  --output table | tail -5
```

Use the URN from the output (e.g., `Canonical:ubuntu-26_04-lts:pro-server-cvm:latest`) as `CVM_IMAGE` below:

```bash
export CVM_IMAGE="Canonical:ubuntu-26_04-lts:pro-server-cvm:latest"
```

Create both VMs in the same virtual network so the CVM can reach Trustee over a private IP:

```bash
# Standard Ubuntu VM for Trustee
az vm create \
  --resource-group cvm-lab \
  --name trustee-vm \
  --image Canonical:ubuntu-26_04-lts:server:latest \
  --size Standard_D2s_v3 \
  --location "${LOCATION}" \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name cvm-lab-vnet \
  --subnet cvm-lab-subnet

# Confidential VM
az vm create \
  --resource-group cvm-lab \
  --name cvm-demo \
  --image "${CVM_IMAGE}" \
  --size "${CVM_SIZE}" \
  --location "${LOCATION}" \
  --security-type ConfidentialVM \
  --os-disk-security-encryption-type VMGuestStateOnly \
  --enable-vtpm true \
  --enable-secure-boot true \
  --admin-username azureuser \
  --generate-ssh-keys \
  --vnet-name cvm-lab-vnet \
  --subnet cvm-lab-subnet
```

Allow port 8080 between the two VMs (KBS default port):

```bash
az network nsg rule create \
  --resource-group cvm-lab \
  --nsg-name trustee-vmNSG \
  --name allow-kbs \
  --priority 1010 \
  --protocol Tcp \
  --destination-port-ranges 8080 \
  --access Allow
```

Capture IPs for SSH and inter-VM communication:

```bash
export TRUSTEE_PUBLIC_IP=$(az vm show -g cvm-lab -n trustee-vm --query publicIps -d -o tsv)
export TRUSTEE_PRIVATE_IP=$(az vm show -g cvm-lab -n trustee-vm --query privateIps -d -o tsv)
export CVM_PUBLIC_IP=$(az vm show -g cvm-lab -n cvm-demo --query publicIps -d -o tsv)

echo "Trustee public:  ${TRUSTEE_PUBLIC_IP}"
echo "Trustee private: ${TRUSTEE_PRIVATE_IP}"
echo "CVM public:      ${CVM_PUBLIC_IP}"
```

**SSH shortcuts** — open two terminal windows, one for each VM:

```bash
# Terminal A — Trustee VM
ssh azureuser@${TRUSTEE_PUBLIC_IP}

# Terminal B — CVM
ssh azureuser@${CVM_PUBLIC_IP}
```

### Step 2: Deploy Trustee on the Trustee VM

SSH into `trustee-vm` (Terminal A — `TRUSTEE_PUBLIC_IP` was captured in Step 1):

On `trustee-vm`:

```bash
# Install Docker via official script (pro-server-cvm image does not include docker-compose-plugin in default repos)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

# Clone Trustee v0.20.0
git clone https://github.com/confidential-containers/trustee --single-branch -b v0.20.0
cd trustee
```

The docker-compose file bundles KBS, the Attestation Service (AS), and RVPS as separate services. A one-shot `setup` container generates the ed25519 auth key pair automatically at `kbs/config/private.key` on first run.

The docker-compose at v0.20.0 references `:latest` image tags, which may be newer than the config schema bundled in the repo. Pin to the exact v0.20.0 image SHAs before starting:

```bash
SHA="d4e317620c4039c89779b725f74974d8f005da66"
sed -i "s|kbs-grpc-as:latest|kbs-grpc-as:${SHA}-x86_64|g" docker-compose.yml
sed -i "s|coco-as-grpc:latest|coco-as-grpc:${SHA}-x86_64|g" docker-compose.yml
sed -i "s|rvps:latest|rvps:${SHA}-x86_64|g" docker-compose.yml

# Start all Trustee services (key generation happens automatically)
docker compose up -d

# Confirm all three services are running
docker compose ps

# Confirm KBS is listening
curl -s http://localhost:8080/kbs/v0/resource/default/test 2>&1 | grep -o '"type":"[^"]*"'
```

Note the path to the auto-generated private key — you will need it in Step 5:

```bash
export KBS_PRIVATE_KEY="$(pwd)/kbs/config/private.key"
ls -la "${KBS_PRIVATE_KEY}"   # confirm the setup service created it
```

Keep this SSH session open — you will return to it in Step 5.

### Step 3: Verify the CVM Hardware

SSH into `cvm-demo` (Terminal B — `CVM_PUBLIC_IP` was captured in Step 1).

Verify hardware memory encryption is active. The output depends on which TEE platform you chose:

```bash
# AMD SEV-SNP — look for:
sudo dmesg | grep -i sev
# Memory Encryption Features active: AMD SEV
# systemd[1]: Detected confidential virtualization sev-snp.

# Intel TDX — look for:
sudo dmesg | grep -i tdx
# tdx: TDX module: attributes 0x0, vendor_id 0x8086, major_version 1 ...
# tdx: Memory is marked as private in EFI memmap
```

Either output confirms the CVM is running inside a hardware TEE with encrypted memory. Note that `dmesg` requires `sudo` on the `pro-server-cvm` image.

Install Docker via the official script:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

# Install ORAS — used to pull guest-components binaries from GHCR
ORAS_VER=$(curl -s https://api.github.com/repos/oras-project/oras/releases/latest | grep tag_name | cut -d'"' -f4 | tr -d 'v')
curl -fLO "https://github.com/oras-project/oras/releases/download/v${ORAS_VER}/oras_${ORAS_VER}_linux_amd64.tar.gz"
tar xzf oras_${ORAS_VER}_linux_amd64.tar.gz
sudo install -m 0755 oras /usr/local/bin/oras

# Install TPM2 libraries required by the attestation-agent
sudo apt-get install -y libtss2-tctildr0 libtss2-esys-3.0.2-0t64 libtss2-rc0t64
```

### Step 4: Run the Guest-Components Stack

The guest-components stack consists of three binaries — the **Attestation Agent (AA)**, the **Confidential Data Hub (CDH)**, and the **API Server** — the same components embedded inside a CoCo CVM. They are distributed as OCI artifacts on GHCR and pulled with ORAS rather than Docker.

At v0.20.0 the commit SHA is `f1561038b9a58d309a3366cc8e25d8e6162424a0`. The AA tag also encodes the TEE platform. For Azure CVMs (both SNP and TDX), the platform is `az-cvm-vtpm`:

```bash
SHA="f1561038b9a58d309a3366cc8e25d8e6162424a0"
REG="ghcr.io/confidential-containers/guest-components"
mkdir -p ~/gc && cd ~/gc

# Pull all three in parallel
oras pull ${REG}/attestation-agent:${SHA}-az-cvm-vtpm_x86_64 &
oras pull ${REG}/confidential-data-hub:${SHA}-x86_64 &
oras pull ${REG}/api-server-rest:${SHA}-x86_64 &
wait

# Extract
tar xf attestation-agent.tar.xz
tar xf confidential-data-hub.tar.xz
tar xf api-server-rest.tar.xz
ls -lh attestation-agent confidential-data-hub api-server-rest
```

Create an AA config file pointing at the KBS (substitute the Trustee private IP printed in Step 1):

```bash
export KBS_URL="http://<TRUSTEE_PRIVATE_IP>:8080"

sudo tee /etc/attestation-agent.toml << EOF
[token_configs.kbs]
url = "${KBS_URL}"
EOF
```

Create the socket directories and start the three services in order:

```bash
sudo mkdir -p /run/confidential-containers/attestation-agent

# 1. Attestation Agent — ttRPC socket, accesses vTPM for SEV-SNP evidence
sudo ~/gc/attestation-agent --config-file /etc/attestation-agent.toml > /tmp/aa.log 2>&1 &
sleep 3

# 2. Confidential Data Hub — connects to AA, handles KBS resource requests
sudo AA_KBC_PARAMS="cc_kbc::${KBS_URL}" ~/gc/confidential-data-hub > /tmp/cdh.log 2>&1 &
sleep 3

# 3. API Server REST — HTTP proxy on 127.0.0.1:8006
sudo ~/gc/api-server-rest > /tmp/api.log 2>&1 &
sleep 2
```

Confirm all three sockets and the REST endpoint are up:

```bash
ls /run/confidential-containers/attestation-agent/attestation-agent.sock \
   /run/confidential-containers/cdh.sock

curl -s http://127.0.0.1:8006/cdh/resource/default/secret/1
# Returns an error until a secret is stored — that is expected
```

### Step 5: Store a Secret in Trustee

Switch back to your SSH session on `trustee-vm`:

Install `cococtl` on `trustee-vm` (if not already present) and use it to populate KBS. The `--kbs-url` and `--auth-key` flags let `cococtl` target any KBS instance, including this standalone docker-compose deployment:

```bash
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
[ "$ARCH" = "x86_64" ] && ARCH="amd64"

COCOCTL_VER=$(curl -s https://api.github.com/repos/confidential-devhub/cococtl/releases/latest | grep tag_name | cut -d'"' -f4)
curl -fLO "https://github.com/confidential-devhub/cococtl/releases/download/${COCOCTL_VER}/cococtl-${OS}-${ARCH}"
sudo install -m 0755 cococtl-${OS}-${ARCH} /usr/local/bin/cococtl
```



Store the secret:

```bash
# Switch to the directory where you cloned the Trustee repo and ran the docker-compose step (`Step 2`).
cd ~/trustee

echo "lab1-secret-value" > secret.txt

cococtl kbs populate \
  --kbs-url http://localhost:8080 \
  --auth-key "${KBS_PRIVATE_KEY}" \
  --path default/secret/1 \
  --resource-file secret.txt
```

### Step 6: Retrieve the Secret from Inside the CVM

Back on `cvm-demo`:

```bash
curl http://127.0.0.1:8006/cdh/resource/default/secret/1
# Returns: lab1-secret-value
```

The CDH forwards the request to the AA, which generates a hardware attestation report (SEV-SNP or TDX), sends it to Trustee, and — after the Attestation Service verifies the evidence against the platform's hardware root of trust — KBS releases the secret. The value appears in your terminal without ever leaving the CVM in plaintext.

This is the same path a CoCo pod's workload takes when it calls the CDH endpoint for a sealed secret or image decryption key.

### What Just Happened

| Step | Component | RATS Role |
|------|-----------|-----------|
| CVM boot | AMD Secure Processor (SEV-SNP) or Intel TDX Module | Hardware Root of Trust |
| Attestation report generation | Attestation Agent (AA) | Attester |
| Report verification | Trustee Attestation Service | Verifier |
| Secret release decision | Key Broker Service (KBS) | Relying Party |
| Secret delivery to workload | Confidential Data Hub (CDH) | — |

### Estimated Cost

Prices are approximate for **East US** (pay-as-you-go, June 2026). West Europe is typically 10–15% higher.

| Resource | AMD SEV-SNP | Intel TDX |
|----------|-------------|-----------|
| `cvm-demo` (CVM) | Standard_DC2as_v5 — ~$0.10/hr | Standard_DC2es_v5 — ~$0.15/hr |
| `trustee-vm` (standard) | Standard_D2s_v3 — ~$0.10/hr | Same — ~$0.10/hr |
| OS disks (2 × 30 GB) | ~$0.01/hr combined | ~$0.01/hr combined |
| **Total** | **~$0.21/hr** | **~$0.26/hr** |
| **2-hour lab session** | **~$0.42** | **~$0.52** |
| **Left running 24 hr** | **~$5.00** | **~$6.20** |

**Stop both VMs** when taking a break to avoid unnecessary charges:

```bash
az vm deallocate --resource-group cvm-lab --name cvm-demo --no-wait
az vm deallocate --resource-group cvm-lab --name trustee-vm --no-wait
```

Restart them when resuming:

```bash
az vm start --resource-group cvm-lab --name trustee-vm
az vm start --resource-group cvm-lab --name cvm-demo

# Refresh IPs (they change on restart if using dynamic allocation)
export TRUSTEE_PUBLIC_IP=$(az vm show -g cvm-lab -n trustee-vm --query publicIps -d -o tsv)
export TRUSTEE_PRIVATE_IP=$(az vm show -g cvm-lab -n trustee-vm --query privateIps -d -o tsv)
export CVM_PUBLIC_IP=$(az vm show -g cvm-lab -n cvm-demo --query publicIps -d -o tsv)
```

### Cleanup

Delete the entire resource group — VMs, disks, VNet, and NSGs — in one command:

```bash
az group delete --name cvm-lab --yes --no-wait
```

Verify deletion is complete (takes 2–5 minutes):

```bash
az group show --name cvm-lab 2>/dev/null && echo "Still deleting..." || echo "Deleted."
```

---

## Lab 2: CoCo Without Confidential Hardware

This lab runs the full Confidential Containers stack on any Linux VM — no TEE required. A **sample verifier** replaces hardware attestation, letting you exercise VM isolation, guest-pull images, and secret delivery from KBS.

### Prerequisites

- Ubuntu 26.04, minimum 8 GB RAM, 4 vCPUs (any cloud or bare-metal VM)
- Run all steps inside the VM via SSH

### Estimated Cost

| Resource | Size | Approx. cost |
|----------|------|-------------|
| `coco-vm` | Standard_D4s_v3 | ~$0.19/hr |
| **2-hour lab session** | | **~$0.38** |

### Step 1: Provision Infrastructure

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

### Step 2: Set Up a Single-Node Kubernetes Cluster

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

### Step 3: Install helm and cococtl

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

### Step 4: Label the Node for the CoCo DaemonSet

```bash
kubectl label node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" \
  "node.kubernetes.io/worker="
```

### Step 5: Install CoCo

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

### Step 6: Run Your First Confidential Pod

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

### Step 7: Deploy Trustee and Store a Secret

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

### Step 8: Retrieve a Secret Inside a CoCo Pod

The Attestation Agent inside the Kata VM needs to know the KBS URL. Pass it via the kernel command line annotation:

```{code-block} yaml
:caption: coco-secret-pod.yaml
cat > coco-secret-pod.yaml << 'EOF'
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

### Key Concepts Exercised

| Concept | Mechanism |
|---------|-----------|
| VM isolation | QEMU/KVM via Kata Containers (`kata-qemu-coco-dev`) |
| Image privacy | Pulled inside guest VM, not on host |
| Secret delivery | CDH at `127.0.0.1:8006` → KBS attestation |
| Non-TEE testing | Sample verifier replaces hardware attestation |

### Cleanup

```bash
az group delete --name coco-lab --yes --no-wait
az group show --name coco-lab 2>/dev/null && echo "Still deleting..." || echo "Deleted."
```

---

## Lab 3: CoCo-fy a Workload with cococtl

`cococtl` (`kubectl coco`) automates the steps from Lab 2: it sets the runtime class, converts Kubernetes Secrets to sealed secrets, generates the initdata annotation (which configures the KBS URL and OPA policy for the Kata VM), and populates KBS — all from a single command.

### Prerequisites

- Lab 2 environment running

### Step 1: Create a Sample App

```{code-block} yaml
:caption: myapp.yaml
cat > myapp.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  replicas: 1
  selector:
    matchLabels:
      app: myapp
  template:
    metadata:
      labels:
        app: myapp
    spec:
      containers:
        - name: myapp
          image: quay.io/prometheus/busybox:latest
          command: [sleep, "infinity"]
          env:
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: myapp-secret
                  key: password
---
apiVersion: v1
kind: Secret
metadata:
  name: myapp-secret
stringData:
  password: "supersecretpassword"
EOF
```

### Step 2: Preview What cococtl Will Change

```bash
kubectl coco explain -f myapp.yaml
```

This shows which transformations will be applied: runtime class, sealed secrets, initdata annotation.

### Step 3: Apply the Original Manifest

The transform step reads the original `myapp-secret` from the cluster to encrypt it. Create it first:

```bash
kubectl apply -f myapp.yaml
```

### Step 4: Transform the Manifest

```bash
kubectl coco apply \
  -f myapp.yaml \
  --skip-apply
```

Three files are generated in the same directory as `myapp.yaml`:

- `myapp-coco.yaml` — transformed deployment (runtimeClass addition, sealed secret ref, initdata annotation)
- `myapp-sealed-secrets.yaml` — Kubernetes Secret containing the sealed token
- `myapp-trustee-secrets.yaml` — KBS upload manifest

### Step 5: Upload Secrets to KBS and Deploy

```bash
# 1. Upload the plaintext secret to KBS (done before sealing)
kubectl coco kbs populate -f myapp-trustee-secrets.yaml

# 2. Create the sealed-secret k8s Secret in the cluster
kubectl apply -f myapp-sealed-secrets.yaml

# 3. Remove the original plaintext secret from the cluster
kubectl delete secret myapp-secret

# 4. Deploy the transformed workload
kubectl apply -f myapp-coco.yaml

# Wait for pod to be Running
kubectl rollout status deployment/myapp
```

### Step 6: Verify Secret Delivery

The `cococtl` initdata annotation includes an OPA policy that blocks `kubectl exec` (this is intentional security — the workload should not be shell-accessible by cluster operators). Use `kubectl logs` to verify the secret reaches the workload:

```bash
# Replace the long-running pod with one that fetches and prints the secret
kubectl delete deployment myapp
```

```{code-block} yaml
:caption: myapp-verify.yaml
cat > myapp-verify.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: verify-secret
spec:
  runtimeClassName: kata-qemu-coco-dev
  containers:
    - name: verify
      image: quay.io/prometheus/busybox:latest
      command:
        - /bin/sh
        - -c
        - |
          sleep 5
          echo "Fetching from KBS via CDH..."
          wget -qO- http://127.0.0.1:8006/cdh/resource/default/myapp-secret/password
          echo ""
          sleep infinity
  restartPolicy: Never
EOF
```

Transform this pod to get KBS initdata:

```bash
kubectl coco apply -f myapp-verify.yaml --skip-apply
kubectl apply -f myapp-verify-coco.yaml
kubectl wait --for=condition=Ready pod/verify-secret --timeout=120s
```

Secret should appear in the logs:

```bash
kubectl logs verify-secret
# supersecretpassword
```

The sealed secret `myapp-secret-sealed` in the cluster stores an opaque token, not the plaintext. The actual value is fetched by CDH inside the Kata VM after the Attestation Agent successfully contacts KBS.

### What cococtl Automated

| Manual step (Lab 2) | cococtl equivalent |
|--------------------|--------------------|
| Set `runtimeClassName` | `apply` adds it automatically |
| Pass KBS URL to AA | initdata annotation (generated by `apply`) |
| Set OPA policy | initdata annotation (allow-all-except-exec by default) |
| Upload secrets to KBS | `kbs populate` |
| Create sealed k8s Secret | `apply` generates `myapp-sealed-secrets.yaml` |

### Understanding the Sealed Secret Flow

```bash
kubectl apply -f myapp.yaml        # plaintext k8s Secret in etcd
kubectl coco apply ...             # cococtl reads plaintext, generates sealed token
kubectl coco kbs populate          # plaintext stored in KBS (encrypted at rest)
kubectl delete secret myapp-secret # plaintext removed from etcd
kubectl apply -f myapp-coco.yaml   # pod uses sealed token as env var reference
                                   # -> CDH decodes token -> AA fetches from KBS
                                   # -> plaintext delivered inside TEE only
```

### Going Further

```bash
# Add an attestation initContainer that blocks until attestation succeeds
kubectl coco apply -f myapp.yaml --runtime-class kata-qemu-coco-dev --init-container

# Inspect the generated initdata
kubectl coco initdata dump --raw 2>/dev/null || \
  kubectl get pod verify-secret -o jsonpath='{.metadata.annotations.io\.katacontainers\.config\.hypervisor\.cc_init_data}'
```

### Cleanup

Follow the Lab 2 cleanup steps to clean the resources.

```bash
az group delete --name coco-lab --yes --no-wait
az group show --name coco-lab 2>/dev/null && echo "Still deleting..." || echo "Deleted."
```

---

## Lab 4: CoCo on a Real CVM via Peer-Pods (BYOM)

This lab runs a Kubernetes cluster on a standard VM and connects it to an Azure Confidential VM as a **peer pod**. Workload containers execute inside the hardware-backed SEV-SNP CVM, not on the K8s node. The BYOM (**Bring Your Own Machine**) provider of cloud-api-adaptor (CAA) manages the pre-existing CVM pool and delivers pod configuration to the CVM via SFTP.

```{figure} ../images/page_60.png
:alt: CoCo peer-pods architecture
:align: center
```

```{admonition} BYOM images are not in the release artifacts
:class: note
The CAA v0.21.0 release does not publish pre-built BYOM images. This lab includes a one-time build step to compile the BYOM binaries from source and push them to a container registry you control. The build takes roughly 2–3 hours on a 4-vCPU VM; plan accordingly or run it in a background session.
```

The lab uses two Azure VMs in the same VNet:

| VM | Role | Size | Image |
|----|------|------|-------|
| `k8s-vm` | K8s control plane + CAA + build host | Standard_D4s_v3 | Ubuntu 26.04 |
| `cvm-peer` | Peer pod CVM (workloads run here) | Standard_DC2as_v5 | Ubuntu 26.04 Pro CVM |

### Prerequisites

- Azure subscription with quota for **DCasv5-series** (CVM) and **D4s_v3** in East US or West Europe
- Azure CLI installed and authenticated (`az login`)
- A container registry you can push to (Docker Hub, quay.io, GitHub Container Registry, or ACR)

### Estimated Cost

| Resource | Size | Approx. cost |
|----------|------|-------------|
| `k8s-vm` | Standard_D4s_v3 | ~$0.19/hr |
| `cvm-peer` | Standard_DC2as_v5 | ~$0.10/hr |
| **Total** | | **~$0.29/hr** |

### Step 1: Provision Infrastructure

```bash
export LOCATION="eastus"
export RG="byom-lab"

az group create --name $RG --location $LOCATION

az vm create --resource-group $RG --name k8s-vm \
  --image "Canonical:ubuntu-26_04-lts:server:latest" \
  --size Standard_D4s_v3 --location $LOCATION \
  --admin-username azureuser --generate-ssh-keys \
  --vnet-name byom-lab-vnet --subnet byom-lab-subnet

az vm create --resource-group $RG --name cvm-peer \
  --image "Canonical:ubuntu-26_04-lts:pro-server-cvm:latest" \
  --size Standard_DC2as_v5 --location $LOCATION \
  --security-type ConfidentialVM \
  --os-disk-security-encryption-type VMGuestStateOnly \
  --enable-vtpm true --enable-secure-boot true \
  --admin-username azureuser --generate-ssh-keys \
  --vnet-name byom-lab-vnet --subnet byom-lab-subnet

# Allow SFTP (port 22) from the K8s VM to the CVM
az network nsg rule create --resource-group $RG \
  --nsg-name cvm-peerNSG --name allow-ssh-from-k8s \
  --priority 1010 --protocol Tcp --destination-port-ranges 22 --access Allow \
  --source-address-prefixes VirtualNetwork
```

Capture IPs for use throughout the lab:

```bash
export K8S_PUBLIC_IP=$(az vm show -g $RG -n k8s-vm --query publicIps -d -o tsv)
export CVM_PUBLIC_IP=$(az vm show -g $RG -n cvm-peer --query publicIps -d -o tsv)
export CVM_PRIVATE_IP=$(az vm show -g $RG -n cvm-peer --query privateIps -d -o tsv)
echo "k8s-vm:   $K8S_PUBLIC_IP"
echo "cvm-peer: $CVM_PUBLIC_IP (private: $CVM_PRIVATE_IP)"
```

### Step 2: Setup BYOM SSH Keys

The SSH keys allow CAA running in `k8s-vm` to reach `cvm-peer` via SFTP:

```bash
ssh-keygen -f ./byom-id_rsa -N "" -t rsa -C "byom-peerpod"
```

Copy the BYOM public key to `k8s-vm` and `cvm-peer`:

```bash
# From your local machine
scp ./byom-id_rsa.pub azureuser@${K8S_PUBLIC_IP}:~/byom-id_rsa.pub
scp ./byom-id_rsa.pub azureuser@${CVM_PUBLIC_IP}:~/byom-id_rsa.pub
```

Copy the BYOM private key to `k8s-vm`:

```bash
# From your local machine
scp ./byom-id_rsa azureuser@${K8S_PUBLIC_IP}:~/byom-id_rsa
```

### Step 3: Set Up a Single-Node Kubernetes Cluster

SSH into `k8s-vm` and install containerd, kubeadm, Docker (needed for the BYOM image build), and Go:

```bash
ssh azureuser@${K8S_PUBLIC_IP}
```

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

### Step 4: Install helm and cococtl

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

### Step 5: Prepare the CVM as a Peer Pod

In a separate terminal window, ensure you have all the required variables set.

SSH into `cvm-peer`:

```bash
ssh azureuser@${CVM_PUBLIC_IP}
```

On `cvm-peer`, install Docker and clone CAA:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

sudo apt-get install -y make git
git clone --depth=1 --branch v0.21.0 \
  https://github.com/confidential-containers/cloud-api-adaptor.git
```

On `cvm-peer`, run the BYOM setup script. This creates the `peerpod` SFTP user, installs all guest-component binaries from the BYOM image, and enables the required systemd services:

```bash
cd ~/cloud-api-adaptor/src/cloud-api-adaptor

sudo env \
  PODVM_BYOM_BINARIES_IMAGE=quay.io/bpradipt/podvm-byom-binaries-ubuntu-amd64:v0.21.0 \
  SSH_PUBLIC_KEY_PATH=/home/azureuser/byom-id_rsa.pub \
  bash hack/setup-podvm-byom.sh
```

The script extracts binaries from the image and installs them as systemd services. Verify the key services are active:

```bash
systemctl is-active sftp-dir.service process-user-data.path kata-agent.path
# active
# active
# active
```

### Step 6: Verify SFTP access from the k8s-vm

In a separate terminal window, SSH into `k8s-vm`:

```bash
ssh azureuser@${K8S_PUBLIC_IP}
```

Set the CVM_PRIVATE_IP (from step 1) and verify SFTP access:

```bash
export CVM_PRIVATE_IP=<SET>
ssh -i ~/byom-id_rsa peerpod@${CVM_PRIVATE_IP} -s sftp <<< '' && \
  echo "SFTP access OK" || echo "SFTP access FAILED"
```

### Step 7: Deploy the Peerpods Helm Chart

Create a Kubernetes secret with the BYOM SSH keys:

```bash
kubectl create namespace confidential-containers-system

kubectl create secret generic byom-ssh-keys \
  -n confidential-containers-system \
  --from-file=id_rsa=/home/azureuser/byom-id_rsa \
  --from-file=id_rsa.pub=/home/azureuser/byom-id_rsa.pub
```

Deploy the peerpods chart (version 0.3.0 ships with CAA v0.21.0). This chart installs kata-deploy (which configures the `kata-remote` runtime class) and the CAA daemonset:

```{code-block} yaml
:caption: byom-values.yaml
cat > byom-values.yaml << 'EOF'
provider: byom

image:
  name: quay.io/bpradipt/cloud-api-adaptor
  tag: byom-v0.21.0
  pullPolicy: Always

providerConfigs:
  byom:
    VM_POOL_IPS: "${CVM_PRIVATE_IP}"
    SSH_USERNAME: "peerpod"
    SSH_TIMEOUT: "30"

webhook:
  enabled: false

secrets:
  mode: reference
  existingSshKeySecretName: byom-ssh-keys

kata-deploy:
  enabled: true
  snapshotter:
    setup:
      - nydus
EOF
```

Label the Node for the CoCo DaemonSet:

```bash
kubectl label node "$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')" \
  "node.kubernetes.io/worker="
```

Install the Peerpods Helm Chart:

```bash
helm install peerpods \
  oci://ghcr.io/confidential-containers/cloud-api-adaptor/charts/peerpods \
  --version 0.3.0 \
  -f byom-values.yaml \
  -n confidential-containers-system \
  --wait \
  --timeout 10m
```

Verify all pods are running:

```bash
kubectl get pods -n confidential-containers-system
# cloud-api-adaptor-daemonset-...   1/1   Running
# kata-deploy-...                   1/1   Running
# peerpodctrl-controller-manager-.. 2/2   Running

kubectl get runtimeclass | grep kata-remote
# kata-remote   kata-remote   ...
```

Check the CAA log to confirm the BYOM IP pool was initialized:

```bash
kubectl logs -n confidential-containers-system daemonset/cloud-api-adaptor-daemonset | grep "BYOM provider"
# Initialized BYOM provider with 1 VMs (1 available, 0 in use)
```

### Step 8: Deploy a Pod on the CVM

Create a simple test pod using the `kata-remote` runtime:

```{code-block} yaml
:caption: coco-peer-pod.yaml
cat > coco-peer-pod.yaml << 'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: coco-peer-pod
spec:
  runtimeClassName: kata-remote
  containers:
    - name: busybox
      image: quay.io/prometheus/busybox:latest
      imagePullPolicy: Always
      command: ["sleep", "infinity"]
  restartPolicy: Never
EOF
```

```bash
kubectl apply -f coco-peer-pod.yaml
kubectl get pod coco-peer-pod --watch
# coco-peer-pod   0/1   ContainerCreating   ...
# coco-peer-pod   1/1   Running             ...   (typically 5–10 s)
```

Confirm the pod is running on the CVM by comparing kernels. The `-fde` suffix on the pod's kernel identifies the Azure Confidential VM kernel (Full Disk Encryption enabled):

```bash
kubectl exec coco-peer-pod -- uname -r   # e.g. 7.0.0-1004-azure-fde  (CVM kernel)
uname -r                                 # e.g. 7.0.0-1004-azure        (host kernel)
```

The two kernel strings will differ, confirming that the pod sandbox is running on the CVM, not the K8s node.

Check the vCPU count inside the pod:

```bash
kubectl exec coco-peer-pod -- nproc      # 2  (DC2as_v5 CVM)
nproc                                    # 4  (D4s_v3 k8s-vm)
```

### What Just Happened

| Step | Component | Role |
|------|-----------|------|
| Pod scheduled | Kubernetes scheduler | Assigns pod to k8s-vm node |
| CVM allocated | CAA BYOM provider | Selects cvm-peer from IP pool |
| Config delivered | CAA → SFTP → `/media/cidata/user-data` | Writes pod spec to CVM |
| Image pulled | kata-agent inside CVM | Pulls container image in the CVM and starts the pod|

### Cleanup

```bash
az group delete --name byom-lab --yes --no-wait
az group show --name byom-lab 2>/dev/null && echo "Still deleting..." || echo "Deleted."
```
