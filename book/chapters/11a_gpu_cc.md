# Confidential Computing for GPUs and Devices

The use cases that drive Confidential Computing adoption today, such as model training, inference, and confidential AI services, run on GPUs. But everything covered so far protects *CPU* memory: a CVM with an attached GPU still hands its data to a device that sits outside the TEE boundary, with model weights and training data crossing the PCIe bus and residing in GPU memory in plaintext. This chapter covers how the TEE boundary is being extended to accelerators.

---

## The Problem: The TEE Boundary Stops at the CPU

In a standard CVM with GPU passthrough:

- **GPU memory is not covered** by the CPU's memory encryption: the hypervisor and anyone with physical access can potentially inspect it
- **PCIe transfers are plaintext**: data moving between CVM memory and the GPU transits the bus unprotected
- **The GPU itself is unattested**: nothing proves the device is genuine or running unmodified firmware

For the Chapter 3 AI use cases, this is exactly where the sensitive assets live. A confidential AI deployment needs the GPU inside the trust boundary.

---

## NVIDIA Confidential Computing (Hopper and Later)

NVIDIA's H100 (Hopper) was the first GPU with a confidential computing mode; Blackwell extends it. With CC mode enabled:

- **On-GPU isolation.** Hardware firewalls block access to GPU memory from outside the GPU TEE, including from the hypervisor and other GPU contexts.
- **Encrypted transfers.** The NVIDIA driver running *inside* the CVM establishes an encrypted session with the GPU (via the SPDM protocol). DMA between the CVM and the GPU goes through encrypted bounce buffers in shared memory, so the PCIe bus and the host only see ciphertext.
- **GPU attestation.** The GPU produces its own attestation report containing measurements of its firmware (VBIOS) and configuration, signed by device keys rooted in NVIDIA's certificate authority. Verification is done against the [NVIDIA Remote Attestation Service (NRAS)](https://docs.nvidia.com/attestation/) or a local verifier.
- **Multi-GPU support.** NVLink traffic between GPUs in the same TEE can also be protected, enabling confidential multi-GPU training.

### Composite Attestation

A confidential GPU workload has *two* attesters: the CVM (CPU TEE) and the GPU. A relying party must verify both before releasing secrets: CPU evidence against AMD/Intel roots, and GPU evidence against NVIDIA's. It must also confirm the two are bound together, that is, the GPU is attached to *this* attested CVM. Attestation services are adding this composition: Trustee can delegate GPU evidence verification to NRAS, and Azure/Intel attestation services offer similar flows. In RATS terms, nothing changes conceptually; there are simply multiple pieces of Evidence for the Verifier to appraise.

### Performance

Compute that stays on the GPU runs at essentially native speed: GPU memory bandwidth and compute are unaffected. The overhead concentrates in the encrypted bounce-buffer path across PCIe, so workloads with heavy host-to-device transfer (data-loading-bound training) pay more than inference or compute-bound training that keeps data resident on the GPU.

---

## Trusted I/O: Removing the Bounce Buffers

Encrypted bounce buffers are a bridge, not the destination. The PCIe **TDISP** standard (TEE Device Interface Security Protocol) defines how an attested device can be *accepted into* a VM-based TEE and then DMA directly into the guest's private memory, with no bounce buffers and no extra copies. The CPU-side implementations are **Intel TDX Connect** and **AMD SEV-TIO**; on the device side, GPUs, NICs, and storage controllers must implement TDISP.

The flow mirrors everything this book has covered: the device presents evidence (its own measurements, signed by device keys), the guest verifies and accepts it, and the hardware then extends the TEE boundary to include the device interface. As TDISP-capable platforms and devices ship, expect the bounce-buffer model, and its overhead, to fade.

---

## Availability

| Offering | Status |
|---|---|
| Azure confidential GPU VMs (H100 + SEV-SNP, NCC-series) | GA |
| Google Cloud confidential GPU (H100 on A3) | Preview/GA per region |
| NVIDIA NRAS GPU attestation | GA |
| TDX Connect / SEV-TIO (TDISP) platforms | Emerging |

:::{note}
GPU CC modes, driver support, and attestation tooling are evolving quickly. Check NVIDIA's [confidential computing documentation](https://docs.nvidia.com/confidential-computing/) for current hardware and software requirements before planning a deployment.
:::
