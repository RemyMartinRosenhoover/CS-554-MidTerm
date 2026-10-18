# AGENTS.md — standing rules for AI coding agents in this repository

This repository is a graded course submission (CS 454/554 midterm mini-project).
The assignment text is in `agents/assignment.md`; read it before starting any task.
Everything under `agents/` is process tooling and is **not** part of the submission.

## Non-negotiable rules

1. **Never commit** container image archives (`*.tar`, `*.tgz`), VM images or exports (`*.vmdk`, `*.vdi`, `*.qcow2`, `*.ova`, `*.ovf`, `*.iso`), `node_modules/`, `.env` files, private keys, kubeconfigs, passwords, tokens, or cloud credentials. CI fails the build if any of these are tracked. The repository carries the recipe (Dockerfile, lockfile, manifests), never the baked artifact.
2. **Never weaken a test, check, probe, lint rule, or CI step to make it pass.** When something fails: stop, capture the output verbatim, and report it in the issue or PR with your best root-cause analysis. Say explicitly whether you believe the check is wrong or the code is wrong. A check is changed only with a stated reason and approval recorded in the issue.
3. **Do not touch the instructor's starter repository.** Copy the starter into `app/`. Never open a pull request or push against the course repository.
4. **Keep the project small.** No extra endpoints, frontend, database, authentication, or shared storage for the request counter. The only permitted application change beyond configuration is a clearly documented application-level readiness toggle for the CS 554 experiment, and only when an issue asks for it.
5. **Do not change the host's security posture.** The host is a managed work computer. Do not enable or disable Windows features, change Windows Security or Core Isolation settings, modify firewall rules, install a hypervisor, or reboot unless the issue says so explicitly.
6. **This repository is public: nothing about the managed host beyond what reproducing the project requires.** Never commit the host's hostname or username, the employer's name or any organization-specific path (OneDrive, mapped drives, internal domains), the names or state of security, endpoint-protection, or VPN products, security-configuration details (virtualization-based security, code integrity, credential protections, privilege or group membership), or the raw output of host inventory commands. What may appear: Windows edition, VMware Workstation version, the VMware virtual-network subnets, CPU/RAM/disk headroom, and tool versions. Full host reports stay off the public repo: keep them in the host-side working folder and hand them to the reviewer outside GitHub. The VM's hostname and container hostnames are fine and are part of the evidence.
7. **Evidence is real.** Never fabricate, reorder, or tidy terminal output beyond the scrubbing above. If a capture is messy, keep it and add a one-line note explaining it.
8. **Host-side working files live in one folder.** Any helper script, log, or scratch file an agent writes on the host goes under `%USERPROFILE%\codex-work\` (create it) and nowhere else: never under Start Menu, AppData, Program Files, OneDrive, or system directories. List what was left there in the pull request, and remove it when the issue closes.

## How work arrives and leaves

- Tasks are GitHub Issues labeled `codex`. Work exactly one issue at a time, in full, in the order they are numbered.
- Each issue lists acceptance criteria and the evidence files it must produce. An issue is done only when every criterion is met and CI is green.
- Branch naming: `codex/<issue-number>-<short-slug>`. Open a pull request that references the issue (`Closes #N`). Do not merge your own pull request; the reviewer merges.
- The pull request description must contain: what was done; what was verified and the exact commands used; anything that failed, was skipped, or needs a human, with the reason.
- If an issue is ambiguous or blocked, comment on the issue and stop. Do not guess on anything that would take more than a minute to redo.

## Where things go

| Path | Contents |
|---|---|
| `app/` | starter service, its tests, `Dockerfile` |
| `compose/` | `compose.yaml`, `.env.example` |
| `k8s/` | `deployment.yaml`, `service.yaml`, `service-broken.yaml`, `client-pod.yaml` |
| `docs/` | `report.md`, `diagram.svg`, `references.md` |
| `evidence/` | `NN-topic.md` files with labeled fenced blocks; `screenshots/` |
| `scripts/` | small, idempotent shell scripts; no secrets, no absolute host paths |
| `agents/` | briefs, reports, reviews; referenced from the README by one "graders can ignore" line only |

## Evidence format

Evidence files are Markdown. Each observation gets a heading, one sentence of context (where it ran: host, VM, or cluster; date and time), then a fenced block showing the command on its own line followed by its unedited output:

```text
$ kubectl get pods -o wide
NAME                      READY   STATUS    RESTARTS   AGE   IP           NODE
...
```

Screenshots go in `evidence/screenshots/` with descriptive names, for example `03-selector-broken-curl-timeout.png`.

## Environment facts

From host verification (issue #1), limited to what rule 6 allows:

- Host: Windows 11 Enterprise with VMware Workstation 17.6.1. Hyper-V is present, so Workstation runs on the Windows Hypervisor Platform; nested virtualization is unavailable in that mode and is not needed (Docker and k3d are containers inside the VM). Plenty of headroom: 32 logical CPUs, 64 GiB RAM, hundreds of GiB free on C:.
- VMware virtual networks on the host: VMnet8 (NAT) 192.168.197.0/24 with the host at .1; VMnet1 (host-only) 192.168.2.0/24 with the host at .1. A VM on NAT gets a 192.168.197.x address from VMware's DHCP, and the host can reach it directly on that address, so host-to-VM access needs no port forwarding.
- An older Ubuntu VM (2 vCPU, 4 GiB) exists under the user's synced Documents folder. New VMs go under a non-synced folder such as `C:\VMs`; VM disks must not live in a cloud-synced folder.
- Host tooling: git, gh (authenticated), Node 24. Git `user.name`/`user.email` are not set on the host; commits use the GitHub noreply address via per-command options until an issue sets them. Docker Desktop exists on the host but is not used for this project; everything runs inside the VM.
- Network: no proxy variables and no WinHTTP proxy; github.com and releases.ubuntu.com reachable. Whether TLS interception is present (check 11) is still unverified.
- VM: Ubuntu Server 24.04 LTS, VMware NAT networking; Docker Engine + Compose plugin inside it
- Kubernetes: k3d inside the same VM (matches the course exercises); image loaded with `k3d image import`
- Image: `cs554-midterm:1.0`, built from `app/Dockerfile`; configuration via `PORT`, `SERVICE_NAME`, `MESSAGE`
- Corporate network hazard (from the course's RESTRICTED-NETWORKS appendix): a TLS-intercepting proxy on the work network breaks apt, Docker pulls, and k3d node image pulls with `x509: certificate signed by unknown authority`. Issue #1 checks for it; the VM build issue handles it if present.
