# The Trust Boundary Problem

Cloud computing promises flexibility and scale. But it comes at a cost: when you run workloads on someone else's infrastructure, you must trust the infrastructure owner. Let's examine what that trust actually means, and why it is a deeper problem than it first appears.

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

:::{note}
**KVM blurs the host OS / hypervisor line:** With KVM, the hypervisor is a kernel module running inside the host OS. The host OS *is* the hypervisor.
They form a single trust domain, not two separate layers. The book lists them separately for conceptual clarity.
:::

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

Each attack scenario represents a class of attack that a privileged infrastructure operator (or a compromised one) can carry out:

### 1. Live Memory Dump

A hypervisor administrator uses QEMU/KVM or cloud management APIs to pause a VM and dump its entire memory contents to disk. The dump contains:

- Plaintext encryption keys
- In-memory databases
- Active TLS private keys
- User session tokens and credentials

This requires no vulnerability in the guest OS. It is a built-in capability of every hypervisor.

### 2. Cold-Boot Attack

Physical access to a server allows an attacker to freeze DRAM chips (preserving memory contents for minutes to hours), remove them, and read them in another machine. AES keys, RSA private keys, and session data are all recoverable.

### 3. Hypervisor-Level Keylogger

By intercepting virtual keyboard I/O at the hypervisor layer, an attacker captures keystrokes before they reach the guest OS, including passwords, PINs, and passphrases entered by users.

### 4. DRAM Bus Snooping

Physical access to the memory bus allows passive reading of unencrypted DRAM traffic. Without memory encryption, all guest data transiting the memory bus is plaintext.

### 5. Snapshot & Restore Attack

An attacker takes a VM snapshot, restores the VM to that earlier state, and observes outputs to extract cryptographic secrets.

### 6. Rogue or Coerced Insider

A cloud provider employee with hypervisor access, whether acting maliciously, under coercion, or compelled by a legal order, can inspect any running VM without the tenant's knowledge.

### 7. Co-Tenant Side-Channel Attacks

A co-tenant VM running on the same physical host can leak secrets from another VM without any hypervisor access, by exploiting **shared hardware resources**:

**CPU Cache Timing (Spectre/Meltdown family)**
Modern CPUs share the Last-Level Cache (LLC, typically L3) across physical cores, with L1 and L2 per-core. SMT siblings on the same core share L1/L2, but cross-VM co-tenant attacks primarily exploit the shared LLC. A malicious co-tenant can measure cache access times to infer which memory addresses a victim VM is accessing — and from that, reconstruct cryptographic keys or sensitive data patterns.

- **Spectre** (CVE-2017-5753, CVE-2017-5715) — exploits speculative execution to read across privilege boundaries
- **Meltdown** (CVE-2017-5754) — allows user-space code to read kernel memory within the same OS; not itself a cross-VM attack, but it demonstrated the transient-execution class of leaks; patched in software but with performance cost
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

| Regulation | Jurisdiction | Requirement | Traditional Cloud Problem |
|---|---|---|---|
| **GDPR** | EU | Appropriate technical measures to protect personal data | Cloud provider has access to personal data in memory |
| **HIPAA** | US | PHI must be protected against unauthorised access | Hypervisor admins can access PHI in running workloads |
| **PCI-DSS** | Global | Cardholder data must be protected at all times | "In use" is an unprotected state in traditional VMs |
| **FedRAMP / IL4/IL5** | US Federal | US government data must not be accessible to CSP staff | Structural impossibility without hardware isolation |
| **DORA** | EU | ICT risk management must address third-party service provider access | Cloud infrastructure access breaks the ICT supply chain trust requirements |
| **NIS2** | EU | Cybersecurity risk management for essential/important entities, including supply chain security | The cloud provider's privileged access to workloads is itself a supply-chain risk that must be managed |

Confidential Computing is increasingly cited by compliance frameworks as the mechanism to satisfy these "data in use" requirements.

---

## Why Hardware Enforcement Is the Only Solution

Any purely software-based isolation boundary can be bypassed by software running at a higher privilege level. It is by design: the hypervisor must be able to manage guest resources.

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

- VM memory is hardware-encrypted and access-controlled by the CPU — for example, Intel TDX marks guest memory as "TD Private", enforcing at the hardware level that only the TD can access it; the hypervisor has no hardware path to plaintext, regardless of privilege level
- The Trusted Computing Base (TCB) is reduced — the hypervisor and host OS are no longer trusted components
- Boot measurements are rooted in hardware — not in provider-controlled firmware
- Tenants can independently verify the integrity of their environment before trusting it with secrets

The tenant trust boundary now extends *down to the hardware*, bypassing the hypervisor entirely. The following chapters explain the mechanisms that make this possible.

:::{note}
**Confidential Computing is not a silver bullet.** Researchers have demonstrated attacks that bypass CC protections, notably attacks requiring physical access to the hardware, such as rogue DRAM modules and memory-bus interposition. The CC threat model assumes the physical infrastructure is secure. These attacks are covered in [Known Attacks Against Confidential Computing](05a_known_attacks.md), once the building blocks needed to understand them are in place.
:::
