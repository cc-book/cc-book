# Concepts

## Root of Trust (RoT)

**A Root of Trust** is an essential, foundational security component that provides a set of trustworthy functions that the rest of the device or system can use to establish strong levels of security.

*[Trusted Computing Group What is a Root of Trust?](https://trustedcomputinggroup.org/about/what-is-a-root-of-root-rot/)*

### Functions a RoT Provides

| Function | Description |
|---|---|
| **Trusted Boot** | Ensures only authorized software starts |
| **Measurement** | Records what software ran (in a tamper-proof way) |
| **Secure Storage** | Stores cryptographic keys isolated from system software |
| **Reporting** | Produces signed attestation reports |
| **Verification** | Validates other components' integrity |

Example RoTs - AMD Secure Processor, Trusted Platform Module (TPM), Virtual Trusted Platform Module (vTPM), Device Identifier Composition Engine (DICE)

---

## Trusted Platform Module (TPM) and vTPM

TPM (Trusted Platform Module) is a computer chip (microcontroller) that can securely store artifacts used to authenticate the platform (your PC or laptop). These artifacts can include passwords, certificates, or encryption keys. A TPM can also be used to store platform measurements that help ensure that the platform remains trustworthy. It's an example of a RoT component.

A Virtual Trusted Platform Module (vTPM) is a software-based representation of a physical Trusted Platform Module (TPM) 2.0 chip.

*[Trusted Computing Group TPM summary](https://trustedcomputinggroup.org/resource/trusted-platform-module-tpm-summary/)*

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

The **Trusted Computing Base** is the set of all hardware, firmware, and software components that you *must trust* for your system's security to hold. In a traditional cloud VM, this includes the hypervisor and host OS — both controlled by the cloud provider.

```{figure} ../images/page_15.png
:alt: Trusted Computing Base in a traditional VM
:align: center
```

---

## Secure Boot, Trusted Boot, and Measured Boot

### Secure Boot and Trusted Boot

**Secure Boot** verifies digital signatures before running bootloaders.

- It is a feature of the Unified Extensible Firmware Interface (UEFI). It's used to check bootloaders, key operating system files, and the ROM for any tampering attempts.
- UEFI firmware has signatures stored in a database and Secure Boot will check those signatures. If the signatures don't match, then something was modified incorrectly and the boot process will halt.

**Trusted Boot** extends this with a chain of verification — each stage checks the next before passing control.

- The bootloader (which we've verified to be trustworthy) will check the digital signature of the operating system kernel before loading it.
- The verified kernel will then verify every other part of the OS startup process including boot drivers and startup files, to make sure those components are all safe.

```{figure} ../images/page_16.png
:alt: Secure Boot and Trusted Boot
:align: center
```

### Measured Boot

Measured boot uses hardware Root of Trust (RoT) eg. TPM to record a cryptographic hash of every stage of the boot process into PCRs. This creates a tamper-evident audit trail that can be verified remotely at any point in time.

Measured Boot doesn't *block* anything — instead it **records** everything that runs (eg. into the TPM's PCRs). This enables **remote attestation** — a third party can cryptographically verify the exact software stack that booted.

```{figure} ../images/page_17.png
:alt: Measured Boot
:align: center
```

### Summary Comparison

Comparison of boot security mechanisms: Secure Boot and Trusted Boot prevent unauthorized software from running; Measured Boot records what ran and enables remote verification via attestation.

```{figure} ../images/page_18.png
:alt: Summary Comparison Table — Secure Boot vs Trusted Boot vs Measured Boot
:align: center
```

---

## Trusted Execution Environments (TEEs)

A **Trusted Execution Environment (TEE)** is a hardware-enforced, isolated region of a processor that protects code and data from unauthorized access — including from privileged software like the OS, hypervisor, or firmware.

```{figure} ../images/page_22.png
:alt: Trusted Execution Environments definition
:align: center
```

| Characteristic | Description |
|---|---|
| **Memory Encryption** | All data in the TEE's memory is encrypted by the hardware. Even physical DRAM access reveals only ciphertext. |
| **Isolation** | The TEE is isolated from other processes, VMs, and the host OS. Hardware enforces this boundary. |
| **Remote Attestation** | The TEE can prove its identity and integrity to remote parties cryptographically. |
| **Data Integrity** | The hardware detects and prevents tampering with TEE memory. |

### Types of TEEs

```{figure} ../images/page_23.png
:alt: Types of TEEs — VM-based and Process-based
:align: center
```

**VM-Based TEEs** encrypt memory along a traditional VM boundary. The hypervisor cannot read VM memory.

Examples: AMD SEV-SNP, Intel TDX, IBM Secure Execution, IBM PEF

- Protects entire existing applications without code changes
- Supports standard Linux distributions
- Scales to large memory and multi-core workloads

**Process-Based TEEs** split an app into trusted and untrusted components. Only the sensitive part runs in encrypted memory.

Example: Intel SGX

- Smaller attack surface (only enclave code is in the TCB)
- Requires application refactoring to separate trusted/untrusted components
- Historically constrained to small enclave memory sizes

### TCB Reduction with Confidential Computing

Confidential Computing dramatically reduces the TCB. The hypervisor and host OS move out of the TCB — you no longer need to trust the cloud provider's software stack.

```{figure} ../images/page_24.png
:alt: TCB reduction with Confidential Computing
:align: center
```
