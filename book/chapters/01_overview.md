# What is Confidential Computing?

## The Data Security Triad

Modern data security is often described using three states of data:

| Data State | Description | Protection Mechanism |
|---|---|---|
| **Data at Rest** | Stored on disk, databases, backups | Encryption (e.g., AES, LUKS) |
| **Data in Transit** | Moving across networks | TLS/mTLS, VPNs |
| **Data in Use** | Actively being processed in memory | **Confidential Computing** |

For decades, security focused on the first two states. Confidential Computing fills the missing pillar — protecting data *while it is being computed on*.

## Current Data Security Challenges

```{figure} ../images/page_03.png
:alt: Current Data Security Challenges and Solutions
:align: center
Current data security challenges — data vulnerability when in use, insider threats, compliance needs, and multi-tenant cloud risks. Confidential Computing is a key Privacy Enhancing Technology (PET) addressing these.
```

When you run a workload in a public cloud, you face several fundamental challenges:

- **Data Vulnerability when in Use** — even if your data is encrypted at rest and in transit, it must be decrypted into plaintext memory when the CPU processes it. Anyone with privileged access to the host can read that memory.
- **Insider Threats** — cloud provider employees, contracted vendors, or malicious administrators with physical or hypervisor-level access can inspect running workloads.
- **Compliance Needs** — regulations like HIPAA, GDPR, and PCI-DSS require demonstrable data protection, including against infrastructure operators.
- **Multi-Tenant Cloud Risks** — in shared infrastructure, side-channel attacks and hypervisor vulnerabilities can expose data between tenants.

## The Confidential Computing Definition

```{figure} ../images/page_04.png
:alt: What is Confidential Computing
:align: center
Confidential Computing — the missing pillar of the data security triad.
```

> *"Confidential Computing is the protection of data in use by performing the computation in a hardware-based, attested Trusted Execution Environment."*
> — [Confidential Computing Consortium](https://confidentialcomputing.io)

Three key phrases in this definition:

1. **Protection of data in use** — not just at rest or in transit, but while actively being processed.
2. **Hardware-based** — the security guarantee comes from the CPU hardware itself, not from software policies that can be bypassed.
3. **Attested Trusted Execution Environment** — you can *verify* (remotely) that the environment is genuine and unmodified before trusting it with secrets.

## The Core Problem Confidential Computing Solves

```{figure} ../images/page_05.png
:alt: What problem does Confidential Computing solve
:align: center
Confidential Computing solves the problem of securing remote computation — executing software on a remote computer owned by an untrusted party, with integrity and confidentiality guarantees.
```

This is the fundamental promise: **you can run code on someone else's machine and still prove that your data wasn't seen by the machine's owner.**

:::{note}
Confidential Computing does **not** protect against vulnerabilities *within* your own application code. If your app has a bug that leaks data, CC won't help. It protects against threats from the *infrastructure* layer.
:::
