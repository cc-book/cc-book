# The Trust Boundary Problem

With the building blocks in place — Root of Trust, measured boot, and TEEs — we can now ask the critical question: **do they actually protect tenants from the infrastructure they run on?**

---

## Trust Boundary in Traditional Virtualisation

In traditional virtualisation, the provider fully controls everything below the guest VM — the hypervisor, host OS, device firmware, and hardware. This means the provider can:

- Inspect guest memory
- Modify guest execution
- Inject code via the hypervisor

The tenant trust boundary sits *above* the hypervisor. Everything below it belongs to the provider.

```{figure} ../images/page_19.png
:alt: Trust Boundary in Virtualisation
:align: center
```

---

## Why Existing Mitigations Fall Short

The table below shows common security mechanisms, their intended protections and where the protections fail when the attacker controls the infrastructure:

| Mechanism | Protects Against | Fails When |
|---|---|---|
| **Encryption at rest** | Stolen disks | Attacker controls the hypervisor (reads key from memory) |
| **Encryption (TLS) in transit** | Network eavesdropping | Attacker controls the VM (terminates TLS inside guest) |
| **Secure Boot** | Unsigned bootloaders | Provider defines trusted signing certificates |
| **Measured/Trusted Boot** | Tampered boot components | Only proves machine runs *provider's* approved software |
| **SELinux / AppArmor** | Process-level isolation | Bypassed by hypervisor-level access |
| **Namespace isolation** | Container escapes | Hypervisor can still access all guest memory |

```{admonition} The Core Problem
:class: warning

All software-based security controls can be bypassed by a sufficiently privileged attacker. The hypervisor sits *above* all guest software — it is the ultimate arbiter of what the guest sees and does.

**Software cannot protect itself from the software below it.**

```

---

## Real-World Attack Scenarios

Each attach scenario represents a class of attack that a privileged infrastructure operator (or a compromised one) can carry out:

### 1. Live Memory Dump

A hypervisor administrator uses QEMU/KVM or cloud management APIs to pause a VM and dump its entire memory contents to disk. The dump contains:

- Plaintext encryption keys
- In-memory databases
- Active TLS private keys
- User session tokens and credentials

This requires no vulnerability in the guest OS — it is a built-in capability of every hypervisor.

### 2. Cold-Boot Attack

Physical access to a server allows an attacker to freeze DRAM chips (preserving memory contents for minutes to hours), remove them, and read them in another machine. AES keys, RSA private keys, and session data are all recoverable.

### 3. Hypervisor-Level Keylogger

By intercepting virtual keyboard I/O at the hypervisor layer, an attacker captures keystrokes before they reach the guest OS — including passwords, PINs, and passphrases entered by users.

### 4. DRAM Bus Snooping

Physical access to the memory bus allows passive reading of unencrypted DRAM traffic. Without memory encryption, all guest data transiting the memory bus is plaintext.

### 5. Snapshot & Restore Attack

An attacker takes a VM snapshot, restores the VM to that earlier state, and observes outputs to extract cryptographic secrets.

### 6. Rogue or Coerced Insider

A cloud provider employee with hypervisor access — whether acting maliciously, under coercion, or compelled by a legal order — can inspect any running VM without the tenant's knowledge.

### 7. Co-Tenant Side-Channel Attacks

A co-tenant VM running on the same physical host can leak secrets from another VM without any hypervisor access, by exploiting **shared hardware resources**:

**CPU Cache Timing (Spectre/Meltdown family)**
Modern CPUs share L1/L2/L3 caches across logical cores. A malicious co-tenant can measure cache access times to infer which memory addresses a victim VM is accessing — and from that, reconstruct cryptographic keys or sensitive data patterns.

- **Spectre** (CVE-2017-5753, CVE-2017-5715) — exploits speculative execution to read across privilege boundaries
- **Meltdown** (CVE-2017-5754) — allows user-space code to read kernel memory; patched in software but with performance cost
- **Flush+Reload, Prime+Probe, Evict+Time** — cache side-channel techniques requiring only shared LLC (Last-Level Cache)

**DRAM Rowhammer**
By repeatedly reading ("hammering") rows of DRAM, an attacker flips bits in adjacent memory rows belonging to another process or VM. This can corrupt page table entries and escalate privilege, even without any software vulnerability.

**Branch Predictor & TLB Attacks**
Shared branch predictors and Translation Lookaside Buffers leak information about the control flow and memory access patterns of co-resident VMs.

**Why this matters:** these attacks require **no hypervisor access** and **no software vulnerability in the victim** — only physical co-residency on the same host.

---

## The Insider Threat Taxonomy

Not all privileged attackers are equal. Here is how they map to real roles:

| Adversary | Access Level | What They Can Do |
|---|---|---|
| **Physical datacenter admin** | Hardware, DRAM bus | Cold-boot, bus sniffing, hardware implants |
| **Hypervisor/cloud operator** | Hypervisor API | Memory dump, snapshot, VM pause/inspect |
| **Cloud platform engineer** | Management plane | VM migration, storage access, network tap |
| **Co-tenant (side-channel)** | Shared hardware | Cache-timing attacks, Spectre/Meltdown variants |
| **Compromised orchestration** | K8s/cloud API | Workload injection, secret exfiltration via env vars |

---

## The Compliance Gap

Regulations increasingly require that data be protected from *infrastructure operators*, not just external attackers:

| Regulation | Requirement | Traditional Cloud Problem |
|---|---|---|
| **GDPR (Art. 32)** | Appropriate technical measures to protect personal data | Cloud provider has access to personal data in memory |
| **HIPAA** | PHI must be protected against unauthorised access | Hypervisor admins can access PHI in running workloads |
| **PCI-DSS** | Cardholder data must be protected at all times | "In use" is an unprotected state in traditional VMs |
| **FedRAMP / IL4/IL5** | US government data must not be accessible to CSP staff | Structural impossibility without hardware isolation |

Confidential Computing is increasingly cited by compliance frameworks as the mechanism to satisfy these "data in use" requirements.

---

## Why Hardware Enforcement Is the Only Solution

Any purely software-based isolation boundary can be bypassed by software running at a higher privilege level. This is not a bug — it is by design: the hypervisor must be able to manage guest resources.

The only way to make the isolation boundary *uncrossable* by software is to have the **hardware itself enforce it**:

```{mermaid}
flowchart LR
    SW["Software isolation <br/> (namespaces, SELinux,<br/>disk encryption)"]
    HV["Hypervisor <br/> (higher privilege)"]
    HW["Hardware TEE<br/>(CPU enforces boundary)"]
    HV2["Hypervisor"]

    HV -->|"can bypass"| SW
    HV2 -. "cannot bypass<br/>(hardware blocks it)" .-> HW
```

This is what **Confidential Computing** provides: a hardware-enforced boundary that even the hypervisor cannot cross.

---

## Confidential Computing

```{figure} ../images/page_21.png
:alt: Enter Confidential Computing
:align: center
```

Confidential Computing introduces **hardware-enforced TEE boundaries** where:

- VM memory is encrypted by the CPU — the hypervisor sees only ciphertext
- The TCB is reduced — the hypervisor and host OS are no longer trusted components
- Measured boot is rooted in hardware (AMD SP, Intel TDX Module) — not in provider-controlled firmware
- **Remote attestation** lets the tenant independently verify the boot measurements, without relying on the provider

The tenant trust boundary now extends *down to the hardware*, bypassing the hypervisor entirely.

---

## Known Attacks Against Confidential Computing

Confidential Computing is not a silver bullet. Researchers have demonstrated attacks that bypass CC protections — particularly those requiring physical access to hardware. Understanding these is important for setting accurate expectations.

### BadRAM (CVE-2024-21944)

**What it is:** An attack that exploits rogue DRAM modules to trick the CPU into mapping two distinct addresses to the same physical memory cell — a technique called *memory aliasing*.

**How it works:**

1. The attacker modifies the **SPD (Serial Presence Detect)** chip on a DIMM, causing it to misreport memory size. The CPU is deceived into creating "ghost" addresses that alias real memory regions.
2. Aliased addresses are discovered automatically (tools take minutes).
3. Through the alias, the attacker bypasses CPU-enforced memory protections.

For AMD SEV-SNP specifically:
- The **Reverse Map Table (RMP)** — SEV-SNP's defence against page remapping — is unencrypted and can be directly manipulated via aliasing
- SEV's static encryption (identical plaintext → identical ciphertext) allows stale-data replay
- Attackers can **forge attestation measurements**, making backdoored code appear to be a legitimate CVM

**Hardware required:** ~$10 (Raspberry Pi Pico, DDR socket, 9V source)

**Affected TEEs:**

| TEE | Vulnerable? |
|---|---|
| AMD SEV-SNP | ✔ Yes (patched via AMD-SB-3015 firmware update) |
| Intel TDX | ✗ No — alias-checking at boot prevents it |
| Intel Scalable SGX | ✗ No |
| ARM CCA | Untested |

**Mitigation:** AMD released a firmware update (AMD-SB-3015) that treats SPD data as untrusted and validates memory configuration in trusted firmware. Major cloud providers have applied this patch.

*Reference: [BadRAM](https://badram.eu)*

---

### TEE.Fail — Physical Bus Interposition on DDR5

**What it is:** A side-channel attack that physically intercepts all memory traffic between the CPU and DDR5 DRAM to extract secrets from TEEs — including Intel TDX, AMD SEV-SNP, and Nvidia GPU Confidential Computing.

**How it works:**

Researchers built a custom **interposition device** (~$1,000 of off-the-shelf electronics) that sits between the CPU and DIMM and passively captures all memory bus traffic. The attack exploits a fundamental weakness:

> **AES-XTS encryption, used by both Intel and AMD, is deterministic** — identical plaintexts always produce identical ciphertexts. This allows pattern analysis and data extraction without direct decryption.

Even AMD's **Ciphertext Hiding** feature (designed to obscure memory patterns) was shown to be insufficient.

**What can be extracted:**

- Cryptographic keys from Intel TDX and AMD SEV-SNP guests
- **ECDSA attestation keys** from Intel's Provisioning Certification Enclave (PCE) — allowing an attacker to **fake valid attestation reports**
- Private signing keys from OpenSSL's ECDSA implementation on fully patched systems
- Once attestation keys are extracted, the attack extends to **Nvidia GPU Confidential Computing**

**Notable:** this is the first demonstrated attack against DDR5, the latest generation of memory hardware.

**Vendor response:** Both AMD and Intel classify physical bus interposition as **out of scope** for their TEE threat models. No firmware mitigations are planned. Researchers suggest software-level countermeasures against deterministic encryption, though these carry performance costs.

*References: [The Hacker News](https://thehackernews.com/2025/10/new-teefail-side-channel-attack.html)*

---

### What These Attacks Mean in Practice

```{admonition} Physical access changes the threat model
:class: warning

Both BadRAM and TEE.Fail require **physical access to the server hardware** — either to modify DRAM modules (BadRAM) or to attach an interposition device to the memory bus (TEE.Fail). 

It's important to keep in mind that CC threat model still relies on the assumption that the **physical infrastructure is secure**.
```
