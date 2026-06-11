# What is Confidential Computing?

## The Data Security Triad

Modern data security is often described using three pillars:

| Pillars | Description | Protection Mechanism |
|---|---|---|
| **Data at Rest** | Stored on disk, databases, backups | Encryption (e.g., AES, LUKS) |
| **Data in Transit** | Moving across networks | TLS/mTLS, VPNs |
| **Data in Use** | Actively being processed in memory | **Confidential Computing** |

For decades, security focused on the first two pillars. **Confidential Computing (CC)** fills the missing pillar - protecting ***data in use.***

```{figure} ../images/page_04.png
:alt: Data security triad
:align: center
```

## Current Data Security Challenges

When you run a workload in an infrastructure managed by an external entity, you face several fundamental challenges:

- **Data Vulnerability when in Use** — even if your data is encrypted at rest and in transit, it must be decrypted into plaintext memory when the CPU processes it. Anyone with privileged access to the host can read that memory.
- **Insider Threats** — employees, contracted vendors, or malicious administrators with physical or hypervisor-level access can inspect running workloads.
- **Compliance Needs** — regulations like HIPAA, GDPR, PCI-DSS, and DORA require demonstrable data protection, including against infrastructure operators.
- **Multi-Tenant Risks** — in shared infrastructure software and hardware vulnerabilities can expose data between tenants.

## Current Solutions

- Legal contracts
- Governance
- Privacy Enhancing Technologies (PETs)

```{figure} ../images/page_03.png
:alt: Current Data Security Challenges and Solutions
:align: center
```

***Confidential Computing is one of the key PET technology.***

## Confidential Computing Definition

> *"Confidential Computing is the protection of data in use by performing the computation in a hardware-based, attested Trusted Execution Environment."*
> — [Confidential Computing Consortium](https://confidentialcomputing.io)

Three key phrases in this definition:

1. **Protection of data in use** — not just at rest or in transit, but while actively being processed.
2. **Hardware-based** — the security guarantee comes from the hardware itself, not from software policies that can be bypassed.
3. **Attested Trusted Execution Environment (TEE)** — you can *verify* (remotely) that the environment is genuine and unmodified before trusting it with your secrets.

The CCC further specifies that TEEs provide three distinct security properties that are often overlooked:

| Property | What it means |
|---|---|
| **Data confidentiality** | Code running outside the TEE cannot read data inside it |
| **Data integrity** | Code running outside the TEE cannot modify data inside it without detection |
| **Code integrity** | The code running inside the TEE cannot be replaced or tampered with by outside software |

Code integrity in particular is frequently underestimated — it ensures not just that your *data* is protected, but that the *computation itself* has not been altered by a privileged adversary.

## The Core Problem Confidential Computing Solves

Confidential Computing solves the problem of securing remote computation — executing software on a remote computer owned by an untrusted party, with integrity and confidentiality guarantees.

This shifts the trust requirement: instead of trusting the infrastructure operator's policies and personnel, you trust the hardware itself. **A cloud provider's software stack — including privileged administrators — cannot access your data in use, and you can verify this cryptographically.**

:::{note}
This guarantee applies to *software-layer* attackers. CC's threat model still assumes physical infrastructure security — attacks requiring physical hardware access (such as memory bus interposition) are out of scope. These limits are covered in the Trust Boundary chapter.
:::

```{figure} ../images/page_05.png
:alt: What problem does Confidential Computing solve
:align: center
```

:::{note}
CC does **not** protect against vulnerabilities *within* your own application code. If your app has a bug that leaks data, CC won't help. It protects against threats from the *infrastructure* layer.
:::
