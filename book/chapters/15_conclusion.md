# Conclusion

## What We Covered

This book walked through Confidential Computing from first principles to production deployment:

**Why it exists** — Traditional cloud security cannot protect data *in use*. The hypervisor, host OS, and infrastructure administrators all have unrestricted access to running workload memory. Confidential Computing moves the trust boundary down to the hardware itself, making those privileged layers irrelevant to workload security.

**How it works** — TEEs combine memory encryption with hardware-enforced access control and measured boot. Remote attestation closes the remaining gap: before trusting a TEE with secrets, a remote party can cryptographically verify that the correct software is running inside a genuine, unmodified hardware environment.

**What to deploy** — Three deployment tiers match different threat models:
- **Pillar 1 (CVM):** Protect a standalone VM from the infrastructure operator
- **Pillar 2 (Confidential Containers):** Protect individual Kubernetes pods from both the infrastructure and cluster administrators — the right choice for most organizations starting with CC
- **Pillar 3 (Confidential Cluster):** Protect entire Kubernetes nodes, including the control plane, from the infrastructure operator

**The ecosystem** — CNCF CoCo provides an open-source foundation that abstracts AMD SEV-SNP, Intel TDX, and IBM Secure Execution behind a common API. Trustee (KBS + AS + RVPS) handles remote attestation and secret delivery. The IETF RATS framework provides the conceptual vocabulary that ties vendors and projects together.

---

## What This Technology Does Not Solve

Confidential Computing reduces the trust you must place in cloud infrastructure. It does not:

- Protect against vulnerabilities **within your own application code**
- Defend against **physical attacks** on the hardware (memory bus interposition, rogue DIMMs) — these remain out of scope for the current threat model
- Eliminate the need for **secure software development practices** — a buggy workload inside a TEE is still a buggy workload
- Replace **network security** — inter-node traffic still requires encryption (e.g., WireGuard in a Confidential Cluster)

---

## Where the Technology Is Heading

Confidential Computing is maturing rapidly. Key trends as of the time of writing:

- **GPU TEEs** — Nvidia H100 and later support confidential computing for AI training and inference.
- **Broader cloud availability** — All major cloud providers now offer CC instances; availability of attestation infrastructure is expanding
- **Standards convergence** — IETF RATS (RFC 9334) provides the conceptual framework; tooling is converging around it
- **Regulatory tailwinds** — DORA, NIS2, and evolving GDPR guidance are increasing the compliance pressure that drives CC adoption in financial services and healthcare

---

## Getting Started

If you have not yet run the labs, start with **Lab 1** (CVM attestation on Azure) for a hardware-backed experience, or **Lab 2** (CoCo without confidential hardware) if you want to experiment locally without specialized hardware.

For production deployments, the recommended path:
1. Start with **Pillar 2 (CoCo)** on a cloud provider that supports SEV-SNP or TDX
2. Use **Trustee** as your attestation and secret delivery service
3. Validate your threat model against the three-pillar framework in this book

---

## About the Author

**Pradipta Banerjee** is a Project Maintainer of the [CNCF Confidential Containers](https://github.com/confidential-containers) project. The author's work focuses on bringing Confidential Computing into cloud-native ecosystems and making it accessible to practitioners without hardware security backgrounds.

**Acknowledgements:** Ariel Adam, Axel Saß, Christophe de Dinechin, Emanuele Esposito, Jens Freimann, Mohammed Adnan, Tobin Feldman-Fitzthum, Vitaly Kuznetsov, Magnus Kulke, and many others in the community whose work and feedback shaped this material.
