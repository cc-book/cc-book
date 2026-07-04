# Remote Attestation

Confidential computing has two dimensions: **runtime isolation** and **attestation**.

:::{note}
**What does "remote" mean in remote attestation?**

The term is used differently across the industry. Intel historically defines "remote" as *outside the CPU package* — i.e., any entity other than the CPU itself. The CCC, Red Hat, and most cloud-native practitioners use "remote" to mean *a party not under the control of the cloud infrastructure operator* — a verifier on a completely different network, beyond the provider's administrative reach. This book uses the CCC/industry definition: remote attestation lets a *workload owner* verify a TEE without trusting the cloud provider's own attestation infrastructure.
:::


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

The *Attester* (TEE) produces *Evidence* (measurements/claims), which the *Verifier* checks against *Reference Values* from a Reference Value Provider. The *Verifier* returns an Attestation Result to the *Relying Party*, which then decides whether to release a resource (e.g., a decryption key).

### Key Roles and Artifacts

| Role / Artifact | Description | Example |
|---|---|---|
| **Attester** (role) | The entity being attested — generates evidence about itself | The TEE (CVM) |
| **Evidence** (artifact) | Claims produced by the Attester, containing measurements | Attestation report with PCR/RTMR values |
| **Verifier** (role) | Validates evidence against reference values | Attestation Service (AS) |
| **Reference Value Provider** (role) | Supplies the "golden" reference measurements | Firmware vendor, OS publisher |
| **Relying Party** (role) | Uses the attestation result to make decisions | Application owner, Resource gatekeeper |

Trustee (Chapter 11) implements the Reference Value Provider role as a component called the **Reference Value Provider Service (RVPS)**. That name is Trustee-specific, not an IETF term.

:::{note}
**Evidence vs attestation report — terminology clarification**

This chapter uses the IETF RATS term **Evidence** (capitalised) for the abstract concept. In practice, Evidence takes hardware-specific forms:

- AMD SEV-SNP produces an **SNP attestation report** (signed by the VCEK)
- Intel TDX produces a **TDX Quote** (signed by the Quoting Enclave)

When you see "attestation report" elsewhere in this book or in vendor documentation, it refers to one of these concrete Evidence artifacts. The terms are used interchangeably; context determines which hardware format is meant.
:::
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
:alt: CC Attestation — Background Check Model
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
:alt: CC Attestation — Passport Model
:align: center
```

### When to Use Each Model

| | Background Check | Passport |
|---|---|---|
| **Verification trigger** | Each Relying Party verifies independently | Attester verifies once; presents token to many |
| **Freshness** | Evidence is fresh per request | Token has a bounded validity window (TTL) |
| **Relying Party requirement** | Must have access to a Verifier | Only needs to validate the token signature |
| **Best for** | Single Relying Party, or when fresh evidence is required every time | Multiple Relying Parties that trust the same Verifier |

---

## Verification Services

| Service | Provider | Supports |
|---|---|---|
| **Intel Trust Authority (ITA)** | Intel | TDX, SGX |
| **Azure Attestation Service (MAA)** | Microsoft | SNP, TDX, SGX |
| **Trustee/AS** | CNCF CoCo | SNP, TDX, SGX, IBM SE |

---

## Attestation Operations in Practice

The mechanics above are the easy part. The recurring operational work in production attestation is managing *reference values* and *policy* over time.

### Where reference values come from

A verifier needs "golden" measurements to compare Evidence against. In practice they come from three sources:

1. **Vendor-published values**: firmware vendors and OS publishers can publish expected measurements for their releases.
2. **Computed from the image**: tools compute the expected launch measurement directly from the artifacts you deploy. For example, [sev-snp-measure](https://github.com/virtee/sev-snp-measure) derives the SNP launch measurement from a given OVMF binary, kernel, initrd, and command line. This is the most common approach for custom guest images.
3. **Reproducible builds**: if the guest image builds reproducibly, anyone can independently rebuild it and confirm the measurement, removing the need to trust the image publisher's claim.

### Measurement churn

Every update to a measured component (firmware, kernel, initramfs, kernel command line, agent policy) changes the measurements. That means:

- **Patching is an attestation event.** A routine kernel security update will cause attestation failures unless the new reference values are provisioned to the verifier *before* the updated guests boot.
- **Rollouts need overlapping trust windows.** During a fleet upgrade, the verifier must accept both the old and new measurements; the old values are retired once the rollout completes.
- **Automate the pipeline.** Mature deployments generate reference values in CI as part of the image build and push them to the verifier (e.g., Trustee's RVPS) in the same pipeline that publishes the image.

### TCB versioning and recovery

Hardware vendors patch their own platform security (microcode, SNP firmware, the TDX module). The platform's **TCB version** is reported inside the Evidence, and the signing key itself is bound to it (AMD's VCEK is derived per TCB version). Verifier policy should enforce a *minimum* TCB version. This is how the ecosystem recovers from hardware vulnerabilities: the vendor ships fixed firmware, and verifiers raise the required TCB floor, causing unpatched hosts to fail attestation. A host that lags on firmware updates will (correctly) stop receiving secrets.

### Policy, not just matching

Real verifiers don't hard-compare every field. They evaluate Evidence against a **policy** (Trustee's Attestation Service uses [OPA](https://www.openpolicyagent.org/) Rego policies) that decides *which* claims matter: exact launch measurement pinning, minimum TCB version, allowed hardware models, debug-mode disallowed, and so on. Looser policies ease operations; tighter policies narrow the attack surface. Chapter 11 shows where these policies live in Trustee.

---

## Security Considerations

- **Freshness:** Always use nonces in attestation to prevent replay attacks.
- **Revocation:** If a CPU is found vulnerable, AMD/Intel can revoke VCEK/PCK certificates. Verifiers should check revocation lists.
- **Third-Party Trust:** When using cloud-provided attestation services, you trust the cloud provider's attestation infrastructure. Self-hosted Trustee eliminates this dependency. Trustee is covered in detail in Chapter 11, along with its integration into the CoCo attestation flow.