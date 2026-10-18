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

## Environment summary

- Host: Windows 11 workstation running VMware Workstation (TODO: version)
- VM: Ubuntu Server 24.04 LTS in VMware Workstation, NAT networking (TODO: vCPU, RAM, disk, addresses)
- Docker Engine and Docker Compose: both run inside the VM (TODO: versions)
- Kubernetes: k3d (k3s nodes running as Docker containers) inside the same VM, the same distribution used in the course exercises; the image reaches the cluster with `k3d image import` (TODO: versions)
- Tools used: TODO

## Prerequisites

TODO — host-side tools, VM-side packages, and the versions they were tested with.

## Part 1 — Build the image

The service in `app/` is the course starter (`cs454-midterm-starter`, copied from the course exercises repository at commit `8c572c1`), unchanged. It is dependency-free and needs Node.js 22 or newer.

```bash
cd app && npm test          # unit test: configuration, counter, health, fresh instance
docker build -t cs554-midterm:1.0 app
```

- Configuration is read from environment variables at run time: `PORT` (default `8080`), `SERVICE_NAME` (default `cs454-midterm`), `MESSAGE` (default `Hello from the mini-project!`). The image bakes none of them in; Compose and Kubernetes supply them.
- `GET /` returns `{service, message, hostname, requestCount}`; `GET /health` returns `{"status":"ok"}` with HTTP 200; anything else is 404.
- The counter counts successful `GET /` requests only (health checks do not touch it), lives in the process's memory, and starts at zero for every new process. A restarted container or a replacement Pod therefore begins again at 1.
- Every request is logged to standard output as one JSON line (`{"method","path","status"}`), and startup logs `Listening on port <PORT>`, so `docker compose logs` and `kubectl logs` show both.
- The image runs as the unprivileged `node` user, starts Node as PID 1 (exec-form `CMD`), and the service handles `SIGTERM` with a graceful shutdown.

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
