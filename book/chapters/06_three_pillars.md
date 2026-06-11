# Three Pillars of Confidential Computing

Confidential Computing in cloud-native environments is organized into three deployment tiers, each building on the previous one.

The three pillars:

1. Confidential Virtual Machine — run a VM inside a TEE (the foundation)
2. Confidential Container — run a Kubernetes Pod inside a CVM
3. Confidential Cluster — run Kubernetes nodes themselves inside CVMs

---

## Pillar 1: Confidential Virtual Machine (CVM)

A **Confidential Virtual Machine** is a VM that runs inside a TEE. It is the foundational building block.

**What it provides:**

- VM memory is hardware-encrypted — the hypervisor cannot read it
- Measured boot proves what software started inside the VM
- Remote attestation allows external parties to verify the CVM's state
- TCB is reduced — you no longer need to trust the hypervisor or host OS

---

## Pillar 2: Confidential Container (Pod)

A **Confidential Container** runs a Kubernetes Pod inside a CVM (which itself runs inside a TEE).

**Key properties:**

- Each Pod gets its own CVM — strong isolation between Pods
- The Kubernetes control plane (kubelet, containerd/crio) is **outside the TEE** — it is untrusted
- Container images are **downloaded inside the CVM**, not on the worker node.
- Secrets are delivered via **remote attestation**, not via K8s Secrets in etcd
- **Policy enforcement** controls what the K8s control plane can instruct the CVM to do

```{figure} ../images/page_35.png
:alt: Confidential Containers — run a Kubernetes Pod inside a CVM
:align: center
```

**Implementation:** The [CNCF Confidential Containers (CoCo) project](https://github.com/confidential-containers) is the primary open-source implementation.

---

## Pillar 3: Confidential Cluster

A **Confidential Cluster** runs Kubernetes **nodes** themselves inside CVMs (which run inside TEEs).

```{figure} ../images/page_36.png
:alt: Confidential Cluster — Kubernetes nodes run inside CVMs
:align: center
```

## Comparing the Pillars

| | Confidential VM | Confidential Containers | Confidential Cluster |
|---|---|---|---|
| **What's in the TEE** | The entire VM | The entire VM including the pod | Entire K8s nodes |
| **K8s control plane** | N/A | Untrusted (on regular infra) | Trusted (inside CVMs) |
| **Trust boundary** | VM level | VM level | Cluster level |
| **Admin Trust** | Infra admin is untrusted | Infra and cluster admin are untrusted | Infra admin is untrusted |
| **Multi-tenancy** | N/A | Since cluster admin is untrusted, each pod can belong to different tenant | Since cluster admin is trusted, it can't be used for multi-tenancy |
| **Operation Type** | Standalone — no K8s required | Day 2 Operation — can be deployed on existing K8s cluster | Day 1 Operation — requires new K8s cluster |
| **Use case** | Protect standalone workloads | Workload isolation within K8s | Full cluster isolation |

---

## Choosing the Right Pillar

| Requirement | Recommended Pillar |
|---|---|
| Protect standalone code | Pillar 1: CVM |
| Protect K8s pods from each other and cluster/infra admin | Pillar 2: Confidential Containers |
| Protect entire K8s cluster from infra admin | Pillar 3: Confidential Cluster |

:::{admonition} Practical Recommendation
:class: tip
For most organizations starting with Confidential Computing, **Pillar 2 (Confidential Containers)** offers the best balance of security, practicality, and ecosystem support. It integrates with existing Kubernetes workflows while protecting workloads from both the cluster and infrastructure administrators.
:::
