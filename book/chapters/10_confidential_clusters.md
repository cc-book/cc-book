# Confidential Cluster

A **Confidential Cluster** is a Kubernetes cluster with **Confidential Virtual Machines (CVMs)** as Kubernetes nodes. Every node is a CVM, so the cloud provider and infrastructure administrator cannot inspect node memory, including the workloads, secrets, and cluster state running on those nodes.

```{figure} ../images/page_36.png
:alt: Confidential Cluster — Kubernetes nodes run inside CVMs
:align: center
```

---

## Threat Model

The confidential cluster threat model differs from both standard Kubernetes and Confidential Containers (Pillar 2).

**What is untrusted:**

| Component | Untrusted? | Why |
|---|---|---|
| Cloud provider / IaaS | ✔ Yes | Controls the hardware and hypervisor |
| Infrastructure admin | ✔ Yes | Can access the underlying host |
| Hypervisor | ✔ Yes | Excluded from the TCB by the TEE |
| Other VMs on the host | ✔ Yes | Memory isolation enforced by hardware |

**What is trusted:**

| Component | Trusted? | Why |
|---|---|---|
| Kubernetes cluster admin | ✔ Yes | Runs control plane components inside CVMs |
| Worker node software | ✔ Yes (once attested) | Node is a CVM with measured boot |
| Kubelet and container runtime | ✔ Yes | Running inside the CVM |

The key property: **the cluster admin is trusted**, but the **infrastructure admin is untrusted**. Note that for Confidential Containers both the cluster admin and infrastructure admin are untrusted.

:::{admonition} Implication for Multi-Tenancy
:class: warning
Because the cluster admin is in the trust boundary, a confidential cluster is **not suitable for multi-tenant workloads where tenants distrust each other or the cluster operator**. For multi-tenancy, Pillar 2 (Confidential Containers) is the right choice — each Pod has its own TEE and the cluster admin is untrusted.
:::

---

## How It Works

When a confidential cluster node boots, it goes through the same measured boot process as any CVM. The critical addition is that **the cluster admission gate requires successful remote attestation before a node can join**.

```{mermaid}
sequenceDiagram
    participant Node as New Worker Node (CVM)
    participant HW as TEE Hardware (AMD/Intel)
    participant AS as Attestation Service
    participant CP as Cluster Control Plane

    Node->>HW: Boot with measured boot (UEFI → kernel → OS)
    HW-->>Node: Signed attestation report (PCR measurements)
    Node->>AS: Submit attestation report
    AS->>AS: Verify hardware signature + check measurements
    AS-->>Node: Attestation token (if trusted)
    Node->>CP: Join request + attestation token
    CP->>CP: Verify token, check node identity
    CP-->>Node: Cluster credentials & secrets released
    Note over Node,CP: Node is now a trusted cluster member
```

Only a node running the **expected OS image inside a genuine TEE** passes attestation and receives the credentials needed to join. A compromised or unverified node is denied admission.

---

## Key Capabilities

### Node Remote Attestation

Every node that attempts to join the cluster presents a hardware-signed attestation report. The control plane (or a delegated attestation service) verifies:

1. The node is running inside a genuine hardware TEE
2. The expected node OS image was booted
3. The hardware firmware is at a trusted patch level

This gates cluster membership based on the result of attestation.

### Encrypted Disk Storage

Worker node disks must be encrypted to prevent the hypervisor from reading the persistent data. Boot disk encryption is tied to attestation: the decryption key is only released after the node proves it is running the correct software inside a TEE.

### Encrypted Cluster Networking

In a standard cluster, inter-node traffic is plaintext on the cluster network — visible to anyone with host access. A confidential cluster implementation must use **encrypted networking between nodes** (e.g., using WireGuard), so the infrastructure admin cannot observe intra-cluster traffic.

---

## Spectrum of Implementations

Not all confidential cluster deployments provide the same guarantees. There is a spectrum from **partial** (worker nodes only) to **full** (entire cluster).

### Partial: Worker Nodes Only

Only the worker nodes run inside CVMs. The Kubernetes control plane (API server, etcd, scheduler) runs on regular infrastructure managed by the cloud provider.

**Security properties:**

- Workload memory is encrypted and isolated from the host
- Control plane state (etcd, secrets) is **not** in a TEE
- Kubernetes secrets in etcd are accessible to the cloud provider unless separately encrypted
- Node attestation may or may not be enforced at admission

**Examples:** [GKE Confidential Nodes](https://cloud.google.com/blog/products/identity-security/announcing-general-availability-of-confidential-gke-nodes), 

### Full: Entire Cluster

All nodes, including control plane nodes run inside CVMs.

**Additional security properties over partial:**

- etcd (cluster state) is inside a TEE
- Cluster keys are managed within the TEE
- A single verifiable attestation covers the whole cluster
- Encrypted networking between all nodes

**Examples:** [Constellation (Edgeless Systems)](https://docs.edgeless.systems/constellation) - *this is no longer maintained*, [OpenShift Confidential Cluster (Red Hat)](https://www.redhat.com/en/blog/confidential-cluster-running-red-hat-openshift-clusters-confidential-nodes)

---