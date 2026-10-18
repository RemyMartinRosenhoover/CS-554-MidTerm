# CS 454/554 Midterm Mini-Project — One Service, Two Deployment Environments

> **Work in progress.** Parts 1 and 2 are complete; Parts 3–5 and the CS 554 extension are being added. Sections marked `TODO` are not yet done.

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

- Host: Windows 11 with VMware Workstation 17.6.1 and OVF Tool 4.6.3; VM hardware version pinned to 21.
- VM: Ubuntu Server 24.04.5 LTS, `cs554-vm`, 2 vCPUs, 4096 MiB RAM, 25 GiB virtual disk (root filesystem approximately 24 GiB), stored at `C:\VMs\cs554-vm`.
- Network: VMware NAT (VMnet8), `192.168.197.0/24`; host adapter `192.168.197.1`, guest `192.168.197.134` at verification time. DHCP may change the guest address; host access is direct without port forwarding.
- Docker Engine 29.1.3 and Docker Compose 2.40.3 run inside the VM; not on the Windows host for this project.
- Kubernetes tooling: kubectl 1.37.1, k3d 5.9.0 (reported default k3s `v1.35.5-k3s1`). The cluster will run inside this VM, as Docker containers; no cluster is created in the VM-build step. Image loading will use `k3d image import`. Client/server version compatibility must be checked when choosing the cluster version.
- Tools used: Windows PowerShell 5.1, Windows OpenSSH client, VMware `ovftool`, `vmware-vdiskmanager` and `vmrun`; guest cloud-init, OpenSSH, APT, OpenSSL, Docker, Compose, kubectl and k3d.

## Prerequisites

Host: Windows 11, Windows PowerShell 5.1, Windows OpenSSH client (`ssh`, `scp`, `ssh-keygen`), Windows `curl.exe`, and VMware Workstation 17.6.1 with `ovftool`, `vmrun`, and `vmware-vdiskmanager`. The recipe pins imported virtual hardware to version 21 because OVF Tool can otherwise emit an unsupported hardware version.

Guest: the Ubuntu noble server cloud OVA, verified against its published SHA256SUMS. Cloud-init installs `docker.io`, `docker-compose-v2`, `curl`, `ca-certificates`, `jq`, `git`, and `openssl`; provisioning installs `gnupg`, kubectl from the course's Kubernetes v1.37 APT repository, and k3d from its upstream installer. Actual versions are recorded above and in `evidence/00-host-vm.md`. Guest `student` authenticates with the project SSH key and has passwordless sudo. No password is configured.

From the repository root, use these separate PowerShell phases. Keys, downloads, generated cloud-init, known-hosts and logs stay in a working folder outside the repository (the scripts default to `$env:USERPROFILE\codex-work`); never commit them.

```powershell
$work = Join-Path $env:USERPROFILE 'codex-work'
$keys = Join-Path $work 'keys'
New-Item -ItemType Directory -Path $keys -Force | Out-Null
$key = Join-Path $keys 'cs554_vm'
# Run only if the key does not already exist. Empty passphrase: press Enter twice.
ssh-keygen -t ed25519 -f $key -C cs554-vm
powershell.exe -NoLogo -NoProfile -File scripts\vm-create.ps1 -Phase Download
powershell.exe -NoLogo -NoProfile -File scripts\vm-create.ps1 -Phase Import
powershell.exe -NoLogo -NoProfile -File scripts\vm-create.ps1 -Phase Grow
powershell.exe -NoLogo -NoProfile -File scripts\vm-create.ps1 -Phase Configure
powershell.exe -NoLogo -NoProfile -File scripts\vm-create.ps1 -Phase Start
$ip = Get-Content -LiteralPath (Join-Path $work 'logs\cs554-vm-ip.txt')
$knownHosts = Join-Path $keys 'known_hosts'
ssh -i $key -o StrictHostKeyChecking=accept-new -o "UserKnownHostsFile=$knownHosts" "student@$ip" 'cloud-init status --wait'
scp -i $key -o "UserKnownHostsFile=$knownHosts" scripts\vm-tls-probe.sh scripts\vm-provision.sh "student@${ip}:/home/student/"
ssh -i $key -o "UserKnownHostsFile=$knownHosts" "student@$ip" 'bash vm-tls-probe.sh'
# Run provisioning only after the TLS probe passes. Do not bypass validation.
ssh -i $key -o "UserKnownHostsFile=$knownHosts" "student@$ip" 'sudo bash vm-provision.sh'
Test-NetConnection $ip -Port 22
```

The import phase refuses to overwrite an existing VM. Do not rerun creation/configuration phases against a running VM. This step installs tools only; no container image is pulled and no service or Kubernetes cluster is deployed.

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

Run inside the VM, from the public checkout at `/home/student/CS-554-MidTerm`. The image is built from the unchanged `app/Dockerfile`; Kubernetes will reuse `cs554-midterm:1.0`.

```bash
cd /home/student/CS-554-MidTerm
docker build -t cs554-midterm:1.0 app
docker image ls cs554-midterm
cd compose
cp .env.example .env
docker compose config
docker compose up -d
docker compose up -d --wait --wait-timeout 90
docker compose ps
docker compose logs
```

The committed `.env.example` supplies `PORT=8080`, `HOST_PORT=8080`, `SERVICE_NAME=cs554-compose`, and `MESSAGE=Hello from Compose inside the VM`. The generated `.env` is ignored and must not be committed. Compose publishes VM port 8080 to container port 8080, uses `restart: unless-stopped`, and checks `/health` every 10 seconds with a 3-second timeout and 3 retries. A failed health check marks the container unhealthy; it does not itself restart the process. The observed service was healthy.

### Access from inside the VM

```bash
curl -s http://localhost:8080/
curl -s http://localhost:8080/
curl -s http://localhost:8080/
curl -i http://localhost:8080/health
```

The first three responses reported counts 1, 2, and 3 with service `cs554-compose`; `/health` returned HTTP 200 without changing the counter. JSON responses have no trailing newline, so consecutive responses run together in the raw capture.

### Access from the host (networking mode and port forwarding)

VMware NAT on VMnet8: the Windows host reaches the guest directly at `192.168.197.134`, without port forwarding. Docker's published port connects VM port 8080 to the application in the container. The guest address is DHCP-assigned; confirm it before reusing these commands.

```powershell
curl.exe -s http://192.168.197.134:8080/
curl.exe -i http://192.168.197.134:8080/health
```

The host request reported count 4 from the same container, and the health request returned HTTP 200.

### Restart and the request counter

From the VM checkout's `compose/` directory:

```bash
curl -s http://localhost:8080/
docker compose restart
docker compose up -d --wait --wait-timeout 90
docker compose ps
curl -s http://localhost:8080/
docker compose logs --since 2m
```

The count was 5 before restart and 1 afterward. The container hostname stayed the same, but its application process restarted and lost its in-memory count. Logs show `Received SIGTERM; stopping.` followed by a new `Listening on port 8080` line. Automatic and manual `/health` requests appear in the logs but do not increment the counter.

### Cleanup

```bash
docker compose down
docker compose ps
```

This removed the service container and Compose network; `ps` showed no service. The local image and ignored `.env` remain. For the walkthrough, the service was subsequently brought back up and left healthy:

```bash
docker compose up -d
docker compose up -d --wait --wait-timeout 90
docker compose ps
```

The complete build, configuration, requests, logs, restart, cleanup, and final status captures are in `evidence/01-compose.md`.

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

No interactive Ubuntu installation was needed; cloud-init used `DataSourceVMware [seed=guestinfo]` and completed successfully. The first import produced virtual hardware version 99, which Workstation rejected before boot. With the VM powered off, it was corrected to 21; the recipe now supplies `--maxVirtualHardwareVersion=21` to reproduce the correction.

The imported serial device was initially disconnected. It was connected using `vmrun connectNamedDevice ... serial0`; the recipe now sets `serial0.startConnected = "TRUE"`. Serial output goes to `$env:USERPROFILE\codex-work\logs\cs554-vm-serial.log`. Early first-boot messages were recovered from `/var/log/cloud-init-output.log` because the serial log did not capture that period; those messages are not serial-console evidence. For startup troubleshooting, inspect the new VM's `vmware.log`, the serial log and `cloud-init status --long` without changing host settings.

All seven in-VM TLS endpoints validated with public CA issuers before provisioning; no extra root certificate was needed. Recheck TLS on a different network before downloads. If validation fails, stop for the appropriate approved trust configuration; never disable certificate verification. No guest VM fallback route, host software install, or host configuration change was required.
