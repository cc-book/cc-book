# TEE Technologies: AMD SEV-SNP, Intel TDX, and Intel SGX

This chapter compares the major Trusted Execution Environment (TEE) technologies — AMD SEV-SNP, Intel TDX, and Intel SGX,
and explains how they implement memory isolation, measured boot, TCB configurations, certificate chains, and remote attestation.

---

(tcb-configurations-for-vm-tees)=
## TCB Configurations for VM TEEs

The placement of the vTPM relative to the TEE boundary has a direct impact on what ends up in the Trusted Computing Base.

### vTPM Outside the TEE

```{figure} ../images/page_25.png
:alt: TCB for VM TEEs with vTPM — two configurations
:align: center
```

| Configuration | vTPM Location | Hypervisor in TCB? | Used By |
|---|---|---|---|
| vTPM outside TEE | Managed by hypervisor | ✔ Yes | AWS, GCP |
| vTPM inside TEE | Inside the CVM | ✗ No | Azure CVMs, bare metal (with SVSM) |

### vTPM Inside the TEE (SVSM)

**SVSM** (Secure VM Service Module) runs *inside* the TEE and provides hypervisor-like services (such as vTPM) without involving the hypervisor itself. This means even the cloud provider's hypervisor is excluded from the TCB.

```{figure} ../images/page_27.png
:alt: TCB for AMD VM TEEs with SVSM
:align: center
```

### Without vTPM (Direct Boot Model)

When no vTPM is used, the hypervisor is excluded from the TCB entirely. The hardware Root of Trust generates attestation reports directly from its own measurements.

```{figure} ../images/page_26.png
:alt: TCB for VM TEEs without vTPM
:align: center
```

---

## AMD SEV-SNP

### Measured Boot

Here is an example measured boot flow with an SNP VM TEE in a KVM/Qemu environment. Note that TPM is not used. Instead, the hashes of the kernel, kernel command line and initramfs are stored in guest memory and measured by the AMD Secure Processor (SP).

1. Qemu started with -kernel param (direct boot)
2. Qemu loads OVMF into guest memory
3. Qemu loads hashes of kernel, kernel command line and initramfs into guest memory
4. AMD Secure Processor (SP) measures all the guest memory
5. Once the OVMF is loaded, it will load the kernel and initramfs into memory, but it will continue the boot process only if the hashes of the kernel, kernel command line and initramfs match the hashes in the measured SEV hashes page in guest memory. (OVMF holds no hash values itself — QEMU injects the hashes page into guest memory, and it is covered by the launch measurement.)

The measurements are available at any time as part of the attestation report and can be used for remote attestation. The attestation report is signed with the Versioned Chip Endorsement Key (VCEK).

```{figure} ../images/page_28.png
:alt: Measured boot with AMD SEV-SNP
:align: center
```

### Certificate Chain

```
AMD Root Key (ARK)
    └── signs AMD SEV Key (ASK)
            └── signs VCEK certificate
                    └── VCEK private key signs SNP attestation report
```

The VCEK is unique per chip and firmware version. AMD's Key Distribution Service ([KDS](https://wiki.ietf.org/group/rats/referencevalues/amd-key-distribution-service?ref=blog.polyhedra.network)) provides VCEK certificates publicly.

KDS is stateless: certificates are fetched on demand by chip ID and TCB version, with no platform registration required.

The root of trust for the chain is AMD's ARK (AMD Root Key), a long-lived key pair whose public half is published by AMD and embedded in verifier software. Trusting ARK means trusting AMD as the hardware manufacturer — it is the foundational assumption for all AMD SEV-SNP attestation.

:::{admonition} Offline / Disconnected Deployments
:class: warning
In air-gapped or network-restricted environments, nodes cannot reach AMD KDS to retrieve VCEK certificates at runtime. Operators must pre-fetch and cache certificate collateral (ARK, ASK, VCEK) and distribute it out-of-band. Failing to plan for this is a common production operational challenge.
:::

---

## Intel TDX

### Measured Boot

Here is an example measured boot flow with a TDX VM TEE in a KVM/Qemu environment. Note that TPM is not used.

1. Qemu started with -kernel param (direct boot)
2. Qemu loads OVMF into guest memory
3. The initial TD contents are measured into the build-time register **MRTD** by the TDX module.
4. OVMF (TDVF) measures the kernel into **RTMR1**; the kernel's EFI stub then measures the kernel command line and initramfs into **RTMR2**. RTMRs are Runtime Extendable Measurement Registers.

The measurements (MRTD plus the RTMRs and their event log) are available at any time and can be used as evidence for remote attestation.

```{figure} ../images/page_29.png
:alt: Measured boot with Intel TDX
:align: center
```

### Certificate Chain

```
Intel Root CA
    └── signs Intel Provisioning Certification Key (PCK) Platform CA
            └── signs PCK Certificate
                    └── Provisioning Certification Enclave (PCE) certifies Quoting Enclave (QE) Attestation Key
                            └── QE signs TDX Quote
```

The PCK (Provisioning Certification Key) certificate is platform-specific and TCB-version dependent. Intel's Provisioning Certification Service ([PCS](https://api.portal.trustedservices.intel.com/content/documentation.html)) provides PCK certificates. The Quoting Enclave (QE) generates and signs the TDX Quote, while the Provisioning Certification Enclave (PCE) certifies the QE attestation key.

PCS is more infrastructure-heavy than AMD KDS: it requires platform registration, subscription/API access, and a PCCS caching layer for production deployments.

The root of trust is Intel's Root CA, whose public key is published by Intel and embedded in verifier software. Trusting Intel Root CA means trusting Intel as the hardware manufacturer.

:::{admonition} Offline / Disconnected Deployments
:class: warning
Because PCK certificate retrieval from Intel PCS requires platform registration and network access, disconnected or air-gapped deployments require a local PCCS (Provisioning Certificate Caching Service) instance pre-loaded with the relevant certificate collateral. This is a significant operational requirement that must be planned for ahead of deployment.
:::

---

## AMD SEV-SNP vs Intel TDX — Comparison

### Attestation Evidence

| | With TPM | Without TPM (SNP/TDX direct boot) |
|---|---|---|
| **Measurements** | PCRs | Specific memory locations (SNP) / RTMRs (TDX) |
| **Evidence** | PCR Quote + event log | Attestation report / event log |
| **Secret unsealing** | PCR authorization in hardware | External authorization + policy |

### Certificate Infrastructure

| | AMD SEV-SNP | Intel TDX |
|---|---|---|
| **Certificate service** | AMD KDS | Intel PCS |
| **Certificate type** | VCEK | PCK |
| **Root chain** | ARK → ASK → VCEK | Intel Root CA → PCK CA → PCK |
| **Quote collateral** | SNP attestation report | TDX Quote |
| **Registration required** | No | Yes |
| **Infrastructure complexity** | Low (stateless fetch) | Higher (PCCS caching) |

### Feature Comparison

| Feature | AMD SEV-SNP | Intel TDX | Intel SGX |
|---|---|---|---|
| **Type** | VM-based | VM-based | Process-based |
| **Granularity** | Full VM | Full VM | Enclave (subset of process) |
| **App changes needed** | None | None | Yes (trust/untrust split) |
| **Hypervisor in TCB** | Optional* | Optional* | N/A |
| **Available on cloud** | AWS, Azure, GCP, IBM Cloud | Azure, GCP, IBM Cloud | Azure, IBM Cloud, Alibaba Cloud |

\* Depends on where the vTPM is placed; see [TCB Configurations for VM TEEs](#tcb-configurations-for-vm-tees) at the top of this section.

:::{note}
**Intel SGX is deliberately out of scope for this book.** SGX is a process-based TEE requiring applications to be split into trusted and untrusted components, a different programming model from the VM-based TEEs this book focuses on. For a deep treatment, see [Intel SGX Explained (Costan & Devadas)](https://eprint.iacr.org/2016/086.pdf) and Intel's SGX developer documentation.
:::

---

## Other TEE Architectures

Beyond AMD and Intel on x86, VM-based TEEs exist or are emerging on every major CPU architecture. This book's concepts (measured launch, hardware-signed evidence, a vendor certificate chain) carry over directly; only the component names change.

### Arm CCA

**Arm Confidential Compute Architecture (CCA)**, part of Armv9-A, introduces **Realms**: VM-based TEEs whose memory and register state are inaccessible to the hypervisor and to Arm TrustZone's Secure world. Realms are managed by a small, verifiable firmware component called the **Realm Management Monitor (RMM)**, the architectural analogue of the Intel TDX module. Attestation follows the same pattern as SNP/TDX: the hardware produces a signed **CCA attestation token** covering the Realm's initial measurement, rooted in device keys provisioned by the manufacturer. As of this writing, CCA-capable server hardware is still reaching the market, but the software stack (Linux, KVM, kvmtool/QEMU, Trustee support) is being developed in the open.

### RISC-V CoVE

**CoVE (Confidential VM Extensions)** is the RISC-V specification for VM-based TEEs. It defines **TEE Virtual Machines (TVMs)** managed by a **TEE Security Manager (TSM)** running in a higher privilege level than the hypervisor, again mirroring the TDX module / RMM pattern. CoVE is a specification with reference implementations rather than shipping silicon; it matters because it extends the CC programming and attestation model to an open ISA.

### IBM Z and LinuxONE: Secure Execution

**IBM Secure Execution (SE)** protects KVM guests on IBM Z and LinuxONE using a firmware **ultravisor**. Its trust model differs from SNP/TDX in an instructive way: the guest image is *encrypted at build time* against a host-specific public key, so trust is established by image preparation rather than by comparing runtime measurements, though SE also supports attestation and is integrated with CoCo and Trustee. IBM Power offers a similar capability, the **Protected Execution Facility (PEF)**.
