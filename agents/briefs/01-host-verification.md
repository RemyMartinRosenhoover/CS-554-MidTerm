# Brief 01 — Host verification (read-only)

Target: the Windows 11 work desktop where VMware Workstation is installed.
Issued: 2026-10-17. Tracked as GitHub issue #1.

## Rules

Verify and report only. Change no settings, enable no Windows features, install nothing, reboot nothing. If a check fails or is blocked by policy, report that as the finding; do not work around it. Report each item as pass / fail / unknown with the evidence. Leave the host's hostname and username out of the report.

## Checks

1. Windows edition, version, and build (`Get-ComputerInfo`). Confirm Pro or Enterprise, not Home.
2. CPU virtualization enabled in firmware? (`systeminfo`, "Hyper-V Requirements" section; note if it instead reports that a hypervisor is already present.)
3. Hyper-V, Virtual Machine Platform, WSL2, and Core Isolation / Memory Integrity: on or off? (`Get-WindowsOptionalFeature -Online`; Windows Security > Device security.) Report only.
4. VMware Workstation: version, install path, `vmrun.exe` present, Virtual Network Editor present. If item 3 shows Hyper-V or VBS on, confirm the Workstation version runs alongside it (16 or 17 is fine).
5. VMware host adapters: IPs of VMnet8 (NAT) and VMnet1 (host-only) from `ipconfig /all`.
6. Resources: logical CPUs, total RAM, free disk on the drive where VMware stores VMs. Target VM: 2 vCPU, 4 GB RAM, 25 GB disk.
7. Existing VMs: list `.vmx` files in the VMware VM folder; note any Linux VM that could be reused.
8. Is the current user a local Administrator?
9. Tooling on the host: `git`, `gh`, `node` versions if present; `git` user.name and user.email set; `gh auth status`. Docker should NOT be on the host; say if it is.
10. Corporate constraints: proxy environment variables; can the host reach github.com and releases.ubuntu.com; any endpoint security likely to interfere with VMware NAT networking.

## Deliverable

`agents/reports/01-host-verification.md`: a short table (item, result, evidence), followed by any notes. Open it as a pull request from branch `codex/1-host-verification`.
