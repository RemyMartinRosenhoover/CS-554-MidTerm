# CS 454/554 Midterm Mini-Project — One Service, Two Deployment Environments

> **Status: scaffold.** Sections marked `TODO` are completed as each part of the project lands.

One small Node.js HTTP service, deployed two ways: Docker Compose inside a Linux virtual machine, and a local Kubernetes cluster running two replicas. The project records how each environment manages the service, investigates a deliberately broken Service selector, runs a readiness experiment (CS 554), and explains how the same workload would be deployed on OpenStack.

**Student:** TODO (name, course section)
**Walkthrough video (3–5 min):** TODO — link

## Repository layout

| Path | What it is |
|---|---|
| `app/` | The service (from the course starter), its tests, and the `Dockerfile` (Part 1) |
| `compose/` | Docker Compose configuration used inside the VM (Part 2) |
| `k8s/` | Kubernetes manifests: Deployment, Service, the deliberately broken Service, in-cluster test client (Parts 3–4, CS 554) |
| `docs/` | Technical report, deployment diagram, references |
| `evidence/` | Labeled terminal output and screenshots for every required observation |
| `scripts/` | Small helper scripts (VM setup, image loading) |
| `agents/` | **Not part of the submission.** Working notes used to coordinate AI coding assistants during the project. Graders can ignore this folder. |

## Environment summary

- Host: Windows 11 workstation running VMware Workstation (TODO: version)
- VM: TODO (distribution and version, vCPU, RAM, disk, VMware networking mode)
- Docker Engine and Docker Compose: TODO (versions; both run inside the VM)
- Kubernetes: TODO (distribution and version; where it runs relative to the host and the VM)
- Tools used: TODO

## Prerequisites

TODO — host-side tools, VM-side packages, and the versions they were tested with.

## Part 1 — Build the image

TODO — build command, image name and tag, how the counter behaves, where request/startup logs go.

## Part 2 — Docker Compose inside the VM

### Start, status, and logs
TODO

### Access from inside the VM
TODO

### Access from the host (networking mode and port forwarding)
TODO — VM networking mode, addresses, and any port forwarding, exactly as used.

### Restart and the request counter
TODO

### Cleanup
TODO

## Part 3 — Kubernetes

### Making the image available to the cluster
TODO — the exact image-loading command and how to confirm the cluster has it.

### Deploy
TODO

### Access through the Service
TODO — the access method and what it does and does not demonstrate.

### Two ready replicas and Pod replacement
TODO

### Cleanup
TODO

## Part 4 — Controlled troubleshooting

See `evidence/03-selector-break.md` and section 4 of `docs/report.md`.

## CS 554 extension — resource settings and readiness

See `k8s/deployment.yaml`, `evidence/04-readiness-554.md`, and section 6 of `docs/report.md`.

## Report and evidence

- Report: `docs/report.md` (diagram, Compose vs Kubernetes comparison, OpenStack analysis, CS 554 extension)
- Diagram: `docs/diagram.svg`
- Evidence log: `evidence/`
- References: `docs/references.md`

## Manual setup steps

TODO — anything that could not be scripted, such as creating the VM in VMware Workstation.
