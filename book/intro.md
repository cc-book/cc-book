# Confidential Computing Deep Dive

**Author:** Pradipta Banerjee, Project Maintainer — Confidential Containers  
**Acknowledgements:** Ariel Adam, Christophe de Dinechin, Emanuele Esposito, Jens Freimann, Tobin Feldman-Fitzthum, Vitaly Kuznetsov, Magnus Kulke and many others in the community.

---

## About This Book

This book is a comprehensive deep dive into **Confidential Computing**. It covers the theory, architecture, components, and use cases to understand and work with confidential computing.

The content is structured for engineers, architects, and security practitioners who want to understand:

- **Why** confidential computing exists and what problems it solves
- **What** the core building blocks are (TEEs, attestation, measured boot)
- **How** production systems using CNCF Confidential Containers (CoCo) are built
- **Where** to apply it — use cases, integrations, and deployment topologies

## Prerequisites

This book assumes working familiarity with the following:

- **Virtualisation** — how hypervisors, VMs, and guest/host boundaries work
- **Containers and Kubernetes** — container runtimes, pod lifecycle, and cluster architecture
- **Linux fundamentals** — boot process, kernel command line, systemd, and standard CLI tooling
- **Basic cryptography** — public/private key signing, certificate chains, and hash functions
- **Cloud infrastructure** — provisioning VMs, networking basics, and cloud CLI tooling (at least one lab targets Azure)

No prior knowledge of confidential computing or hardware security is assumed.

## Book Structure

```{tableofcontents}
```

> *"Confidential Computing is the protection of data in use by performing computation in a hardware-based, attested Trusted Execution Environment."*
> — Confidential Computing Consortium
