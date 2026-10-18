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
- Kubernetes: k3d 5.9.0 runs the single-node `cs554` cluster as Docker containers inside this VM. The server image is pinned to `rancher/k3s:v1.37.1-k3s1`, matching kubectl 1.37.1; do not use k3d's older default image. The application image is imported with `k3d image import`.
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

Run inside the VM from `/home/student/CS-554-MidTerm`. The cluster runs in k3d containers inside `cs554-vm`, which itself runs in VMware Workstation on the Windows host. Compose can remain running on VM port 8080.

```bash
bash scripts/vm-tls-probe.sh
k3d cluster create cs554 --image rancher/k3s:v1.37.1-k3s1 --servers 1 --agents 0
kubectl cluster-info
kubectl get nodes -o wide
kubectl version
k3d image import cs554-midterm:1.0 -c cs554
docker exec k3d-cs554-server-0 crictl images | grep cs554-midterm
```

The probe must pass before downloads. Both client and server were 1.37.1. Import uses the existing Part 2 image, not a new build or application registry; `crictl images` confirmed it on the node. The Deployment uses `imagePullPolicy: Never`, so a missing import cannot silently fall back to a registry pull. The kubeconfig generated by k3d stays outside the repository in the VM; never commit it. Run cluster creation only if `k3d cluster list` shows no existing `cs554` cluster.

### Deploy

```bash
kubectl apply --dry-run=client -f k8s/
kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/client-pod.yaml
kubectl rollout status deploy/cs554-midterm --timeout=120s
kubectl wait --for=condition=Ready pod/client --timeout=120s
kubectl get deploy,rs,pods,svc -o wide
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl describe svc cs554-midterm
```

The resources use namespace `default`. The Deployment has two replicas labeled `app=cs554-midterm,tier=web`. The ClusterIP Service selects `app=cs554-midterm`, exposes port 80, and targets named container port `http` (8080). Only the three explicitly listed manifests are applied: `service-broken.yaml` is committed for the later selector experiment and must not be applied here. Client dry-run validates it without changing the running Service.

### Access through the Service

```bash
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6; do curl -s http://cs554-midterm/; echo; done'
```

This exercises Service DNS, ClusterIP routing, and selection of ready backends. Both application Pod hostnames answered, with independent counters. It demonstrates requests reaching multiple backends, not strict round-robin ordering or a fairness guarantee.

For VM-local access, run the forwarder in one VM terminal and requests in another:

```bash
kubectl port-forward svc/cs554-midterm 18080:80
curl -fsS http://127.0.0.1:18080/
curl -fsS http://127.0.0.1:18080/
curl -fsS http://127.0.0.1:18080/
```

The capture started the forwarder in the background and stopped it afterward. All three responses came from the same Pod. Service port-forward uses the Service's selector and target port to choose a Pod, then forwards directly to that Pod through the API server; it does not exercise ClusterIP packet routing or distribute requests across replicas. Port 18080 is loopback-only inside the VM, not an exposed Windows-host endpoint. Stop the forwarder with Ctrl+C before deleting its chosen Pod.

### Two ready replicas and Pod replacement

The initial Deployment was `2/2`, both application Pods were `1/1 Running`, and the EndpointSlice contained two addresses. To reproduce replacement, first list the current names and substitute one for `<pod-to-delete>`:

```bash
kubectl get pods -l app=cs554-midterm -o wide
kubectl delete pod <pod-to-delete> --wait=false
for i in $(seq 1 10); do
    date --iso-8601=seconds
    kubectl get pods -l app=cs554-midterm -o wide
    sleep 3
done
kubectl rollout status deploy/cs554-midterm --timeout=120s
kubectl get rs
kubectl describe deploy cs554-midterm
kubectl describe rs <replicaset-name>
kubectl exec <replacement-pod> -- wget -qO- http://127.0.0.1:8080/
```

The recorded deletion was `cs554-midterm-64fccd9c5-mkspb`; replacement `cs554-midterm-64fccd9c5-2jmll` progressed from ContainerCreating to Running and ready within six seconds. The ReplicaSet returned to desired/current/ready 2 and recorded `SuccessfulCreate`. The replacement's first request counted 1. This direct request proves fresh process state, not Service routing.

The ReplicaSet controller reconciles the surviving Pods against the Deployment's desired `replicas: 2`, creating a different Pod without another apply. Compose's earlier restart command restarted the process in the same container; Kubernetes created a new named Pod automatically after deletion. Both lose the in-memory counter. Full status, events, settings, and request captures are in `evidence/02-kubernetes.md`.

### Cleanup

```bash
kubectl delete -f k8s/client-pod.yaml -f k8s/service.yaml -f k8s/deployment.yaml
kubectl get all
```

Only the default `kubernetes` Service remained after application cleanup; the k3d cluster and Compose service were not deleted. The three manifests were subsequently reapplied with the deploy commands above, and two ready replicas plus the client Pod were left running for the selector experiment. The broken Service and readiness experiment have not been applied.

## Part 4 — Controlled troubleshooting

See `evidence/03-selector-break.md` and section 4 of `docs/report.md`.

## CS 554 extension — resource settings and readiness

See `k8s/deployment.yaml`, `evidence/04-readiness-554.md`, and section 6 of `docs/report.md`.

The deployed settings are in `k8s/deployment.yaml`: CPU/memory requests of `50m`/`64Mi` and limits of `250m`/`128Mi`, yielding Burstable QoS because requests differ from limits. Requests reserve scheduling capacity; CPU limits constrain CPU time and exceeding the memory limit can cause an OOM kill. Readiness checks `/health` on named port `http`, with initial delay 2 seconds, period 5 seconds, failure threshold 2, and success threshold 1 (default timeout 1 second). Readiness governs Service traffic eligibility, not process restart; there is deliberately no liveness probe. The readiness-failure experiment is a later task.

## Report and evidence

- Report: `docs/report.md` (diagram, Compose vs Kubernetes comparison, OpenStack analysis, CS 554 extension)
- Diagram: `docs/diagram.svg`
- Evidence log: `evidence/`
- References: `docs/references.md`

## Manual setup steps

No interactive Ubuntu installation was needed; cloud-init used `DataSourceVMware [seed=guestinfo]` and completed successfully. The first import produced virtual hardware version 99, which Workstation rejected before boot. With the VM powered off, it was corrected to 21; the recipe now supplies `--maxVirtualHardwareVersion=21` to reproduce the correction.

The imported serial device was initially disconnected. It was connected using `vmrun connectNamedDevice ... serial0`; the recipe now sets `serial0.startConnected = "TRUE"`. Serial output goes to `$env:USERPROFILE\codex-work\logs\cs554-vm-serial.log`. Early first-boot messages were recovered from `/var/log/cloud-init-output.log` because the serial log did not capture that period; those messages are not serial-console evidence. For startup troubleshooting, inspect the new VM's `vmware.log`, the serial log and `cloud-init status --long` without changing host settings.

All seven in-VM TLS endpoints validated with public CA issuers before provisioning; no extra root certificate was needed. Recheck TLS on a different network before downloads. If validation fails, stop for the appropriate approved trust configuration; never disable certificate verification. No guest VM fallback route, host software install, or host configuration change was required.
