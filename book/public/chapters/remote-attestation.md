# Remote Attestation

Confidential computing has two dimensions: **runtime isolation** and **attestation**.

Runtime isolation — technologies like memory encryption — creates a boundary between the TEE and the untrusted world, protecting data while in use. But isolation alone doesn't address a fundamental problem: a TEE's initial state is typically configured by an untrusted host (for example, a hypervisor setting initial guest memory). Because that initial configuration is highly significant, a TEE is not considered secure unless those properties are validated.

Attestation closes this gap. It *extends trust from a hardware root of trust to a TEE*: the hardware root of trust attests to the TEE's configuration and initial state, typically by signing a report with a key tied to the hardware manufacturer. This is what allows a remote party to confirm they are communicating with a genuine, unmodified TEE running the expected software.

---

## Disambiguating "Attestation"

The term "attestation" is overloaded and worth clarifying before going further:

| Type | Characteristics |
|---|---|
| **Host attestation** (TPM-based) | Continuous, non-blocking; periodic checks; corrective actions on failure |
| **Confidential attestation** | Blocks secret delivery; scoped to the TEE's initial state |
| **SPIFFE/SPIRE workload attestation** | One component attesting to properties of another |

The parties capable of validating a host environment versus a guest TEE environment are usually distinct, making these separate processes. This chapter focuses on **confidential attestation**.

---

## Why Attestation Matters

Consider this scenario: you want to send sensitive data to a TEE running in a cloud provider's infrastructure. Before you send your secrets:

1. How do you know the TEE is real (not a software simulation)?
2. How do you know it's running the code you expect (not malware)?
3. How do you know the firmware hasn't been tampered with?

Remote attestation answers all three questions cryptographically.

---

## The IETF RATS Framework

The industry has standardized remote attestation procedures through the **IETF RATS (Remote ATtestation procedureS)** framework ([RFC 9334](https://www.rfc-editor.org/rfc/rfc9334)).

The *Attester* (TEE) produces *Evidence* (measurements/claims), which the *Verifier* checks against *Reference Values* from the Reference Value Provider Service (RVPS). The *Verifier* returns an Attestation Result to the *Relying Party*, which then decides whether to release a resource (e.g., a decryption key).

### Key Roles

| Role | Description | Example |
|---|---|---|
| **Attester** | The entity being attested — generates evidence about itself | The TEE (CVM) |
| **Evidence** | Claims produced by the Attester, containing measurements | Attestation report with PCR/RTMR values |
| **Verifier** | Validates evidence against reference values | Attestation Service (AS) |
| **Reference Value Provider (RVPS)** | Supplies the "golden" reference measurements | Firmware vendor, OS publisher |
| **Relying Party** | Uses the attestation result to make decisions | Application owner, Resource gatekeeper |

---

## Attestation Models

### Background Check Model

Here is the flow of a background check model:

1. **RVPS provisions reference values** (golden measurements) to the Verifier
2. **Attester (TEE) sends Evidence** to the Relying Party (attestation report: hardware measurements, firmware hash, etc.)
3. **Relying Party forwards Evidence** to the Verifier
4. **Verifier compares** Evidence against Reference Values
5. **Verifier returns Attestation Result** to the Relying Party
6. **Relying Party decides** whether to release the resource (key, secret, certificate)

```{figure} ../images/rats_background_check.png
:alt: CoCo Attestation — Background Check Model
:align: center
```

### Passport Check Model

Here is the flow of a passport check model:

1. **RVPS provisions reference values** (golden measurements) to the Verifier
2. **Attester (TEE) sends Evidence** to the Verifier (attestation report: hardware measurements, firmware hash, etc.)
3. **Verifier compares** Evidence against Reference Values
4. **Verifier returns Attestation Result** to the Attester
5. **Attester (TEE) presents Attestation Result** to the Relying Party
6. **Relying Party decides** whether to release the resource (key, secret, certificate)

```{figure} ../images/rats_passport.png
:alt: CoCo Attestation — Passport Model
:align: center
```

---

## Verification Services

| Service | Provider | Supports |
|---|---|---|
| **Intel Trust Authority (ITA)** | Intel | TDX, SGX |
| **Azure Attestation Service (MAA)** | Microsoft | SNP, TDX, SGX |
| **Trustee/AS** | CNCF CoCo | SNP, TDX, SGX, IBM SE |

---

## Security Considerations

- **Freshness:** Always use nonces in attestation to prevent replay attacks.
- **Revocation:** If a CPU is found vulnerable, AMD/Intel can revoke VCEK/PCK certificates. Verifiers should check revocation lists.
- **Reference Value Management:** Keeping reference values (golden measurements) up to date as software is patched is an ongoing operational challenge.
- **Third-Party Trust:** When using cloud-provided attestation services, you trust the cloud provider's attestation infrastructure. Self-hosted Trustee eliminates this dependency.

