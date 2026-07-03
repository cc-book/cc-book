# Confidential Virtual Machine (CVM)

A **Confidential Virtual Machine (CVM)** is a virtual machine that runs inside a hardware Trusted Execution Environment (TEE), protecting the guest's memory and execution from inspection or tampering by the hypervisor, host OS, and other privileged software.

CVMs impose the least restrictions of any CC deployment model: existing applications run **unmodified** inside a CVM, with no code changes required.

```{figure} ../images/cvm.png
:alt: Confidential Virtual Machine architecture
:align: center
```

*References: [Red Hat — Introduction to Confidential Virtual Machines](https://www.redhat.com/en/blog/introduction-confidential-virtual-machines), [Edgeless Systems — CVMs](https://www.edgeless.systems/wiki/what-is-confidential-computing/cvms)*

---

## CVM Threat Model

The untrusted components include the host OS, KVM hypervisor, other VMs on the same host, other processes on the host machine.

Application code vulnerabilities, availability attacks, and software TEEs are out of scope.

### What a CVM Protects

CVMs provide **workload confidentiality**. The data in use is isolated from higher-privilege layers:

| Layer | Can it read CVM memory? |
|---|---|
| Hypervisor | ✗ No |
| Host OS | ✗ No |
| Host administrators | ✗ No |
| DMA-capable host devices | ✗ No |
| Other VMs on the same host | ✗ No |
| Guest OS (within the CVM) | ✔ Yes |
| The workload itself | ✔ Yes |

```{figure} ../images/cvm_protections.png
:alt: CVM protections
:align: center
```

### What CVMs Do NOT Protect Against

- Vulnerabilities within the guest workload (application bugs, remote exploits)
- Availability attacks (DoS)
- Attacks that originate inside the guest with legitimate access

---

## Memory Encryption

The hardware memory controller transparently encrypts all guest physical memory pages with a key held inside the CPU. The hypervisor sees only ciphertext when it accesses guest memory.

AMD SEV-SNP uses a dedicated processor called AMD Secure Processor (ASP), also known as AMD Platform Security Processor or PSP, to manage its
security features. ASP is an ARM-based processor separated from the main x86 cores but directly integrated into the CPU die, creating a hardware root-of-trust. The ASP securely manages SEV-SNP VM encryption keys and the reverse map table to ensure the integrity of the guest address translation.

Intel introduces two new components: a new CPU operation mode Secure Arbitration Mode (SEAM), and special trusted software the TDX module. A Trust Domain (TD) is a virtual machine that runs in a secure environment under the control of the TDX
module.

**Data at rest** in a CVM also requires protection — the host controls storage access, so full disk encryption (e.g., LUKS) is mandatory for any sensitive data persisted to disk.

---

## Boot Chain Security

A critical risk in CVMs: even with memory encryption, a malicious host could swap binaries before they are loaded into protected memory. Every executable must therefore be **authenticated** before execution.

### UEFI Secure Boot

Secure Boot ensures only vendor-signed code executes during boot:

```{mermaid}
flowchart LR
    FW["UEFI Firmware (Root of Trust)"]
    SH["Shim (Signed OS-vendor certs)"]
    BL["Bootloader (GRUB / systemd-boot)"]
    KN["Kernel lockdown mode"]
    MOD["Kernel Modules (signed only)"]

    FW -->|verifies| SH
    SH -->|verifies| BL
    BL -->|verifies| KN
    KN -->|allows| MOD
```

### Unified Kernel Image (UKI)

A UKI bundles the kernel, initramfs, and kernel command line into **one signed UEFI binary**, extending trust to components that were previously unsigned:

| Component | Standard Boot | UKI |
|---|---|---|
| Kernel | ✔ Signed | ✔ Signed |
| initramfs | ✗ Unsigned | ✔ Signed (part of UKI) |
| Kernel command line | ✗ Unprotected | ✔ Signed (part of UKI) |

**Trade-offs:** the initramfs and kernel command line are fixed at build time — they cannot be modified dynamically (e.g., `root=` cannot be set at runtime).

### Measured Boot and the Root Volume Key

Even with Secure Boot, a signed kernel could be paired with a crafted initramfs to extract a volume decryption key. The solution is **PCR-gated key unsealing**:

1. Each boot component extends a PCR register: `PCR_new = SHA256(PCR_old || component_hash)`
2. The volume decryption key is sealed to a TPM policy requiring specific PCR values
3. The hardware evaluates the policy — if any boot component changed, PCRs differ and the key is not released
4. A compromised guest OS cannot circumvent this because the hardware enforces it

Key PCRs for CVMs:

| PCR | What it covers |
|---|---|
| PCR4 | Boot manager code and boot attempts |
| PCR7 | Secure Boot policy (PK/KEK/db/dbx + the db entry used to authorize each loaded image) |
| PCR11 (UKI via systemd-stub) | Kernel, initramfs, command line, all UKI sections |

---

## The vTPM Role

A **virtual TPM backed by hardware** (rather than managed by the hypervisor) enables:

- **Automated (unattended) key unsealing** — no user password at boot (which the host could intercept via console emulation)
- **Attestable genuineness** — under SEV-SNP or TDX, a vTPM inside the TEE cannot be faked by the host
- **PCR-based policies** — the same policy model used for bare-metal TPMs works inside the CVM

When the vTPM is placed **inside the TEE** (via SVSM on AMD SEV-SNP, or natively on [Azure CVMs](https://learn.microsoft.com/en-us/azure/confidential-computing/virtual-tpms-in-azure-confidential-vm)), the hypervisor is completely excluded from the trust chain.

---

## Remote Attestation for CVMs

The hardware generates a **signed attestation report** containing the boot measurements. A remote party can use this to verify:

1. The VM is genuinely running inside a hardware TEE (not a software simulation)
2. The correct guest OS was booted (measurements match expected values)
3. The hardware is at the required firmware/patch level

```{mermaid}
sequenceDiagram
    actor Tenant
    participant CVM as CVM (TEE)
    participant HW as AMD / Intel

    Tenant->>CVM: Request attestation
    CVM->>HW: Get attestation report
    HW-->>CVM: Signed report
    CVM-->>Tenant: Attestation report
    Tenant->>Tenant: Verify report against AMD/Intel cert chain
    Tenant->>Tenant: Check measurements match expected values
    Tenant->>CVM: Send secrets (if verification passed)
```

---

## Hardware Technologies

All major CPU vendors support CVMs.

| Vendor | Technology|
|---|---|
| **AMD** | SEV-SNP |
| **AMD** | SEV-ES |
| **AMD** | SEV |
| **Intel** | TDX |
| **IBM Z** | Secure Execution |
| **IBM Power** | Protected Execution Facility (PEF) |
| **ARM** | CCA (Confidential Compute Architecture) |
| **RISC-V** | CoVE (Confidential VM Extensions) |

:::{note}
**SEV, SEV-ES, and SEV-SNP are successive generations, not alternatives.** Plain SEV encrypts guest memory only; SEV-ES additionally protects CPU register state on VM exits; SEV-SNP adds memory integrity protection (the Reverse Map Table) and a hardware-signed attestation report. Only SEV-SNP provides the full confidentiality, integrity, and attestation guarantees this book assumes. SEV and SEV-ES appear here for completeness and should not be used for new deployments.
:::

---

## Cloud Availability

| Cloud | Technology | Status |
|---|---|---|
| **Microsoft Azure** | AMD SEV-SNP | GA |
| **Microsoft Azure** | Intel TDX | GA |
| **Google Cloud** | AMD SEV-SNP | GA |
| **Google Cloud** | Intel TDX | GA |
| **AWS** | AMD SEV-SNP | GA |
| **IBM Cloud** | IBM Secure Execution | GA |
| **IBM Cloud** | AMD SEV-SNP | GA |
| **IBM Cloud** | Intel TDX | GA |

---

## Performance and Operational Considerations

A common first question: *what does the encryption cost?* The honest answer is "usually little, but it depends on the workload", and the overhead is rarely where people expect it.

### Runtime overhead

- **CPU- and memory-bound workloads** typically see **low single-digit percentage** overhead. Memory encryption is performed by dedicated hardware in the memory controller and is not the bottleneck.
- **I/O-heavy workloads pay more.** Devices cannot DMA directly into the guest's private (encrypted) memory, so every network packet and disk block crosses the boundary through **bounce buffers** (shared, unencrypted pages managed via `swiotlb` in Linux). This adds a memory copy and CPU cost per I/O operation. Network- or storage-intensive workloads can see noticeably higher overhead and increased CPU utilization per unit of throughput.
- **VM exits are more expensive.** Context switches between guest and host involve additional hardware state protection (especially on SEV-SNP with register state encryption), so exit-heavy workloads (frequent interrupts, timer-heavy applications) are disproportionately affected.

Always benchmark *your* workload; published numbers vary widely with kernel version, I/O pattern, and hardware generation.

### Boot and startup latency

- Guest memory must be validated/accepted before use. Large-memory CVMs use **lazy memory acceptance** to avoid multi-second boot delays; fully pre-accepting memory at launch is slower but avoids runtime acceptance hiccups.
- Attestation adds a network round-trip (to a verifier and/or certificate service) before secrets are released; plan for this in autoscaling paths.

### Operational restrictions

- **Memory cannot be overcommitted or swapped by the host**: guest memory is pinned. Capacity planning is stricter than for regular VMs.
- **Live migration is limited or unavailable** depending on the platform and cloud, so host maintenance may mean a stop/restart instead of a transparent migration.
- **Snapshots and hibernation of guest state are generally unsupported**: this is by design, since exporting encrypted guest state would undermine the threat model.

---

## CVMs as the Foundation for CoCo

CVMs are **Pillar 1** of the Confidential Computing stack. The CNCF Confidential Containers (CoCo) project builds directly on CVMs:

- Each Kubernetes Pod runs inside its own CVM
- The CVM provides the hardware TEE boundary
- Attestation of the CVM is the root of trust for all CoCo secrets

The chapters that follow cover how CoCo build on this foundation.
