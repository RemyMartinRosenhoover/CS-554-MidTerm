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
6. **Scrub the host's hostname and username** from anything committed. The VM's hostname and container hostnames are fine and are part of the evidence.
7. **Evidence is real.** Never fabricate, reorder, or tidy terminal output beyond the scrubbing above. If a capture is messy, keep it and add a one-line note explaining it.

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

Filled in after host verification (issue #1). Until then, assume nothing about the host.

- Host: Windows 11 (Pro or Enterprise), VMware Workstation — version TBD
- VM: Ubuntu Server 24.04 LTS, VMware NAT networking; Docker Engine + Compose plugin inside it
- Kubernetes: k3d inside the same VM (matches the course exercises); image loaded with `k3d image import`
- Image: `cs554-midterm:1.0`, built from `app/Dockerfile`; configuration via `PORT`, `SERVICE_NAME`, `MESSAGE`
- Corporate network hazard (from the course's RESTRICTED-NETWORKS appendix): a TLS-intercepting proxy on the work network breaks apt, Docker pulls, and k3d node image pulls with `x509: certificate signed by unknown authority`. Issue #1 checks for it; the VM build issue handles it if present.
