# TEE Technologies

This section covers how the major TEE implementations — AMD SEV-SNP, Intel TDX, and Intel SGX — realise the concepts introduced in the previous section: measured boot, TCB configurations, and the certificate chains that underpin remote attestation.

---

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
5. Once the OVMF is loaded, it will load the kernel and initramfs into memory, but it will continue the boot process only if the hashes of the kernel, kernel command line and initramfs match the hashes stored in OVMF.

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

---

## Intel TDX

### Measured Boot

Here is an example measured boot flow with a TDX VM TEE in a KVM/Qemu environment. Note that TPM is not used.

1. Qemu started with -kernel param (direct boot)
2. Qemu loads OVMF into guest memory
3. OVMF loads kernel and initramfs into memory and measures the kernel, kernel command line and initramfs into Runtime Extendable Measurement Registers (RTMRs).

The measurements are available at any time (in the event log) and can be used as evidence for remote attestation.

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

---

## AMD SEV-SNP vs Intel TDX — Comparison

```{figure} ../images/page_30.png
:alt: Summary — TPM vs without TPM
:align: center
```

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
| **Hypervisor in TCB** | Optional | Optional | N/A |
| **Available on cloud** | AWS, GCP, Azure | Azure, GCP | AWS, Azure, GCP |
