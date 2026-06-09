# Glossary

Acronyms and key terms used throughout this book, listed alphabetically.

| Acronym / Term | Expansion | Brief Definition |
|---|---|---|
| **AA** | Attestation Agent | Component inside the CoCo CVM that handles the attestation process on behalf of the workload |
| **ARK** | AMD Root Key | Top-level key in AMD's certificate chain, used to sign the AMD SEV Key (ASK) |
| **AS** | Attestation Service | Trustee component that verifies attestation evidence against reference values |
| **ASK** | AMD SEV Key | Intermediate key in AMD's certificate chain, signed by the ARK and used to sign the VCEK |
| **BYOM** | Bring Your Own Machine | Deployment model where the user supplies their own (remote) machine as the CVM host |
| **CAA** | Cloud API Adaptor | CoCo component that provisions peer-pod CVMs via cloud provider APIs |
| **CDH** | Confidential Data Hub | CoCo component inside the CVM that acts as a proxy for secret retrieval |
| **CNI** | Container Network Interface | Standard interface for Kubernetes pod networking plugins (e.g. Flannel, Calico) |
| **CoCo** | Confidential Containers | CNCF project for running Kubernetes pods inside CVMs using Kata Containers |
| **CVM** | Confidential Virtual Machine | A virtual machine running inside a TEE, with hardware-encrypted memory |
| **CDI** | Container Device Interface | Standard for exposing hardware devices to containers |
| **DICE** | Device Identifier Composition Engine | Hardware RoT standard for deriving layered identity keys at each boot stage |
| **DMA** | Direct Memory Access | Hardware mechanism allowing devices to access system memory without CPU involvement; a source of side-channel risk |
| **GHCR** | GitHub Container Registry | GitHub's OCI-compatible container and artifact registry (ghcr.io) |
| **GRUB** | Grand Unified Bootloader | Common Linux bootloader responsible for loading the kernel |
| **IETF** | Internet Engineering Task Force | Standards body that publishes internet and security protocol specifications (RFCs) |
| **KBS** | Key Broker Service | Trustee component that releases secrets (keys, certificates) only after successful attestation |
| **KDS** | Key Distribution Service | AMD's public service for distributing VCEK certificates by chip ID and TCB version |
| **KVM** | Kernel-based Virtual Machine | Linux kernel hypervisor module used by QEMU to run VMs |
| **LLC** | Last-Level Cache | The largest shared CPU cache (typically L3); a surface for cache side-channel attacks |
| **LUKS** | Linux Unified Key Setup | Standard disk encryption specification on Linux, used to protect ephemeral CVM storage |
| **NSG** | Network Security Group | Cloud firewall construct (e.g. Azure) controlling inbound/outbound traffic to VMs |
| **OCI** | Open Container Initiative | Standards body defining container image and runtime specifications |
| **OPA** | Open Policy Agent | General-purpose policy engine; used in CoCo to enforce initdata policies |
| **ORAS** | OCI Registry As Storage | Tool for pushing and pulling arbitrary artifacts (binaries, configs) from OCI registries |
| **OVMF** | Open Virtual Machine Firmware | Open-source UEFI firmware used as the guest firmware in QEMU/KVM VMs |
| **PCE** | Provisioning Certification Enclave | Intel SGX enclave that certifies the Quoting Enclave's attestation key |
| **PCK** | Provisioning Certification Key | Intel platform-specific key used to sign TDX/SGX quote collateral |
| **PCCS** | Provisioning Certificate Caching Service | Local caching proxy for Intel PCS certificates, reducing latency in production deployments |
| **PCR** | Platform Configuration Register | Tamper-evident register inside a TPM that accumulates boot measurements via hash extension |
| **PCS** | Provisioning Certification Service | Intel's public service for distributing PCK certificates for TDX and SGX platforms |
| **PSP** | Platform Security Processor | Alternative name for AMD's dedicated security processor (also called ASP) |
| **QE** | Quoting Enclave | Intel SGX/TDX enclave that signs attestation quotes using a platform attestation key |
| **QEMU** | Quick EMUlator | Open-source machine emulator and virtualizer; used with KVM to run CVMs |
| **RAG** | Retrieval-Augmented Generation | LLM technique that grounds responses by retrieving relevant documents at query time |
| **RATS** | Remote ATtestation procedureS | IETF framework (RFC 9334) defining roles and flows for remote attestation |
| **RFC** | Request for Comments | IETF standards document; RFC 9334 defines the RATS attestation framework |
| **RoT** | Root of Trust | Foundational hardware component (e.g. AMD SP, TPM) whose integrity is assumed and not derived |
| **RTMR** | Runtime Extendable Measurement Register | Intel TDX equivalent of TPM PCRs; accumulates measurements during and after boot |
| **RVPS** | Reference Value Provider Service | Trustee component that stores and serves "golden" reference measurements for comparison |
| **SEAM** | Secure Arbitration Mode | New Intel CPU operation mode introduced by TDX to host and manage Trust Domains |
| **SEV** | Secure Encrypted Virtualization | AMD technology for encrypting VM memory to protect it from the hypervisor |
| **SEV-SNP** | Secure Encrypted Virtualization — Secure Nested Paging | AMD's extension to SEV adding integrity protection and a hardware attestation report |
| **SFTP** | Secure File Transfer Protocol | SSH-based protocol for secure file transfer between hosts |
| **SGX** | Software Guard Extensions | Intel's process-based TEE technology for running isolated enclaves within an application |
| **SNP** | Secure Nested Paging | The page-integrity component of AMD SEV-SNP that prevents hypervisor memory tampering |
| **SPIFFE** | Secure Production Identity Framework for Everyone | CNCF standard for workload identity in distributed systems |
| **SPIRE** | SPIFFE Runtime Environment | Reference implementation of the SPIFFE standard |
| **SVSM** | Secure VM Service Module | Software component that runs inside a TEE and provides hypervisor-like services (e.g. vTPM) without trusting the hypervisor |
| **TCB** | Trusted Computing Base | The minimal set of hardware, firmware, and software components that must be trusted for security to hold |
| **TCG** | Trusted Computing Group | Industry consortium that defines TPM and related trusted computing standards |
| **TDX** | Trust Domain Extensions | Intel's VM-based TEE technology that protects entire VMs (Trust Domains) from the hypervisor |
| **TEE** | Trusted Execution Environment | Hardware-enforced isolated region of a processor protecting code and data from privileged software |
| **TPM** | Trusted Platform Module | Hardware chip (or firmware equivalent) for secure key storage, measurement, and attestation |
| **UEFI** | Unified Extensible Firmware Interface | Modern PC firmware standard that replaced BIOS; provides Secure Boot capabilities |
| **UKI** | Unified Kernel Image | A single EFI binary bundling the kernel, initramfs, and kernel command line for measured boot |
| **VCEK** | Versioned Chip Endorsement Key | AMD per-chip, per-firmware key used to sign SNP attestation reports |
| **vTPM** | Virtual Trusted Platform Module | Software emulation of a TPM 2.0 chip, provided to a guest VM by the hypervisor or SVSM |
