# Known Attacks Against Confidential Computing

Confidential Computing is not a silver bullet. Researchers have demonstrated attacks that bypass CC protections — particularly those requiring physical access to hardware. Now that the building blocks are in place (TEE hardware, measured boot, certificate chains, and remote attestation), you have the vocabulary to understand how these attacks work and what they mean for the threat model. Understanding them is important for setting accurate expectations.

## BadRAM (CVE-2024-21944)

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

## TEE.Fail — Physical Bus Interposition on DDR5

**What it is:** A side-channel attack that physically intercepts all memory traffic between the CPU and DDR5 DRAM to extract secrets from TEEs — including Intel TDX, AMD SEV-SNP, and Nvidia GPU Confidential Computing.

**How it works:**

Researchers built a custom **interposition device** (~$1,000 of off-the-shelf electronics) that sits between the CPU and DIMM and passively captures all memory bus traffic. The attack exploits a fundamental weakness:

> **AES-XTS encryption, used by both Intel and AMD, is deterministic** — identical plaintexts always produce identical ciphertexts. This allows pattern analysis and data extraction without direct decryption. AES-XTS was chosen specifically for performance: it operates on fixed-size tweakable blocks with no IV negotiation overhead, making it suitable for low-latency memory encryption. The trade-off is this determinism vulnerability.

Even AMD's **Ciphertext Hiding** feature (designed to obscure memory patterns) was shown to be insufficient.

**What can be extracted:**

- Cryptographic keys from Intel TDX and AMD SEV-SNP guests
- **ECDSA attestation keys** from Intel's Provisioning Certification Enclave (PCE) — the PCE-certified Quoting Enclave (QE) private key can be extracted, allowing an attacker to generate new TDX Quotes (the hardware-specific attestation evidence) that are cryptographically indistinguishable from genuine ones
- Private signing keys from OpenSSL's ECDSA implementation on fully patched systems
- Once attestation keys are extracted, the attack extends to **Nvidia GPU Confidential Computing**

**Notable:** this is the first demonstrated attack against DDR5, the latest generation of memory hardware.

**Vendor response:** Both AMD and Intel classify physical bus interposition as **out of scope** for their TEE threat models. No firmware mitigations are planned. Researchers suggest firmware- and cryptographic-library-level countermeasures against deterministic encryption (e.g., probabilistic encryption schemes in the TEE firmware or TLS libraries), though these carry performance costs.

*References: [The Hacker News](https://thehackernews.com/2025/10/new-teefail-side-channel-attack.html)*

---

## What These Attacks Mean in Practice

```{admonition} Physical access changes the threat model
:class: warning

Both BadRAM and TEE.Fail require **physical access to the server hardware** — either to modify DRAM modules (BadRAM) or to attach an interposition device to the memory bus (TEE.Fail). 

It's important to keep in mind that CC threat model still relies on the assumption that the **physical infrastructure is secure**.
```
