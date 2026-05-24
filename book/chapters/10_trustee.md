# Trustee

[Trustee](https://github.com/confidential-containers/trustee) is the remote attestation and secret brokering infrastructure for CNCF Confidential Containers.

Trustee implements the **Relying Party** and **Verifier** roles from the IETF RATS architecture, and consists of three sub-components:

| Component | RATS Role | Responsibility |
|---|---|---|
| **Key Broker Service (KBS)** | Relying Party | Receives attestation requests; releases resources after verification |
| **Attestation Service (AS)** | Verifier | Verifies TEE evidence against reference values |
| **Reference Value Provider (RVPS)** | Reference Value Provider | Supplies golden measurements for comparison |

[Guest-components](https://github.com/confidential-containers/guest-components) is the repository for the **Attester** role, which is implemented by the **Attestation Agent** running inside the TEE (CVM). The AA is responsible for sending the evidence (claims) from the TEE to prove the trustworthiness of the environment.

There are also few other helper components inside the TEE:

- Confidential Data Hub (CDH): The CDH facilitates secure key retrieval for kata-agent and applications. It also provides additional services, such as secure mount for external storage or key management client services to retrieve keys directly from external Key Management Services. The secure mount service enables mounting of encrypted storage inside the TEE. The CDH APIs are exposed to the applications via a local API Server.

---

## Architecture

The CVM's Attestation Agent (AA) sends attestation evidence to the KBS. The KBS forwards it to the AS for verification against the RVPS. Upon a positive result, the KBS releases the requested resource (e.g., a decryption key) from the KMS backend.

```{figure} ../images/page_65.png
:alt: Trustee Architecture
:align: center
```

## End-to-End Flow

A CVM attests to request a resource. The KBS appraises the attestation result before releasing a key or secret. Trustee can also delegate verification to external services (Intel Trust Authority, NVIDIA NRAS, etc.) and integrate with KMS, Vault, HSM, or Kubernetes Secrets as key backends.

```{figure} ../images/page_66.png
:alt: Trustee Architecture — end to end example
:align: center
```

---

## CoCo Attestation

CoCo performs **lazy attestation** — Attestation is triggered on-demand. For example during pod creation to retrieve container image signature policy and key, or image decryption key. It could also be triggered post pod creation when the workload requests a secret.

Two attestation models are supported:

**Background Check Model** — the default CoCo mode. The CVM sends evidence directly to Trustee; Trustee verifies and releases the secret.

```{figure} ../images/trustee_backgroud_check.png
:alt: CoCo Attestation — Background Check Model
:align: center
```

**Passport Check Model** — the CVM obtains a reusable attestation token from the Verifier and presents it to one or more Relying Parties directly. Useful when many services need to verify the same CVM.

```{figure} ../images/trustee_passport.png
:alt: CoCo Attestation — Passport Check Model
:align: center
```

---

## Workload APIs

Inside the pod, the **Confidential Data Hub (CDH)** exposes a local HTTP endpoint for secret retrieval. All requests trigger attestation if not already performed, and return the secret only on success.

### Secret Resource Release API

The secret resource release API endpoint is available at `http://127.0.0.1:8006/cdh/resource/` inside the pod.

The secret resource must be referenceable under the following path: `{repository}/{type}/{tag}`

**Example — retrieve a decryption key stored in KBS under `default/enckey/key.pem`:**

```bash
curl http://127.0.0.1:8006/cdh/resource/default/enckey/key.pem
```

### Sealed Secrets

A **sealed secret** is a Kubernetes Secret whose value is encrypted and can only be decrypted inside a TEE after successful attestation. The encrypted form is stored in etcd — the actual plaintext never exists outside the TEE.

```{figure} ../images/page_69.png
:alt: CoCo Sealed Secrets flow
:align: center
```

**Flow:**

1. User creates a sealed secret config pointing to a KBS resource
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
| Attestation Result | Attestation Result |
