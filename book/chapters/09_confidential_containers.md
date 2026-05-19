# Confidential Containers (CoCo)

## What Are Confidential Containers?

```{figure} ../images/page_56.png
:alt: Confidential Containers definition
:align: center
Confidential Containers — a generic term for containers deployed inside Trusted Execution Environments (TEEs).
```

> *"The CoCo project aims to enable users to run containers inside TEEs on any Kubernetes cluster, with minimal changes to their existing applications and workflows."*

## CNCF Confidential Containers Project

```{figure} ../images/page_57.png
:alt: CNCF Confidential Containers Project overview
:align: center
The CNCF CoCo project provides a common foundation for deploying containers inside VM- or process-based TEEs on any Kubernetes cluster, and includes Trustee — a remote attestation service based on IETF RATS.
```

```{figure} ../images/page_58.png
:alt: CNCF CoCo three deployment approaches
:align: center
CoCo provides three deployment approaches: (1) Confidential containers using VM-based TEEs on a local hypervisor; (2) Confidential containers using VM-based TEEs on a remote hypervisor (peer-pods); (3) Confidential containers using process-based TEEs (e.g., Intel SGX).
```

---

## From Kata to CoCo: The Key Difference

Kata Containers **protects the host from the workload**.
CoCo **protects the workload from the host**.

| | Kata Containers | CoCo |
|---|---|---|
| **Threat model** | Host ← Workload | Host → Workload |
| **Who's protected** | Infrastructure | The application |
| **Image download** | On worker node | Inside the CVM |
| **Secrets via** | K8s Secrets (etcd) | Sealed Secrets (attestation) |
| **TEE required** | No | Yes |
| **Attestation** | No | Yes |

---

## Architecture: CoCo/bare-metal (Local Hypervisor)

```{figure} ../images/page_59.png
:alt: High Level Architecture — CoCo/bare-metal
:align: center
CoCo/bare-metal: the Confidential VM (CVM) runs on the worker node inside the TEE hardware. Inside the CVM: kata-agent manages containers, image-rs downloads encrypted images, the Confidential Data Hub (CDH) serves as the secret retrieval proxy, and the Attestation Agent (AA) produces hardware-backed evidence. Container images are always downloaded inside the CVM, never on the host.
```

---

## Architecture: CoCo/peer-pods (Remote Hypervisor)

```{figure} ../images/page_60.png
:alt: High Level Architecture — CoCo/peer-pods
:align: center
CoCo/peer-pods: same as bare-metal but the Confidential VM runs externally in the cloud. The worker node hosts only the kata-runtime and cloud-api-adaptor. The CVM in the cloud handles all TEE operations, attestation, and encrypted image downloads.
```

---

## CoCo Threat Model

```{figure} ../images/page_61.png
:alt: CoCo Threat Model — protect the workload from the host
:align: center
CoCo threat model: untrusted components include the host OS, KVM hypervisor, cloud provider software, other VMs on the same host, other processes on the host machine, and the Kubernetes control plane (kubelet, etcd, API server). Out of scope: application code vulnerabilities, availability attacks, and software TEEs.
```

---

## Integrity Protection for CoCo CVM Images

```{figure} ../images/page_62.png
:alt: Integrity Protection for CoCo CVM images
:align: center
dm-verity protected read-only OS rootfs prevents tampering with the CVM image. The kernel, kernel cmdline, and initrd are measured and included in the attestation report. Any change to the OS image changes the measurements, causing attestation to fail.
```

---

## CoCo CVM Requirements

```{figure} ../images/page_63.png
:alt: CoCo CVM Requirements
:align: center
CoCo CVM requirements: (1) read-only rootfs with integrity protection (dm-verity/fs-verity + composefs); (2) memory-backed filesystem or LUKS-encrypted ephemeral disk for read-write storage (container images); (3) measured boot support.
```

### Read-Only Rootfs with Integrity Protection

- **dm-verity** — Linux kernel feature providing transparent integrity checking of block devices
- **fs-verity** — file-level integrity verification
- **composefs** — combining read-only fs-verity protected files with a mutable upper layer

### Encrypted Ephemeral Disk

For container image layers and ephemeral writes, a **LUKS-encrypted disk** uses an **ephemeral key** generated inside the TEE at runtime — never persisted, never leaving the TEE.

---

## Integrity Protection for CoCo Workloads

```{figure} ../images/page_64.png
:alt: Integrity Protection for CoCo workloads
:align: center
Challenges: dynamic pod mutations (container creation/updates/deletions via Kubernetes RPC) and automatic addition of SERVICE_* environment variables. Solutions: policy enforcement (genpolicy/KubeArmor), init-data for measured initial configuration, and change logging via hardware RoT.
```

---

## Trustee Architecture

```{figure} ../images/page_65.png
:alt: Trustee Architecture
:align: center
Trustee architecture: the CVM's Attestation Agent sends evidence to the KBS. The KBS forwards it to the AS for verification against the RVPS. Upon a positive result, the KBS releases the requested resource from the KMS backend.
```

```{figure} ../images/page_66.png
:alt: Trustee Architecture — end to end example
:align: center
End-to-end Trustee flow: a CVM attests to request a resource. The KBS appraises the attestation result (EAR/AR4SI) before releasing a key or secret. Trustee can delegate verification to external services and back secrets with KMS, Vault, HSM, or Kubernetes Secrets.
```

---

## CoCo Attestation

```{figure} ../images/page_67.png
:alt: CoCo Attestation — Background Check and Passport Check Models
:align: center
CoCo performs lazy attestation when secrets are required. Two models: Background Check (TEE sends evidence to Verifier; Verifier returns result to Relying Party) and Passport Check (TEE receives a reusable attestation token from the Verifier). Both are based on the IETF RATS standard.
```

---

## CoCo Workload APIs

```{figure} ../images/page_68.png
:alt: CoCo Workload APIs
:align: center
Secret Resource Release API: GET http://127.0.0.1:8006/cdh/resource/{repo}/{type}/{tag} inside the pod. Triggers attestation if not already performed, returns the decrypted secret only on attestation success. Sealed Secrets: encrypted Kubernetes secrets that only unseal inside the TEE after attestation.
```

**Example — retrieve an encryption key from KBS:**
```bash
curl http://127.0.0.1:8006/cdh/resource/default/enckey/key.pem
```

---

## CoCo Sealed Secrets

```{figure} ../images/page_69.png
:alt: CoCo Sealed Secrets flow
:align: center
Sealed secrets flow: (1) create a sealed secret config JSON pointing to the KBS resource; (2) encode it as a sealed secret value; (3) create a Kubernetes Secret from it — etcd only stores the sealed (encrypted) value; (4) when the pod runs in the TEE, CDH attests to Trustee and retrieves the real secret; (5) the container sees the plaintext value via env var or mounted volume.
```

With sealed secrets, etcd **only ever contains the encrypted form**. The actual secret never exists outside the TEE.

---

## Mapping CoCo to RATS Standard

| CoCo Component | RATS Role |
|---|---|
| Attestation Agent (AA) | Attester |
| AMD SP / Intel TDX Module | Hardware RoT |
| Attestation Service (AS) | Verifier |
| Reference Value Provider (RVPS) | Reference Value Provider |
| Key Broker Service (KBS) | Relying Party |
| CVM evidence | Evidence |
| Attestation Result (EAR/AR4SI) | Attestation Result |
