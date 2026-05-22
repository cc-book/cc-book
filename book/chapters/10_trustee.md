# Trustee

[Trustee](https://github.com/confidential-containers/trustee) is the remote attestation and secret brokering infrastructure for CNCF Confidential Containers. It is the component that makes the security guarantees of CoCo real: a CVM cannot access secrets until Trustee verifies it is running the expected, unmodified software.

Trustee implements the **Relying Party** and **Verifier** roles from the IETF RATS architecture, and consists of three sub-components:

| Component | RATS Role | Responsibility |
|---|---|---|
| **Key Broker Service (KBS)** | Relying Party | Receives attestation requests; releases resources after verification |
| **Attestation Service (AS)** | Verifier | Verifies TEE evidence against reference values |
| **Reference Value Provider (RVPS)** | Reference Value Provider | Supplies golden measurements for comparison |

---

## Architecture

The CVM's Attestation Agent sends attestation evidence to the KBS. The KBS forwards it to the AS for verification against the RVPS. Upon a positive result, the KBS releases the requested resource (e.g., a decryption key) from the KMS backend.

```{figure} ../images/page_65.png
:alt: Trustee Architecture
:align: center
```

## End-to-End Flow

A CVM attests to request a resource. The KBS appraises the attestation result (EAR/AR4SI) before releasing a key or secret. Trustee can also delegate verification to external services (Intel Trust Authority, NVIDIA NRAS, etc.) and integrate with KMS, Vault, HSM, or Kubernetes Secrets as key backends.

```{figure} ../images/page_66.png
:alt: Trustee Architecture — end to end example
:align: center
```

---

## CoCo Attestation

CoCo performs **lazy attestation** — the Attestation Agent inside the CVM does not attest at pod startup. Attestation is triggered on-demand when the workload first requests a secret from the KBS.

Two attestation models are supported:

**Background Check Model** — the default CoCo mode. The CVM sends evidence directly to Trustee; Trustee verifies and releases the secret.

```{figure} ../images/page_67_1.png
:alt: CoCo Attestation — Background Check Model
:align: center
```

**Passport Check Model** — the CVM obtains a reusable attestation token from the Verifier and presents it to one or more Relying Parties directly. Useful when many services need to verify the same CVM.

```{figure} ../images/page_67_2.png
:alt: CoCo Attestation — Passport Check Model
:align: center
```

| Model | Flow | Use When |
|---|---|---|
| **Background Check** | CVM → Evidence → AS → Result → KBS → Secret → CVM | Default CoCo mode |
| **Passport Check** | CVM → Evidence → AS → Token → CVM → Token → KBS → Secret | Many Relying Parties; token reuse |

---

## Workload APIs

Inside the pod, the **Confidential Data Hub (CDH)** exposes a local HTTP endpoint for secret retrieval. All requests trigger attestation if not already performed, and return the secret only on success.

```{figure} ../images/page_68.png
:alt: CoCo Workload APIs
:align: center
```

**Secret Resource Release API:**
```bash
GET http://127.0.0.1:8006/cdh/resource/{repository}/{type}/{tag}
```

**Example — retrieve a decryption key stored in KBS:**
```bash
curl http://127.0.0.1:8006/cdh/resource/default/enckey/key.pem
```

---

## Sealed Secrets

A **sealed secret** is a Kubernetes Secret whose value is encrypted and can only be decrypted inside a TEE after successful attestation. The encrypted form is stored in etcd — the actual plaintext never exists outside the TEE.

```{figure} ../images/page_69.png
:alt: CoCo Sealed Secrets flow
:align: center
```

**Flow:**
1. Operator creates a sealed secret config pointing to a KBS resource
2. The config is encoded as a sealed secret value and stored as a K8s Secret — etcd holds only the encrypted form
3. When the pod runs inside the TEE, CDH attests to Trustee and retrieves the real secret
4. The plaintext value is injected into the container as an env var or volume mount

---

## Mapping to RATS Standard

| CoCo Component | RATS Role |
|---|---|
| Attestation Agent (AA) | Attester |
| AMD SP / Intel TDX Module | Hardware Root of Trust |
| Attestation Service (AS) | Verifier |
| Reference Value Provider (RVPS) | Reference Value Provider |
| Key Broker Service (KBS) | Relying Party |
| CVM attestation report | Evidence |
| Attestation Result (EAR/AR4SI) | Attestation Result |
