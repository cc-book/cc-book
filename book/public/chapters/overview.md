# What is Confidential Computing?

Before getting to confidential computing, we must understand data security challenges and solutions.

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

***Confidential Computing is one of the key PET technologies.***

## How Confidential Computing Compares to Other PETs

Confidential Computing is not the only technology that protects data during computation. Three cryptographic approaches solve overlapping problems, and it helps to know when each fits:

- **Fully Homomorphic Encryption (FHE)** computes directly on encrypted data: the data is *never* decrypted, not even in memory. The trade-off is performance: depending on the workload, FHE is orders of magnitude slower than plaintext computation, and applications must be rewritten around a restricted set of operations.
- **Secure Multi-Party Computation (MPC)** lets multiple parties jointly compute a function without revealing their private inputs to each other. It requires no special hardware, but needs interactive protocols between the parties, custom protocol design per application, and significant network overhead.
- **Differential Privacy (DP)** adds calibrated statistical noise to query results or training data so that individual records cannot be inferred. It protects *outputs*, not the computation itself: the party running the computation still sees the raw data.

| | Confidential Computing | FHE | MPC | Differential Privacy |
|---|---|---|---|---|
| **Trust anchor** | CPU vendor's hardware | Mathematics (cryptography) | Mathematics (cryptography) | Statistics |
| **Performance overhead** | Low (single-digit % for most workloads) | Very high | High (network-bound) | Negligible |
| **Application changes** | None (VM-based TEEs) | Rewrite around FHE operations | Custom protocol per use case | Query/pipeline changes |
| **Protects data in use from infrastructure** | ✔ Yes | ✔ Yes | Partially (split among parties) | ✗ No |
| **General-purpose computation** | ✔ Yes | Limited | Limited | N/A |
| **Maturity for production** | GA on all major clouds | Emerging | Niche | Mature (analytics) |

The practical takeaway: **Confidential Computing is the only PET that runs existing, unmodified applications at near-native speed**, at the cost of trusting the CPU vendor and its hardware implementation. FHE and MPC remove even that trust assumption but are limited to specialized workloads. These technologies also compose: multi-party analytics can run MPC protocols *inside* TEEs, and a model trained in a TEE can be released with differential privacy guarantees.

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
This guarantee applies to *software-layer* attackers. CC's threat model still assumes physical infrastructure security — attacks requiring physical hardware access (such as memory bus interposition) are out of scope. These limits are covered in [Known Attacks Against Confidential Computing](05a_known_attacks.md).
:::

```{figure} ../images/page_05.png
:alt: What problem does Confidential Computing solve
:align: center
```

:::{note}
CC does **not** protect against vulnerabilities *within* your own application code. If your app has a bug that leaks data, CC won't help. It protects against threats from the *infrastructure* layer.
:::
