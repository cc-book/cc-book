# Market Landscape

## Market Size

Confidential Computing is a rapidly growing market:

| Year | TAM (CSP + Enablement Software ISVs) |
|---|---|
| **2024** | ~$9 billion |
| **2026** | ~$32 billion |

*Source: Everest Group — Confidential Computing: The Next Frontier in Data Security*

The ~3.5x growth in just two years reflects accelerating adoption driven by AI/ML workloads with sensitive model IP, regulatory requirements (GDPR, HIPAA, financial regulations), multi-cloud adoption increasing infrastructure trust concerns, and maturing hardware support (AMD EPYC, Intel Xeon 4th Gen+).

---

## Competitive Landscape

### Confidential Container Offerings

| Vendor | Product | Notes |
|---|---|---|
| **Azure** | Confidential Containers | AKS with SNP-based CoCo, TEE-based node pools |
| **AWS** | Nitro Enclaves | Process-based, tight AWS integration |
| **VMware** | Tanzu Confidential Pods | vSphere-based TEE containers |
| **Alibaba Cloud** | Confidential Containers | ACK-based |
| **Fortanix** | SDKMS + Enclaves | SGX-focused, enterprise key management |
| **Anjuna** | Seaglass | Lift-and-shift to SGX/SNP enclaves |
| **Edgeless Systems** | Marblerun | SGX + TDX orchestration for K8s |
| **CNCF CoCo** | Confidential Containers | Open source, multi-hardware, multi-cloud |

### Confidential VM Offerings

| Cloud Provider | TEE Technology |
|---|---|
| **Azure** | AMD SEV-SNP, Intel TDX |
| **AWS** | AMD SEV-SNP, AWS Nitro |
| **Google Cloud** | AMD SEV-SNP, Intel TDX |
| **Oracle Cloud** | AMD SEV-SNP |
| **IBM Cloud** | IBM Secure Execution (Z) |

### Turnkey Solution Providers

| Vendor | Domain | Value Proposition |
|---|---|---|
| **BeekeeperAI** | Healthcare AI | FDA-compliant AI model validation with CC |
| **Decentriq** | Data Cleanrooms | Secure multi-party analytics on sensitive data |
| **Snowflake** | Data Cleanrooms | Secure multiparty analytics at scale |
| **Habu** | Data Cleanrooms | Privacy-preserving data collaboration |
| **SAS Viya** | Secure AI | Enterprise analytics with CC |
| **Enkrypt AI** | LLM Protection | Protecting LLM IP and user data |
| **eXate** | Data Privacy | Policy-based data access control with CC |

---

## Why CNCF CoCo vs. Proprietary Solutions?

| Dimension | CNCF CoCo | Proprietary (AWS Nitro, Azure CC, etc.) |
|---|---|---|
| **Vendor lock-in** | None | High (cloud-specific APIs) |
| **Attestation control** | Self-hosted (Trustee) | Cloud provider controls attestation |
| **Hardware support** | Multi-hardware (SNP, TDX, SGX, IBM SE) | Often limited to one hardware vendor |
| **Cloud portability** | Any cloud or on-prem | Specific cloud only |
| **Community** | CNCF, open contributions | Vendor-controlled roadmap |
| **App changes needed** | Minimal | Varies (Nitro requires significant changes) |
| **Trust model** | Don't need to trust cloud provider | Must trust cloud provider for attestation |

---

## Performance Considerations

Confidential Computing introduces some performance costs:

| Source | Overhead | Mitigation |
|---|---|---|
| Memory encryption | ~5-10% for memory-intensive workloads | Modern AES-NI hardware minimizes this |
| DMA bounce buffers | Storage/network I/O latency | Tunable buffer sizes |
| Attestation on first secret | 1-5 seconds at pod startup | Cached after first attestation |
| Image download inside CVM | Increased pod startup time for large images | Image pre-warming, lazy pulls |

```{admonition} What CC Does NOT Protect Against
:class: warning

1. **Application vulnerabilities** — if your app has a SQL injection or buffer overflow, CC doesn't help.
2. **Side-channel attacks** — cache timing and power analysis attacks may cross TEE boundaries (hardware vendors continuously address these).
3. **Supply chain attacks on the image** — if the container image itself is malicious, CC provides no protection.
4. **Availability** — CC doesn't protect against Denial of Service attacks.
```

---

## References

| Resource | URL |
|---|---|
| Confidential Computing Consortium | https://confidentialcomputing.io |
| CNCF CoCo Project | https://github.com/confidential-containers |
| Trustee (KBS + AS) | https://github.com/confidential-containers/trustee |
| Kata Containers | https://katacontainers.io |
| IETF RATS RFC 9334 | https://www.rfc-editor.org/rfc/rfc9334 |
| Everest Group CC Market Report | https://confidentialcomputing.io/wp-content/uploads/sites/10/2023/03/Everest_Group_-_Confidential_Computing_-_The_Next_Frontier_in_Data_Security_-_2021-10-19.pdf |
| General CC Security Analysis | https://eprint.iacr.org/2016/086.pdf |
