# Confidential Computing: A Practical Deep Dive

**Author:** Pradipta Banerjee, Project Maintainer — Confidential Containers

---

## About This Book

Learn how **confidential computing protects data in use** with hardware-based
Trusted Execution Environments (TEEs). This practical guide explains remote
attestation, AMD SEV-SNP, Intel TDX, confidential virtual machines (CVMs), and
CNCF Confidential Containers (CoCo), then puts the concepts into practice with
Kubernetes and Azure labs.

The content is structured for engineers, architects, and security practitioners who want to understand:

- **Why** confidential computing exists and what problems it solves
- **What** the core building blocks are (TEEs, attestation, measured boot)
- **How** production systems using CNCF Confidential Containers (CoCo) are built
- **Where** to apply it — use cases, integrations, and deployment topologies

## Prerequisites

This book assumes working familiarity with the following:

- **Virtualisation** — how hypervisors, VMs, and guest/host boundaries work
- **Containers and Kubernetes** — container runtimes, pod lifecycle, and cluster architecture
- **Kata Containers** — helpful but not required; the Confidential Containers chapter includes a primer
- **Linux fundamentals** — boot process, kernel command line, systemd, and standard CLI tooling
- **Basic cryptography** — public/private key signing, certificate chains, and hash functions
- **Cloud infrastructure** — provisioning VMs, networking basics, and cloud CLI tooling (at least one lab targets Azure)

No prior knowledge of confidential computing or hardware security is assumed.

## Book Structure

```{tableofcontents}
```

> *"Confidential Computing is the protection of data in use by performing computation in a hardware-based, attested Trusted Execution Environment."*
> — Confidential Computing Consortium
