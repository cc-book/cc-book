# Kata Containers

[Kata Containers](https://katacontainers.io) is the foundational building block for CNCF Confidential Containers. It provides lightweight VM-based pod sandboxing for Kubernetes.

## What is Kata Containers?

Kata Containers runs each Kubernetes Pod inside a dedicated lightweight Virtual Machine, providing hardware-enforced isolation between pods and the host. Containers normally share the host OS kernel — Kata gives each pod its own kernel.

### Kata Threat Model

```{figure} ../images/page_45.png
:alt: Kata Threat Model — protect the host from the workload
:align: center
Kata's threat model: protect the host from the workload. Untrusted components: the workload (container image). Out of scope: vulnerabilities within the application code itself, and availability attacks.
```

---

## Architecture: Kata/Local Hypervisor (Kata/Qemu)

```{figure} ../images/page_42.png
:alt: High Level Architecture — Kata/local-hypervisor (KVM/Qemu)
:align: center
Kata/Qemu: each Pod runs in a Linux guest VM on the same worker node. The kata-runtime communicates with kata-agent over gRPC/vsock. Container images are downloaded on the worker node and shared with the Kata VM using virtiofs. The Kata VM and the worker node are co-located.
```

### Key Components

| Component | Role |
|---|---|
| `containerd-shim-kata-v2` | Kata runtime shim — manages VM lifecycle |
| `kata-agent` | In-VM agent — executes container operations |
| `virtiofs` | Shares container image filesystems (host → VM) |
| `vsock` | Low-latency VM socket for host↔VM communication |

### Control Plane Communication (Kata/Qemu)

```{figure} ../images/page_46.png
:alt: Kata/Qemu Control Plane Communication
:align: center
The containerd-shim-kata-v2 communicates with kata-agent running inside the Kata VM over gRPC/vsock. The Kata VM runs on the same worker node as the runtime.
```

---

## Architecture: Kata/Remote Hypervisor (Kata/Peer-Pods)

```{figure} ../images/page_43.png
:alt: High Level Architecture — Kata/remote-hypervisor (peer-pods)
:align: center
Kata/Peer-Pods: the Kata VM runs external to the worker node (on a cloud VM or remote machine). cloud-api-adaptor creates the VM using IaaS APIs (AWS, Azure, GCP, IBM Cloud, Libvirt). Container images are downloaded inside the remote VM by image-rs. Communication is over TLS/TCP.
```

### How Peer-Pods Works

1. `kubelet` schedules a pod to the worker node
2. `kata-runtime` calls `cloud-api-adaptor` to create a VM using IaaS APIs
3. The remote VM starts and runs `agent-protocol-forwarder`
4. `cloud-api-adaptor` tunnels kata-shim ↔ kata-agent communication over **TLS-encrypted TCP**
5. Container images are downloaded **inside the remote VM** by `image-rs`

### Peer-Pods: Additional Details

```{figure} ../images/page_44.png
:alt: Kata with remote hypervisor — cont
:align: center
Remote hypervisor support via cloud-api-adaptor: creates Kata VMs using Cloud/IaaS APIs, supporting AWS, Azure, GCP, IBM Cloud, and Libvirt (for on-prem). The agent-protocol-forwarder enables shim ↔ kata-agent communication over TCP.
```

### Control Plane Communication (Peer-Pods)

```{figure} ../images/page_48.png
:alt: Kata/Peer-Pods Control Plane Communication diagram
:align: center
Peer-pods control plane: kata-shim → (Unix socket) → cloud-api-adaptor → (gRPC over TLS/TCP) → agent-protocol-forwarder → (Unix socket) → kata-agent. The TLS TCP connection secures all control traffic between the worker node and the remote Kata VM.
```

---

## Data Plane Communication

### Peer-Pods Data Plane

```{figure} ../images/page_49.png
:alt: Kata/Peer-Pods Data Plane Communication
:align: center
Pod networking for peer-pods uses a VXLAN tunnel connecting the worker node to the external Kata VM. All pod traffic originating in the Kata VM flows via the worker node. Note: the VXLAN tunnel is unencrypted — pod-level mTLS is recommended.
```

### OVN-Kubernetes Data Plane

```{figure} ../images/page_50.png
:alt: Kata/Peer-Pods Data Plane Communication — OVN Kubernetes
:align: center
Peer-pods networking with OVN-Kubernetes: the SDN overlay handles connectivity between the worker node's network namespace and the Kata VM's pod network. OVN manages the VXLAN tunnels and overlay routing.
```

---

## Storage Model

```{figure} ../images/page_51.png
:alt: Kata/Peer-Pods storage model
:align: center
Container images are downloaded inside the Kata VM (not shared from the host via virtiofs). Persistent storage must be directly mounted inside the Kata VM — traditional CSI plugins that mount on the host and bind-mount into the pod do not work for peer-pods without additional configuration.
```

---

## Peer-Pods Use Cases

```{figure} ../images/page_52.png
:alt: Kata/Peer-Pods Use Case — pod sandboxing without node virtualization
:align: center
Use case 1: Create kernel-isolated pods (pod sandboxing) without requiring KVM/virtualization on the worker nodes. The worker node is just a scheduling point; the VM runs externally.
```

```{figure} ../images/page_53.png
:alt: Kata/Peer-Pods Use Case — cloud bursting and accelerators
:align: center
Use case 2: Cloud bursting and accelerator access. Spin up large cloud VMs with GPUs or specialized hardware for specific workloads while keeping orchestration in your existing cluster.
```

```{figure} ../images/page_54.png
:alt: Kata/Peer-Pods Use Case — multi-architecture workloads
:align: center
Use case 3: Multi-architecture workload support from a single cluster. Schedule x86 pods locally and ARM/other-arch pods as peer-pods on matching cloud instance types.
```

---

## Kata/Qemu vs Kata/Peer-Pods Comparison

| Dimension | Kata/Qemu (local) | Kata/Peer-Pods (remote) |
|---|---|---|
| **VM location** | Same worker node | External cloud VM |
| **VM creation** | QEMU/KVM | Cloud/IaaS API |
| **Image delivery** | virtiofs from host | Downloaded inside VM |
| **Control plane** | gRPC over vsock | gRPC over TLS/TCP |
| **Node requirements** | KVM+QEMU on node | None |
| **CC support** | ✔ (CVM on node) | ✔ (CVM on cloud) |
