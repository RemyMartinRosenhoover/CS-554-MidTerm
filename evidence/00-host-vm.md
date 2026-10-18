# 00 — Host, VM, and tool versions

Must contain:

- [ ] VM facts: Linux distribution and version, vCPU, RAM, disk, VMware Workstation networking mode (NAT or bridged) — `cat /etc/os-release`, `nproc`, `free -h`, `df -h /`
- [ ] VM address as seen from inside: `ip -4 addr` (the interface on the VMware network)
- [ ] Host side of the same network: the VMnet8 (NAT) or bridged adapter address from `ipconfig` (scrub hostname and username)
- [ ] Docker Engine and Compose versions inside the VM: `docker version`, `docker compose version`
- [ ] Kubernetes distribution and version, and a one-sentence statement of where the cluster runs relative to the host and the VM: `kubectl version`, plus `kind version` or `k3s --version` as applicable
- [ ] A first host → VM reachability check (ping or an SSH session banner), before any service exists

## Captures

TODO
