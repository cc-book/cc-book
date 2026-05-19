# Confidential Computing Deep Dive

**Author:** Pradipta Banerjee, Engineer Lead — Confidential Containers  
**Acknowledgements:** Ariel Adam, Christophe de Dinechin, Emanuele Esposito, Jens Freimann, Tobin Feldman-Fitzthum, Vitaly Kuznetsov, and many others.

---

## About This Book

This book is a comprehensive deep dive into **Confidential Computing** — one of the most important emerging areas in cloud security. It covers the theory, architecture, components, and real-world deployment patterns needed to understand and work with confidential computing systems.

The content is structured for engineers, architects, and security practitioners who want to understand:

- **Why** confidential computing exists and what problems it solves
- **What** the core building blocks are (TEEs, attestation, measured boot)
- **How** production systems like Kata Containers and CNCF Confidential Containers (CoCo) are built
- **Where** to apply it — use cases, integrations, and deployment topologies

## Book Structure

```{tableofcontents}
```

## Key Concepts at a Glance

| Concept | Short Definition |
|---|---|
| **TEE** | Trusted Execution Environment — hardware-isolated region for computation |
| **CVM** | Confidential Virtual Machine running inside a TEE |
| **TCB** | Trusted Computing Base — the minimal set of components you must trust |
| **RoT** | Root of Trust — foundational hardware security anchor |
| **TPM** | Trusted Platform Module — chip for secure key storage and measurement |
| **Remote Attestation** | Cryptographic proof that a remote system is running expected software |
| **CoCo** | CNCF Confidential Containers — run K8s Pods inside CVMs |
| **KBS** | Key Broker Service — releases secrets only after attestation |

---

> *"Confidential Computing is the protection of data in use by performing computation in a hardware-based, attested Trusted Execution Environment."*
> — Confidential Computing Consortium
