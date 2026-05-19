# Solution Stack

## High-Level Architecture

```{figure} ../images/page_38.png
:alt: Confidential Computing Solution Stack — High Level
:align: center
The CC solution stack: Attestation Service (Verifier in RATS), Key Broker Service (Relying Party), Key Management Service, Image Build Service for signed/encrypted images, and Image Registry for storing encrypted container/VM images.
```

A complete Confidential Computing solution requires several interacting services:

| Component | RATS Role | Function |
|---|---|---|
| **Attestation Service (AS)** | Verifier | Validates TEE evidence against reference values |
| **Key Broker Service (KBS)** | Relying Party | Releases secrets only after attestation passes |
| **Key Management Service (KMS)** | — | Securely stores and manages cryptographic keys |
| **Image Build Service** | — | Signs and encrypts container/VM images |
| **Image Registry** | — | Stores encrypted/signed images (Quay.io, ECR, Docker Hub, etc.) |

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

---

## Red Hat Confidential Containers (CoCo) Solution Stack

```{figure} ../images/page_39.png
:alt: Red Hat Confidential Containers Solution Stack
:align: center
The Red Hat / CNCF CoCo solution stack built on CNCF projects: Kata Containers for VM sandbox runtime, Confidential Containers (CoCo) for attestation/encrypted images/sealed secrets/policy, and Trustee (KBS + AS + RVPS) for the trust infrastructure.
```

---

## Trustee Architecture

```{figure} ../images/page_65.png
:alt: Trustee Architecture
:align: center
Trustee architecture: the CVM's Attestation Agent sends attestation evidence to the Key Broker Service (KBS). The KBS forwards it to the Attestation Service (AS) for verification against the Reference Value Provider Service (RVPS). Upon a positive result, the KBS releases the requested resource (e.g., a decryption key) from the KMS backend.
```

```{figure} ../images/page_66.png
:alt: Trustee Architecture — end to end example
:align: center
End-to-end Trustee flow: A CVM attests to request a resource. The KBS sends evidence for appraisal and appraises the result (EAR/AR4SI) before releasing a resource. Trustee can also delegate verification to external services (Intel Trust Authority, IBM NRAS, etc.) and integrate with KMS, Vault, HSM, or Kubernetes Secrets as key backends.
```
