# The Trust Boundary Problem

With the building blocks in place — Root of Trust, measured boot, and TEEs — we can now ask the critical question: **do they actually protect tenants from the infrastructure they run on?**

## Trust Boundary in Virtualisation


In traditional virtualisation, the provider fully controls everything below the guest VM — the hypervisor, host OS, device firmware, and hardware. This means the provider can:

- Inspect guest memory
- Modify guest execution
- Inject code via the hypervisor

The tenant trust boundary sits *above* the hypervisor. Everything below it belongs to the provider.

```{figure} ../images/page_19.png
:alt: Trust Boundary in Virtualisation
:align: center
```

## The Challenge

**Secure Boot** does not protect the tenant from the provider — the provider signs and defines all trusted components (Firmware, Bootloader, Host OS, Hypervisor).

**Measured/Trusted Boot** only proves the machine is running the *provider's* approved software — not necessarily what the *tenant* wants.

The tenant must ultimately "trust the provider" — the hypervisor can technically map guest memory, read plaintext pages, modify registers, and change guest files.

## Enter Confidential Computing

Confidential Computing resolves this by introducing **hardware-enforced TEE boundaries**:

- VM memory is encrypted by the CPU — the hypervisor sees only ciphertext
- The TCB is reduced — the hypervisor and host OS are no longer trusted components
- Measured boot is rooted in hardware (AMD SP, Intel TDX Module) — not in provider-controlled firmware
- **Remote attestation** lets the tenant independently verify the boot measurements, without relying on the provider

The tenant trust boundary now extends *down to the hardware*, bypassing the hypervisor entirely.

```{figure} ../images/page_21.png
:alt: Enter Confidential Computing
:align: center
```
