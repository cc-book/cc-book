# Building Blocks

Before understanding Confidential Computing systems, you need to understand the foundational security primitives they're built on.

## Root of Trust (RoT)

> *"A Root of Trust is an essential, foundational security component that provides a set of trustworthy functions that the rest of the device or system can use to establish strong levels of security."*
> — [Trusted Computing Group](https://trustedcomputinggroup.org/about/what-is-a-root-of-trust-rot/)

```{figure} ../images/page_13.png
:alt: Root of Trust
:align: center
Root of Trust — the foundational hardware security anchor. Functions include trusted boot, measurement, secure storage, reporting, and verification. Examples: AMD PSP, TPM, vTPM, DICE.
```

### Functions a RoT Provides

| Function | Description |
|---|---|
| **Trusted Boot** | Ensures only authorized software starts |
| **Measurement** | Records what software ran (in a tamper-proof way) |
| **Secure Storage** | Stores cryptographic keys isolated from system software |
| **Reporting** | Produces signed attestation reports |
| **Verification** | Validates other components' integrity |

---

## Trusted Platform Module (TPM) and vTPM

```{figure} ../images/page_14.png
:alt: TPM and vTPM
:align: center
A TPM (Trusted Platform Module) securely stores passwords, certificates, encryption keys, and platform measurements (PCRs). A vTPM is a software-based representation of a physical TPM 2.0 chip.
```

### TPM Platform Configuration Registers (PCRs)

PCRs are special registers inside a TPM where measurements (hashes) are stored. They can only be **extended** (not overwritten):

```
New_PCR_Value = SHA256(Old_PCR_Value || New_Measurement)
```

| PCR | What It Measures |
|---|---|
| 0 | UEFI firmware |
| 1 | UEFI firmware configuration |
| 4 | Boot manager |
| 7 | Secure Boot policy |
| 8-15 | OS/application measurements |

:::{warning}
A vTPM managed by a hypervisor means the hypervisor is in the Trusted Computing Base (TCB). If the hypervisor is compromised, the vTPM's protections can be bypassed. This is addressed by putting the vTPM *inside* the TEE using technologies like SVSM.
:::

---

## Trusted Computing Base (TCB)

```{figure} ../images/page_15.png
:alt: Trusted Computing Base in a traditional VM
:align: center
In a traditional VM, the entire stack — hardware, firmware, host OS, hypervisor, guest firmware, guest kernel, and the application itself — must all be trusted. The cloud provider controls everything below the guest.
```

The **Trusted Computing Base** is the set of all hardware, firmware, and software components that you *must trust* for your system's security to hold. In a traditional cloud VM, this includes the hypervisor and host OS — both controlled by the cloud provider.

---

## Secure Boot, Trusted Boot, and Measured Boot

### Secure Boot and Trusted Boot

```{figure} ../images/page_16.png
:alt: Secure Boot and Trusted Boot
:align: center
Secure Boot (UEFI) verifies digital signatures before running bootloaders. Trusted Boot extends this with a chain of verification — each stage checks the next before passing control.
```

- **Secure Boot** — prevents unsigned or tampered bootloaders from running. The UEFI firmware maintains a database of trusted signing certificates.
- **Trusted Boot** — creates a full chain: Firmware → verifies → Bootloader → verifies → Kernel → verifies → OS components.

### Measured Boot

```{figure} ../images/page_17.png
:alt: Measured Boot
:align: center
Measured boot uses hardware Root of Trust (TPM) to record a cryptographic hash of every stage of the boot process into PCRs. This creates a tamper-evident audit trail that can be verified remotely at any point in time.
```

Measured Boot doesn't *block* anything — instead it **records** everything that runs into the TPM's PCRs. This enables **remote attestation** — a third party can cryptographically verify the exact software stack that booted.

### Comparison

```{figure} ../images/page_18.png
:alt: Summary Comparison Table — Secure Boot vs Trusted Boot vs Measured Boot
:align: center
Comparison of boot security mechanisms: Secure Boot and Trusted Boot prevent unauthorized software from running; Measured Boot records what ran and enables remote verification via attestation.
```

| Boot Type | Prevents Bad Software? | Records What Ran? | Provable to Remote Parties? |
|---|---|---|---|
| Secure Boot | ✔ | ✗ | ✗ |
| Trusted Boot | ✔ | ✗ | ✗ |
| Measured Boot | ✗ | ✔ | ✔ (via attestation) |

---

## The Trust Boundary Problem

```{figure} ../images/page_19.png
:alt: Trust Boundary in Virtualisation
:align: center
In traditional virtualisation, the provider fully controls everything below the guest — including the ability to inspect guest memory, modify guest execution, and inject code via the hypervisor. The tenant must trust the provider.
```

```{figure} ../images/page_20.png
:alt: The Challenge with Secure and Trusted Boot
:align: center
Secure Boot does not protect tenants from the provider — the provider signs and defines all trusted components. The hypervisor can technically map guest memory, read plaintext pages, modify registers, and change guest files.
```

```{admonition} The Fundamental Challenge
:class: warning

Secure Boot and Trusted Boot do **not** protect the tenant from the cloud provider.
The provider signs and defines all trusted components (Firmware, Bootloader, Host OS, Hypervisor).

The tenant must ultimately "trust the provider" — the hypervisor can map guest memory,
read plaintext pages, modify registers, and alter guest files.
```

---

## Enter Confidential Computing

```{figure} ../images/page_21.png
:alt: Enter Confidential Computing
:align: center
Confidential Computing introduces hardware-enforced TEE boundaries that reduce the TCB and encrypt VM memory. The provider can no longer inspect guest memory. Measured boot combined with remote attestation allows tenants to verify the boot measurements independently.
```

---

## AMD SEV-SNP Measured Boot Flow

```{figure} ../images/page_28.png
:alt: Measured boot with AMD VM TEEs (SEV-SNP)
:align: center
AMD SEV-SNP measured boot: QEMU loads OVMF and injects hashes of the kernel, cmdline, and initramfs. The AMD Secure Processor measures all guest memory. OVMF continues boot only if hashes match. The attestation report (VCEK-signed) contains these measurements for remote verification. No TPM is required.
```

## Intel TDX Measured Boot Flow

```{figure} ../images/page_29.png
:alt: Measured boot with Intel VM TEEs (TDX)
:align: center
Intel TDX measured boot: QEMU loads OVMF which extends RTMRs (Runtime Extendable Measurement Registers) with kernel, cmdline, and initramfs hashes. Measurements are available via event log for remote attestation. No TPM required.
```

## TPM vs. No-TPM Summary

```{figure} ../images/page_30.png
:alt: Summary comparison — TPM vs without TPM
:align: center
Summary: with TPM, measurements go into PCRs and evidence is a PCR Quote + event log. Without TPM (SNP/TDX direct boot), measurements are stored in specific memory locations or RTMRs and evidence is the attestation report itself.
```
