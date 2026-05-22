# Operational Aspects

Running Confidential Computing workloads in production introduces operational challenges that don't exist with traditional containers.

```{figure} ../images/page_73.png
:alt: Operational Aspects overview
:align: center
Operational topics: Metrics, Logging, Debugging, Network/Firewalls, CoCo Deployment Topologies, and Trustee (Remote Attestation) Deployment Topologies.
```

---

## Metrics

Monitoring CoCo workloads requires collecting metrics from multiple layers:

| Metric | What It Signals |
|---|---|
| Attestation success rate | Measurement drift, compromised nodes |
| Attestation latency (p99) | KBS/AS performance |
| CVM boot time | Image pull performance inside TEE |
| Secret retrieval latency | CDH/KBS responsiveness |
| Pod startup time | End-to-end CoCo overhead |

Standard Prometheus/OpenTelemetry instrumentation works inside the CVM — application metrics flow out through the normal pod networking path.

---

## Logging

```{figure} ../images/page_75.png
:alt: Logging
:align: center
Two log sources: pod logs (streamed from the container through kata-agent → kata-shim → containerd → kubelet, accessible via `kubectl logs`) and Kata VM logs (guest kernel, kata-agent, CDH, AA — captured by the Kata runtime on the worker node or sent back via the peer-pods control plane).
```

```{admonition} Security Consideration
:class: warning

Application logs flow **out of the TEE** to the host. This means the host OS (and potentially the cloud provider) can read log content. **Do not log sensitive data** (secrets, PII, cryptographic material) from CoCo workloads.
```

---

## Debugging

```{figure} ../images/page_76.png
:alt: Debugging
:align: center
Debugging CoCo workloads is more complex: the TEE boundary limits host-side introspection, there is no interactive access in production, and policy enforcement may block `kubectl exec`. Use enhanced logging, dev-mode permissive policies, and attestation report inspection to diagnose issues.
```

**Key debugging strategies:**

1. **Enhanced logging** — enable verbose logging in kata-agent, CDH, and AA during development
2. **Development mode** — use a permissive policy that allows `kubectl exec` (never in production)
3. **Attestation debugging** — check KBS logs for measurement mismatches; compare expected vs. actual measurements
4. **TEE-specific tools** — `snpguest` (AMD SNP) or `tdx-attest` (Intel TDX) inside the CVM

---

## Networking and Firewalls

```{figure} ../images/page_77.png
:alt: Firewall — Worker Node and Kata VM
:align: center
Firewall requirements differ between Kata/Qemu (local — no additional external ports needed) and Kata/Peer-Pods (remote — the worker node must reach the external Kata VM on TCP port 15150 for the agent-protocol-forwarder). Egress from the Kata VM is needed to reach KBS, image registries, and attestation services.
```

### Egress Requirements from Kata VM (CoCo)

| Destination | Port | Purpose |
|---|---|---|
| KBS | 443 (HTTPS) | Secret retrieval (attestation) |
| Container Registry | 443 (HTTPS) | Encrypted image download |
| Attestation Service | 443 (HTTPS) | Evidence verification |
| AMD KDS (optional) | 443 (HTTPS) | SNP VCEK certificate retrieval |
| Intel PCS (optional) | 443 (HTTPS) | TDX certificate retrieval |

---

## Deployment Topologies

```{figure} ../images/page_78.png
:alt: Deployment Topologies with CoCo
:align: center
Two deployment topologies: (1) Separate clusters — dedicated confidential cluster with TEE hardware separate from regular workload clusters; (2) Single cluster with peer-pods — mixed cluster where regular pods run on nodes and confidential pods become peer-pods on cloud CVMs.
```

### Topology 1: Separate Clusters

Confidential and non-confidential workloads run on completely separate K8s clusters.

**Pros:** Clean separation, no interference  
**Cons:** Separate cluster management overhead

### Topology 2: Single Cluster with Peer-Pods

Both regular and confidential pods run in the same cluster. Confidential pods are created as peer-pods (remote cloud VMs with TEE).

**Pros:** Single cluster management, mixed workloads  
**Cons:** More complex networking

---

## Trustee Deployment Topologies

Trustee (KBS + AS + RVPS) must itself run in a trusted environment — otherwise the attestation authority is compromised.

**Option 1: Trustee in a separate trusted cluster** — workload cluster attests to an independent Trustee cluster, optionally also running in CVMs.

**Option 2: Trustee on trusted on-premises hardware** — workloads run in the cloud but trust only on-prem attestation infrastructure.

**Option 3: Third-party attestation service** — use cloud-provider or vendor-managed attestation (Intel ITA, Azure MAA, AWS Nitro). Simpler to operate but requires trusting the attestation service provider.
