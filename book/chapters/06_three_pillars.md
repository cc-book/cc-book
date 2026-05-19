# Three Pillars of Confidential Computing

Confidential Computing in cloud-native environments is organized into three deployment tiers, each building on the previous one.

## Overview

```{figure} ../images/page_34.png
:alt: Three Pillars of Confidential Computing
:align: center
The three pillars: (1) Confidential Virtual Machine — run a VM inside a TEE (the foundation); (2) Confidential Container — run a Kubernetes Pod inside a CVM inside a TEE; (3) Confidential Cluster — run Kubernetes nodes themselves inside CVMs.
```

---

## Pillar 1: Confidential Virtual Machine (CVM)

A **Confidential Virtual Machine** is a VM that runs inside a TEE. It is the foundational building block.

**What it provides:**
- VM memory is hardware-encrypted — the hypervisor cannot read it
- Measured boot proves what software started inside the VM
- Remote attestation allows external parties to verify the CVM's state
- TCB is reduced — you no longer need to trust the hypervisor or host OS

| Technology | CPU Architecture | TCB includes Hypervisor? |
|---|---|---|
| AMD SEV-SNP | x86 (AMD EPYC) | Optional (depends on vTPM placement) |
| Intel TDX | x86 (Intel Xeon) | Optional |
| IBM Secure Execution | IBM Z/LinuxONE | No |
| IBM PEF | IBM POWER | No |

---

## Pillar 2: Confidential Container (Pod)

```{figure} ../images/page_35.png
:alt: Confidential Containers — run a Kubernetes Pod inside a CVM
:align: center
Confidential Containers: each Kubernetes Pod runs inside its own Confidential VM (CVM), which in turn runs inside a TEE. The Kubernetes control plane (kubelet, etcd) remains outside and is treated as untrusted.
```

A **Confidential Container** runs a Kubernetes Pod inside a CVM (which itself runs inside a TEE).

**Key properties:**
- Each Pod gets its own CVM — strong isolation between Pods
- The Kubernetes control plane (kubelet, containerd) is **outside the TEE** — it is untrusted
- Container images are **downloaded inside the CVM**, not on the host
- Secrets are delivered via **remote attestation**, not via K8s Secrets in etcd
- **Policy enforcement** controls what the K8s control plane can instruct the CVM to do

**Implementation:** The [CNCF Confidential Containers (CoCo) project](https://github.com/confidential-containers) is the primary open-source implementation.

---

## Pillar 3: Confidential Cluster

```{figure} ../images/page_36.png
:alt: Confidential Cluster — Kubernetes nodes run inside CVMs
:align: center
Confidential Cluster: the Kubernetes nodes themselves run as CVMs inside TEEs. Even the Kubernetes control plane components can run inside CVMs, providing the strongest isolation model — protecting workloads even from cluster administrators.
```

A **Confidential Cluster** runs Kubernetes **nodes** themselves inside CVMs (which run inside TEEs).

| | Confidential Containers | Confidential Cluster |
|---|---|---|
| **What's in the TEE** | Individual pods | Entire K8s nodes |
| **K8s control plane** | Untrusted (on regular infra) | Trusted (inside CVMs) |
| **Trust boundary** | Pod level | Cluster level |
| **Use case** | Workload isolation | Full cluster isolation |
| **Complexity** | Medium | High |

---

## Choosing the Right Pillar

| Requirement | Recommended Pillar |
|---|---|
| Protect a single sensitive VM | Pillar 1: CVM |
| Run K8s pods with secret data, protect from infra admin | Pillar 2: Confidential Containers |
| Protect from K8s cluster admin as well | Pillar 3: Confidential Cluster |
| AI model serving (IP protection) | Pillar 2 (CoCo + KServe) |
| Multi-party analytics | Pillar 2 or 3 depending on scale |

:::{admonition} Practical Recommendation
:class: tip
For most organizations starting with Confidential Computing, **Pillar 2 (Confidential Containers)** offers the best balance of security, practicality, and ecosystem support. It integrates with existing Kubernetes workflows while protecting workloads from both the cloud provider and infrastructure administrators.
:::
