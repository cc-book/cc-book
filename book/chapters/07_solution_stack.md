# Solution Stack

## High-Level Architecture

A complete Confidential Computing solution requires several interacting services:

| Component | RATS Role | Function |
|---|---|---|
| **Attestation Service (AS)** | Verifier | Validates TEE evidence against reference values |
| **Key Broker Service (KBS)** | Relying Party | Releases secrets only after attestation passes |
| **Key Management Service (KMS)** | — | Securely stores and manages cryptographic keys |
| **Image Build Service** | — | Signs and encrypts container/VM images |
| **Image Registry** | — | Stores encrypted/signed images (Quay.io, ECR, Docker Hub, etc.) |

```{figure} ../images/page_38.png
:alt: Confidential Computing Solution Stack — High Level
:align: center
```

---

## Core Components

### Attestation Service (AS)

The AS is the **Verifier** in the RATS architecture:

1. Receives **evidence** (attestation reports) from TEEs
2. Compares evidence against **reference values** (golden measurements from RVPS)
3. Evaluates **attestation policies** (e.g., firmware must be version X or later)
4. Returns a signed **Attestation Result** (EAR or AR4SI format)

The AS does not release secrets — it only says "yes, this TEE is trustworthy" or "no, it isn't."

### Key Broker Service (KBS)

The KBS is the **Relying Party**:

1. Receives attestation requests from TEEs
2. Forwards evidence to the Attestation Service
3. Evaluates the Attestation Result against resource-specific policies
4. Releases the requested resource (key, certificate, secret) — **only if attestation passes**

**API endpoint** (inside the CVM): `http://127.0.0.1:8006/cdh/resource/<repo>/<type>/<tag>`

### Key Management Service (KMS)

Common KMS backends integrated with KBS:
- HashiCorp Vault
- AWS KMS / Azure Key Vault
- Hardware Security Modules (HSMs)
- Kubernetes Secrets