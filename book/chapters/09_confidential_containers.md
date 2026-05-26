# Confidential Containers (CoCo)

## What Are Confidential Containers?

Confidential Containers — a generic term for containers deployed inside Trusted Execution Environments (TEEs).

## CNCF Confidential Containers (CoCo) Project

The CNCF CoCo project provides a common foundation for deploying a pod inside a CVM (using [Kata Containers](https://katacontainers.io/)) on any Kubernetes cluster, and includes Trustee as the remote attestation service.

```{figure} ../images/page_57.png
:alt: CNCF Confidential Containers Project overview
:align: center
```

CoCo provides two deployment approaches:

1. Confidential containers using VM-based TEEs on a local hypervisor
2. Confidential containers using VM-based TEEs on a remote hypervisor (peer-pods)

---

## From Kata to CoCo: The Key Difference

Kata Containers **protects the host from the workload**.

CoCo **protects the workload from the host**.

| | Kata Containers | CoCo |
|---|---|---|
| **Threat model** | Protect host from the workload | Protect workload from the host |
| **Who's protected** | Cluster infra | The workload |
| **Image download** | May be on the worker node or inside the VM | Always inside the CVM |
| **TEE required** | No | Yes |
| **Attestation** | No | Yes |

---

## Architecture: CoCo/bare-metal (Local Hypervisor)

The Confidential VM (CVM) runs on the worker node. Inside the CVM: kata-agent manages the lifecycle of the pod (containers), image-rs (part of kata-agent) downloads the container images, the Confidential Data Hub (CDH) serves as the secret retrieval proxy, and the Attestation Agent (AA) handles the attestation process. Container images are always downloaded inside the CVM, never on the host.

```{figure} ../images/page_59.png
:alt: High Level Architecture — CoCo/bare-metal
:align: center
```

---

## Architecture: CoCo/peer-pods (Remote Hypervisor)

The Confidential VM runs external to the worker node. The worker node hosts only the kata-runtime and cloud-api-adaptor.

```{figure} ../images/page_60.png
:alt: High Level Architecture — CoCo/peer-pods
:align: center

```

---

## CoCo Threat Model

The untrusted components include the host OS, hypervisor, cloud provider software, other VMs on the same host, other processes on the worker node, and the Kubernetes control plane (kubelet, etcd, API server).

Application code vulnerabilities, availability attacks, and physical attacks are out of scope.

---

## Integrity Protection for CoCo CVM Images

Dm-verity protected read-only OS rootfs prevents tampering with the CVM image. The kernel, kernel cmd line, and initrd are measured and included in the attestation report. Any change to the OS image changes the measurements, causing attestation to fail.

```{figure} ../images/page_62.png
:alt: Integrity Protection for CoCo CVM images
:align: center
```

Ref: [Building trust into OS images](https://confidentialcontainers.org/blog/2024/03/01/building-trust-into-os-images-for-confidential-containers/)

---

## CoCo CVM Requirements

Following are the key CVM requirements for CoCo:

1. Read-only rootfs with integrity protection (dm-verity/fs-verity + composefs)
2. Memory-backed filesystem or LUKS-encrypted ephemeral disk for read-write storage (container images)

### Read-Only Rootfs with Integrity Protection

- **dm-verity** — Linux kernel feature providing transparent integrity checking of block devices
- **fs-verity** — file-level integrity verification
- **composefs** — combining read-only fs-verity protected files with a mutable upper layer

### Encrypted Ephemeral Disk

For container image layers and ephemeral writes, a **LUKS-encrypted disk** uses an **ephemeral key** generated inside the TEE at runtime — never persisted, never leaving the TEE.

