# Hands-On Labs

This chapter provides practical exercises to complement the concepts covered in previous chapters. The labs are designed to be independent — you can work through them in order or jump to the one most relevant to your environment.

| Lab | What you'll do | Hardware needed |
|-----|---------------|-----------------|
| [Lab 1: CVM Attestation on Azure](12_lab1_cvm_attestation.md) | Provision two Azure VMs (Trustee + SEV-SNP CVM), run hardware attestation end-to-end, retrieve a secret | Azure account |
| [Lab 2: CoCo Without Confidential Hardware](12_lab2_coco_without_hw.md) | Deploy CoCo on a standard Kubernetes cluster using the sample verifier | Any Linux VM |
| [Lab 3: CoCo-fy a Workload with cococtl](12_lab3_cococtl.md) | Transform an existing Kubernetes app into a confidential workload with one command | Any Linux VM |
| [Lab 4: CoCo on a Real CVM via Peer-Pods (BYOM)](12_lab4_byom.md) | Run a CoCo pod on a real Azure SEV-SNP CVM using cloud-api-adaptor's BYOM provider | Azure account |

## Component Versions

All labs in this chapter use the following pinned versions:

| Component | Version |
|-----------|---------|
| Ubuntu (VMs and CVMs) | 26.04 LTS |
| Kubernetes | 1.36.1 |
| CoCo helm chart (Labs 2 & 3) | 0.21.0 |
| Peerpods helm chart (Lab 4) | 0.3.0 (CAA v0.21.0) |
| Kata Containers | 3.31.0 |
| Trustee | v0.20.0 |
| guest-components | v0.20.0 |
