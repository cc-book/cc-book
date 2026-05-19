# Trusted Execution Environments (TEEs)

## What is a TEE?

```{figure} ../images/page_22.png
:alt: Trusted Execution Environments definition
:align: center
A TEE provides hardware-enforced isolation that protects in-memory data from unauthorised entities. Defining characteristics: memory encryption, isolation, remote attestation, and data integrity.
```

A **Trusted Execution Environment (TEE)** is a hardware-enforced, isolated region of a processor that protects code and data from unauthorized access — including from privileged software like the OS, hypervisor, or firmware.

| Characteristic | Description |
|---|---|
| **Memory Encryption** | All data in the TEE's memory is encrypted by the hardware. Even physical DRAM access reveals only ciphertext. |
| **Isolation** | The TEE is isolated from other processes, VMs, and the host OS. Hardware enforces this boundary. |
| **Remote Attestation** | The TEE can prove its identity and integrity to remote parties cryptographically. |
| **Data Integrity** | The hardware detects and prevents tampering with TEE memory. |

---

## Types of TEEs

```{figure} ../images/page_23.png
:alt: Types of TEEs — VM-based and Process-based
:align: center
VM-based TEEs (AMD SEV-SNP, Intel TDX, IBM Secure Execution, IBM PEF) encrypt an entire VM's memory. Process-based TEEs (Intel SGX) isolate only the sensitive portion of an application inside an enclave, requiring a trust/untrust split.
```

### VM-Based TEEs

Memory is encrypted along a traditional VM boundary. The hypervisor cannot read VM memory.

**Examples:** AMD SEV-SNP, Intel TDX, IBM Secure Execution, IBM PEF

**Advantages:**
- Protects entire existing applications without code changes
- Supports standard Linux distributions
- Scales to large memory and multi-core workloads

### Process-Based TEEs

An app is split into trusted and untrusted components. Only the sensitive part runs in encrypted memory.

**Example:** Intel SGX

**Trade-offs:**
- Smaller attack surface (only enclave code is in the TCB)
- Requires application refactoring to separate trusted/untrusted components
- Historically constrained to small enclave memory sizes

---

## TCB Reduction with Confidential Computing

```{figure} ../images/page_24.png
:alt: TCB reduction with Confidential Computing
:align: center
Confidential Computing dramatically reduces the Trusted Computing Base. The hypervisor and host OS move out of the TCB — you no longer need to trust the cloud provider's software stack.
```

---

## TCB for VM TEEs with vTPM

```{figure} ../images/page_25.png
:alt: TCB for VM TEEs with vTPM — two configurations
:align: center
Left: vTPM outside the TEE (managed by the hypervisor) — the hypervisor IS in the TCB. Used by AWS (for SNP) and GCP. Right: vTPM inside the TEE (via SVSM) — the hypervisor is NOT in the TCB. Used on bare metal with SVSM and Azure CVMs.
```

The placement of the vTPM is a critical architectural decision:

| Configuration | vTPM Location | Hypervisor in TCB? | Used By |
|---|---|---|---|
| vTPM outside TEE | Managed by hypervisor | ✔ Yes | AWS (SNP), GCP |
| vTPM inside TEE (SVSM) | Inside the CVM | ✗ No | Azure CVMs, bare metal |

---

## TCB for VM TEEs without vTPM

```{figure} ../images/page_26.png
:alt: TCB for VM TEEs without vTPM
:align: center
When no vTPM is used (direct boot model for SNP/TDX), the hypervisor is excluded from the TCB entirely. The hardware Root of Trust generates attestation reports directly.
```

---

## TCB for AMD VM TEEs with SVSM

```{figure} ../images/page_27.png
:alt: TCB for AMD VM TEEs with SVSM
:align: center
AMD SEV-SNP with SVSM (Secure VM Service Module): SVSM runs at VMPL0 (the most privileged level inside the SNP VM), providing services like vTPM at VMPL1. The Linux guest runs at VMPL1. The hypervisor (QEMU/KVM on Linux) is outside the TCB.
```

**SVSM** (Secure VM Service Module) is a privileged layer running *inside* the TEE that provides hypervisor-like services (such as vTPM) without involving the hypervisor itself. This means even the cloud provider's hypervisor is excluded from the TCB.

---

## AMD SEV-SNP Measured Boot

```{figure} ../images/page_28.png
:alt: Measured boot with AMD SEV-SNP
:align: center
AMD SEV-SNP measured boot flow: QEMU injects hashes of kernel, cmdline, and initramfs; the AMD Secure Processor measures all guest memory; OVMF verifies hashes before booting; measurements are in the VCEK-signed attestation report.
```

---

## Intel TDX Measured Boot

```{figure} ../images/page_29.png
:alt: Measured boot with Intel TDX
:align: center
Intel TDX measured boot: OVMF extends RTMRs with kernel, cmdline, and initramfs measurements during boot. Measurements are in the event log, used as evidence for remote attestation via TD Quote.
```

---

## Comparison: TPM vs. No-TPM Attestation

```{figure} ../images/page_30.png
:alt: Summary — TPM vs without TPM
:align: center
With TPM: PCR-based measurements, PCR Quote + event log as evidence, PCR authorization for secret unsealing. Without TPM (SNP/TDX direct boot): architecture-specific measurement registers, attestation report as evidence, external policy for secret unsealing.
```

## Comparison of Major TEE Technologies

| Feature | AMD SEV-SNP | Intel TDX | Intel SGX |
|---|---|---|---|
| **Type** | VM-based | VM-based | Process-based |
| **Granularity** | Full VM | Full VM (Trust Domain) | Enclave (subset of process) |
| **App changes needed** | None | None | Yes (trust/untrust split) |
| **Hypervisor in TCB** | Optional | Optional | N/A |
| **Available on cloud** | AWS, GCP, Azure | Azure, GCP | AWS (Nitro Enclaves) |
| **Attestation key** | VCEK (per chip+firmware) | IAK (Intel managed) | Intel SGX quote |
