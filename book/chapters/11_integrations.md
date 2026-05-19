# Integrations & Ecosystem

CoCo is designed to integrate with the broader cloud-native ecosystem.

## Integration Status Overview

```{figure} ../images/page_71.png
:alt: CoCo Integrations
:align: center
CoCo integration status with cloud-native projects: Tekton Pipelines, Tekton Chains, KServe ModelServing (complete — leverages modelcar for encrypted models), KServe ModelMesh, KubeFlow, Eclipse Che/Dev Spaces, KubeArmor, CoCo Validated Patterns, KonFlux, Podman Desktop Extension, and SPIFFE/SPIRE.
```

---

## KServe ModelServing (Complete)

This is one of the most impactful CoCo integrations — enabling **confidential AI inference**.

CoCo + KServe allows serving ML models where:
- Model weights are **encrypted** in the OCI image
- Only the CoCo pod (after attestation) can decrypt the model
- The cloud provider cannot access model weights
- Users get inference results without the model being exposed

**How it works:** Uses **ModelCar** — the model is embedded as an OCI artifact inside the container image. `image-rs` inside the CVM downloads and decrypts it via attestation to KBS.

**Reference:** [KServe OCI Storage with ModelCars](https://kserve.github.io/website/latest/modelserving/storage/oci/#using-modelcars)

---

## Tekton Chains (Complete)

Supply chain security for CI/CD — pipeline jobs run inside TEEs, build artifacts are **signed using keys only accessible inside the TEE**, and attestation proves the signing happened in a trusted environment.

---

## Eclipse Che / Dev Spaces (Complete)

Confidential development environments — your entire IDE workspace runs inside a TEE, protecting source code and intellectual property from the IDE platform operator.

**Reference:** [kata-cde](https://github.com/l0rd/kata-cde)

---

## KubeArmor (WIP)

[KubeArmor](https://kubearmor.io) provides LSM-based runtime security inside CoCo pods, restricting syscalls, file access, and network operations. POC complete; code review in progress.

---

## SPIFFE/SPIRE (TBD)

Integration with [SPIFFE/SPIRE](https://spiffe.io) would enable attestation-based workload identity:
- SPIRE issues SVIDs only after CoCo attestation succeeds
- Service-to-service mTLS using attestation-derived identities
- Bridging hardware attestation with SPIFFE's identity ecosystem

---

## Policy Enforcement with genpolicy

`genpolicy` generates OPA policies that restrict what the K8s control plane can ask kata-agent to do. The policy is hashed and included in the CVM's measurements — if the policy is modified, attestation fails.

```bash
# Generate policy from Kubernetes manifest
genpolicy -i deployment.yaml -o policy.rego
kubectl apply -f deployment-with-policy.yaml
```

**What policies restrict:**
- Allowed RPC calls from kubelet to kata-agent
- Environment variables that may be injected
- Mount points allowed inside the CVM
- Container images that may be pulled

---

## Current Challenges

```{figure} ../images/page_70.png
:alt: Current challenges in CoCo
:align: center
Outstanding challenges: encrypted image support for CRI-O in Kata Containers, CSI storage support for the Kata/remote-hypervisor (peer-pods) model, speeding up large container image downloads inside the CVM, and establishing trust in CSP-provided firmware.
```

| Challenge | Status | Impact |
|---|---|---|
| Kata encrypted image support for CRI-O | WIP | Full CRI-O compatibility |
| CSI storage support for peer-pods | WIP | Persistent storage in peer-pod model |
| Faster container image downloads inside CVM | Active | Reduces pod startup time |
| Trusting CSP-provided firmware | Research | Reducing required CSP trust |

---

## CoCo Validated Patterns

[Validated Patterns](https://validatedpatterns.io) provide reference architectures:
- **CoCo Pattern** — initial validated pattern available, includes Operator installation, Trustee deployment, and sample workloads
- **Reference:** [coco-pattern](https://github.com/validatedpatterns/coco-pattern)
