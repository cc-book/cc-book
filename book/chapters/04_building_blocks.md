# Confidential Computing Building Blocks

Confidential computing combines hardware and software building blocks to protect data in use: a Root of Trust, a minimal Trusted Computing Base (TCB), Trusted Execution Environments (TEEs), measured boot, and remote attestation.
Understanding how these pieces establish and verify trust is essential before starting to use confidential computing solutions.

This section covers four areas:

- **Concepts** — the core ideas: Root of Trust, Trusted Computing Base, TEEs, and boot security mechanisms
- **TEE Technologies** — how AMD SEV-SNP, Intel TDX, and Intel SGX implement those concepts in practice
- **Remote Attestation** — how a TEE proves its integrity and initial state to a remote party
- **Known Attacks** — demonstrated attacks against CC protections, and what they mean for the threat model
