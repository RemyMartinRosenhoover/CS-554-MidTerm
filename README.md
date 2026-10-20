# CS 454/554 Midterm Mini-Project — One Service, Two Deployment Environments

> **Complete except the walkthrough video link.**

One small Node.js HTTP service, deployed two ways: Docker Compose inside a Linux virtual machine, and a local Kubernetes cluster running two replicas. The project records how each environment manages the service, investigates a deliberately broken Service selector, runs a readiness experiment (CS 554), and explains how the same workload would be deployed on OpenStack.

**Course:** CS 454/554 — Introduction to Cloud Computing, Fall 2026
**Walkthrough video (3–5 min):** TODO — link
**Demonstration guide:** [Walkthrough Demonstration Guide](docs/report/recording-runbook.pdf) (preconditions, the command entered at each step, the result expected, verification, and restoration; source [`docs/report/recording-runbook.tex`](docs/report/recording-runbook.tex)), with the rehearsed [shot list](docs/video-shotlist.md). It is also a step-by-step way to reproduce the demonstration on an environment built from this README.

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
- Application image: `cs554-midterm:1.1` runs in both Compose and Kubernetes. Version `1.0` in earlier captures records the pre-readiness-toggle experiments; those captures remain unchanged.
- Kubernetes: k3d 5.9.0 runs the single-node `cs554` cluster as Docker containers inside this VM. The server image is pinned to `rancher/k3s:v1.37.1-k3s1`, matching kubectl 1.37.1; do not use k3d's older default image. The application image is imported with `k3d image import`.
- Tools used: Windows PowerShell 5.1, Windows OpenSSH client, VMware `ovftool`, `vmware-vdiskmanager` and `vmrun`; guest cloud-init, OpenSSH, APT, OpenSSL, Docker, Compose, kubectl and k3d.

## Prerequisites

Host: Windows 11, Windows PowerShell 5.1, Windows OpenSSH client (`ssh`, `scp`, `ssh-keygen`), Windows `curl.exe`, and VMware Workstation 17.6.1 with `ovftool`, `vmrun`, and `vmware-vdiskmanager`. The recipe pins imported virtual hardware to version 21 because OVF Tool can otherwise emit an unsupported hardware version.

Guest: the Ubuntu noble server cloud OVA, verified against its published SHA256SUMS. Cloud-init installs `docker.io`, `docker-compose-v2`, `curl`, `ca-certificates`, `jq`, `git`, and `openssl`; provisioning installs `gnupg`, kubectl from the course's Kubernetes v1.37 APT repository, and k3d from its upstream installer. Actual versions are recorded above and in `evidence/00-host-vm.md`. Guest `student` authenticates with the project SSH key and has passwordless sudo. No password is configured.

If another cluster or Compose project already exists on the VM, use distinct names and a separate kubeconfig; the recipes assume a VM dedicated to this project.

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

The import phase refuses to overwrite an existing VM. Do not rerun creation/configuration phases against a running VM. This step installs tools only; no container image is pulled and no service or Kubernetes cluster is deployed. The scripts are one reproducible way to build the VM; any Ubuntu 24.04 VM with Docker Engine, the Compose plugin, kubectl, and k3d installed, reachable from the host over SSH, works for everything that follows.

Inside the VM, clone into the home directory:

```bash
cd ~
git clone https://github.com/RemyMartinRosenhoover/CS-554-MidTerm.git
cd CS-554-MidTerm
```

Later Bash commands run from this checkout root, `~/CS-554-MidTerm` (`/home/student/CS-554-MidTerm` in the recorded run), unless a block changes directory. A new terminal or SSH session starts in the home directory, so the first block of each part begins with `cd ~/CS-554-MidTerm`.

## Part 1 — Build the image

The TLS probe must pass before the test or build command: the test container pulls `node:22-alpine` on a cold VM. Do not bypass certificate validation.

```bash
cd ~/CS-554-MidTerm
bash scripts/vm-tls-probe.sh
```

The service in `app/` is the course starter (`cs454-midterm-starter`, copied from the course exercises repository at commit `8c572c1`), with only an additive `/health` readiness-file toggle for the CS 554 experiment. It is dependency-free and needs Node.js 22 or newer; the Dockerfile remains unchanged.

```bash
# From the checkout root: configuration, counter, health, and readiness tests.
docker run --rm -v "$PWD/app:/app:ro" -w /app node:22-alpine npm test
docker build -t cs554-midterm:1.1 app
```

Node/npm need not be installed in the VM; the test container provides Node 22. Expected summary: 2 tests, 2 pass, 0 fail. The suite requires Node 22 or newer (`engines` in `app/package.json`); on a host with an older Node the first test fails, so run it in the container as shown.

- Configuration is read from environment variables at run time: `PORT` (default `8080`), `SERVICE_NAME` (default `cs454-midterm`), `MESSAGE` (default `Hello from the mini-project!`). The image bakes none of them in; Compose and Kubernetes supply them.
- `GET /` returns `{service, message, hostname, requestCount}`; `GET /health` normally returns `{"status":"ok"}` with HTTP 200; anything else is 404. With `READINESS_FILE` set, the missing-file case instead returns HTTP 503 and `{"status":"not-ready"}`.
- The counter counts successful `GET /` requests only (health checks do not touch it), lives in the process's memory, and starts at zero for every new process. A restarted container or a replacement Pod therefore begins again at 1.
- Every request is logged to standard output as one JSON line (`{"method","path","status"}`), and startup logs `Listening on port <PORT>`, so `docker compose logs` and `kubectl logs` show both.
- The image runs as the unprivileged `node` user, starts Node as PID 1 (exec-form `CMD`), and the service handles `SIGTERM` with a graceful shutdown.

`READINESS_FILE` is optional and checked only by the existing `/health` handler. When unset, behavior is unchanged, including in Compose. Kubernetes sets it to `/tmp/ready`; its container-local file exists after the `postStart` hook runs. Removing the file in one Pod changes only that Pod's health response, not `GET /`, the counter, logging, shutdown, or its running process. Recreating it restores readiness. One added test verifies the 503/200 toggle and uninterrupted counter; existing tests are unchanged.

## Part 2 — Docker Compose inside the VM

### Start, status, and logs

Run inside the VM, from the public checkout root. The image is built from the unchanged `app/Dockerfile`; Kubernetes uses the same `cs554-midterm:1.1`. The earlier Part 2 capture used `1.0`; `evidence/04-readiness-554.md` records the upgrade and successful Compose requests with `READINESS_FILE` unset.

```bash
cd ~/CS-554-MidTerm
docker build -t cs554-midterm:1.1 app
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

VMware NAT on VMnet8: the Windows host reaches the guest directly, without port forwarding. Docker's published port connects VM port 8080 to the application in the container. `$ip` is your VM's address, written by the Start phase; the recorded run's guest was `192.168.197.134`.

```powershell
$ip = (Get-Content -LiteralPath (Join-Path $env:USERPROFILE 'codex-work\logs\cs554-vm-ip.txt') -Raw).Trim()
curl.exe -s "http://${ip}:8080/"
curl.exe -i "http://${ip}:8080/health"
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

This removed the service container and Compose network; `ps` showed no service. The local image and ignored `.env` remain. For the walkthrough, the service was subsequently brought back up and left healthy.

**Optional: retain for the walkthrough; skip for final teardown.** The CS 554 preparation restarts Compose in any case.

```bash
docker compose up -d
docker compose up -d --wait --wait-timeout 90
docker compose ps
```

The complete build, configuration, requests, logs, restart, cleanup, and final status captures are in `evidence/01-compose.md`.

## Part 3 — Kubernetes

### Making the image available to the cluster

Run inside the VM from the checkout root. The cluster runs in k3d containers inside `cs554-vm`, which itself runs in VMware Workstation on the Windows host. Compose can remain running on VM port 8080.

```bash
cd ~/CS-554-MidTerm
bash scripts/vm-tls-probe.sh
k3d cluster create cs554 --image rancher/k3s:v1.37.1-k3s1 --servers 1 --agents 0
kubectl cluster-info
kubectl get nodes -o wide
kubectl version
k3d image import cs554-midterm:1.1 -c cs554
docker exec k3d-cs554-server-0 crictl images | grep cs554-midterm
```

The probe must pass before downloads. Both client and server were 1.37.1. Import uses the same image as Compose, without an application registry; `crictl images` confirmed it on the node. Part 3's original `1.0` captures are historical; the readiness experiment built and imported `1.1` into the same cluster. The Deployment uses `imagePullPolicy: Never`, so a missing import cannot silently fall back to a registry pull. The kubeconfig generated by k3d stays outside the repository in the VM; never commit it. Run cluster creation only if `k3d cluster list` shows no existing `cs554` cluster.

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

The resources use namespace `default`. The Deployment has two replicas labeled `app=cs554-midterm,tier=web`. The ClusterIP Service selects `app=cs554-midterm`, exposes port 80, and targets named container port `http` (8080). Only the three explicitly listed manifests are applied: `service-broken.yaml` is reserved for the controlled selector experiment in Part 4 and must not be applied during normal deployment. Client dry-run validates it without changing the running Service.

### Access through the Service

```bash
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6; do curl -s http://cs554-midterm/; echo; done'
```

This is a short random sample, not a distribution guarantee; one hostname in a short sample, especially right after a change, is not a failure.

This exercises Service DNS, ClusterIP routing, and selection of ready backends. Both application Pod hostnames answered, with independent counters. It demonstrates requests reaching multiple backends, not strict round-robin ordering or a fairness guarantee.

For VM-local access, run the forwarder in one VM terminal and requests in another:

If you background the forwarder instead (`kubectl port-forward svc/cs554-midterm 18080:80 > "$HOME/cs554-forward.log" 2>&1 & forward_pid=$!`), wait until the log shows `Forwarding from 127.0.0.1:18080` before requesting, and stop it with `kill "$forward_pid"`.

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

Only the default `kubernetes` Service remained after application cleanup; the k3d cluster and Compose service were not deleted.

**Required to continue to Part 4 or the CS 554 section; skip only when going straight to Full teardown.** Reapply the three manifests with the deploy commands above and wait for readiness. They were subsequently reapplied in the recorded run. The selector and readiness experiments are complete and all temporary changes were restored; the correct Service, two ready replicas, and client Pod remain running.

## Part 4 — Controlled troubleshooting

Run this controlled experiment inside the existing VM/cluster from the repository root. It changes only the Service selector; do not edit the Deployment or restart Pods.

### Baseline and selector change

```bash
cd ~/CS-554-MidTerm
kubectl get pods -l app=cs554-midterm --show-labels
kubectl get svc cs554-midterm -o yaml | sed -n '/^spec:/,$p'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl describe svc cs554-midterm | grep -E 'Selector|Endpoints'
kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/
```

Verify a fresh `kubectl port-forward svc/cs554-midterm 18080:80` also serves `curl -sS --max-time 5 http://127.0.0.1:18080/`, then stop that forwarder before changing the selector. If backgrounding it, wait for the log's Forwarding line and stop it as in Part 3. The baseline had two ready endpoints and both paths succeeded.

```bash
diff -u k8s/service.yaml k8s/service-broken.yaml
# diff exit 1 is expected: only the app selector differs.
date -u +%Y-%m-%dT%H:%M:%S.%NZ > "$HOME/cs554-issue5-failure-start.txt"
kubectl apply -f k8s/service-broken.yaml
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector}'
```

The timestamp is taken after the baseline requests and immediately before the broken apply, so a baseline request in the same second does not land in the failure window.

### Failure and diagnosis

```bash
for i in 1 2 3; do
    kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/
    echo "exit=$?"
done
kubectl port-forward --pod-running-timeout=5s svc/cs554-midterm 18080:80 > "$HOME/cs554-issue5-broken-forward.log" 2>&1 &
forward_pid=$!
sleep 6
curl -sS --max-time 5 http://127.0.0.1:18080/
echo "curl exit=$?"
wait "$forward_pid"
echo "port-forward exit=$?"
cat "$HOME/cs554-issue5-broken-forward.log"
```

The fresh forwarder terminated with exit 1 and `error: timed out waiting for the condition`; both client paths failed with curl exit 7. The in-cluster request depends on Service DNS and ClusterIP routing. Port-forward must select a matching Pod anew; an old session would remain pinned and could hide the broken selector. No forwarder remains running after these captures.

If the first of the three requests still succeeds, the node's rules had not yet caught up with the emptied EndpointSlice; the following requests fail.

```bash
kubectl get pods -l app=cs554-midterm
kubectl get pods --show-labels
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector}'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json
kubectl describe svc cs554-midterm | grep Endpoints
kubectl get deploy cs554-midterm
kubectl logs deploy/cs554-midterm --since=2m
failure_start=$(cat "$HOME/cs554-issue5-failure-start.txt")
kubectl logs -l app=cs554-midterm --since-time="$failure_start" --timestamps --prefix --tail=-1
```

Pods stayed `1/1 Running`, zero restarts, with `app=cs554-midterm`; the selector was `app=cs554-midterm-typo`. The EndpointSlice remained but its endpoint list was `null`, representing zero endpoints; wide output showed `<unset>`, and this kubectl version printed a blank `Endpoints:` value. Both Pods' exact failure-window logs contained only health checks, with zero `GET /` lines. The Deployment UID, generation, and spec were unchanged (the optional continuity snapshots in the CS 554 section can be taken before and after this experiment as well).

The mismatch made the EndpointSlice controller select no backends, leaving the Service with its DNS name and ClusterIP but nowhere to route traffic. Pod health alone cannot establish Service reachability: the application can answer its own readiness probe while an unrelated selector excludes it. Diagnose the selector, Pod labels, and EndpointSlices together rather than stopping at healthy Pod status.

### Restore and verify

```bash
kubectl apply -f k8s/service.yaml
for attempt in $(seq 1 20); do
    count=$(kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq '[.items[].endpoints[]? | select(.conditions.ready == true)] | length')
    if test "$count" -eq 2; then break; fi
    sleep 1
done
test "$count" -eq 2 || { echo 'Two ready endpoints did not return'; exit 1; }
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector}'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl describe svc cs554-midterm | grep -E 'Selector|Endpoints'
recovered=
for attempt in $(seq 1 20); do
    if kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/; then recovered=$attempt; break; fi
    sleep 1
done
echo "recovered on attempt ${recovered:-none}"
kubectl get pods -l app=cs554-midterm --show-labels
```

The first in-cluster request after the restore can still fail for a second or so: the EndpointSlice is updated as soon as the selector matches again, but kube-proxy rewrites the node's forwarding rules asynchronously, so a successful request, not a populated EndpointSlice, is the recovery criterion. The recorded run recovered on the first attempt; scripted rehearsals needed one or two attempts.

Wait for two ready endpoints, then start a fresh `kubectl port-forward svc/cs554-midterm 18080:80` and retry the VM-local curl; stop it afterward. If backgrounding it, wait for the log's Forwarding line and stop it as in Part 3. Both paths recovered when the selector returned to `app=cs554-midterm`. The same Pod names, UIDs, labels, and zero restart counts were verified before and after; only the Service needed correction. The correct Service, two ready replicas, client Pod, and Compose service remain running. Complete raw baseline/change/failure/diagnosis/recovery captures are in `evidence/03-selector-break.md`; section 4 of [the LaTeX report](docs/report/main.tex) discusses the experiment.

## CS 554 extension — resource settings and readiness

See `k8s/deployment.yaml`, `evidence/04-readiness-554.md`, and section 6 of [the LaTeX report](docs/report/main.tex).

The deployed settings are in `k8s/deployment.yaml`: CPU/memory requests of `50m`/`64Mi` and limits of `250m`/`128Mi`, yielding Burstable QoS because requests differ from limits. Requests reserve scheduling capacity; CPU limits constrain CPU time and exceeding the memory limit can cause an OOM kill. Readiness checks `/health` on named port `http`, with initial delay 2 seconds, period 5 seconds, failure threshold 2, and success threshold 1 (default timeout 1 second). Readiness governs Service traffic eligibility, not process restart; there is deliberately no liveness probe.

### Preparation and baseline

A running Pod's readiness probe is immutable, so changing it by a per-Pod patch is not supported here. Instead, the application-level file toggle implements the permitted alternative. The Deployment's image, `READINESS_FILE=/tmp/ready`, and `postStart` command `touch /tmp/ready` were rolled out normally before baseline capture. No Deployment/template changes occurred during the experiment itself.

```bash
cd ~/CS-554-MidTerm
docker build -t cs554-midterm:1.1 app
cd compose
docker compose up -d
docker compose up -d --wait --wait-timeout 90
docker compose ps
curl -sS --max-time 5 http://localhost:8080/
curl -i --max-time 5 http://localhost:8080/health
cd ..
k3d image import cs554-midterm:1.1 -c cs554
docker exec k3d-cs554-server-0 crictl images | grep cs554-midterm
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deploy/cs554-midterm --timeout=120s
kubectl get pods -l app=cs554-midterm -o wide
kubectl get deploy cs554-midterm -o yaml
kubectl get deploy cs554-midterm -o jsonpath='{.metadata.generation}'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o yaml
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -sS --max-time 5 http://cs554-midterm/; echo; done'
```

Both new Pods were Ready, both EndpointSlice entries had `ready: true`, and requests reached both hostnames. Choose one current Pod name as `<pod-A>`; the recorded A was `cs554-midterm-67c66d7b5d-98k98`, B was `cs554-midterm-67c66d7b5d-l2ffr`. Check A's initial file and counter:

```bash
kubectl exec <pod-A> -- ls -l /tmp/ready
kubectl exec <pod-A> -- wget -qO- http://127.0.0.1:8080/
```

Record your own baseline direct count N: expect N+1 during failure and N+2 after recovery, before new Service traffic. Generation starts at 1 on a fresh deploy and must remain unchanged during this experiment. Names, UIDs, start times, addresses, and absolute counts are run-specific; the evidence's generation 2 and counts 4/5/6 describe the recorded run.

Optional continuity snapshots, taken before changing readiness:

```bash
mkdir -p .qualification
kubectl get pods -l app=cs554-midterm -o json | jq -S '[.items[] | {name:.metadata.name,uid:.metadata.uid,containerID:.status.containerStatuses[0].containerID,restarts:.status.containerStatuses[0].restartCount,startedAt:.status.containerStatuses[0].state.running.startedAt}] | sort_by(.name)' > .qualification/pods-before.json
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > .qualification/deploy-before.json
```

### One running replica becomes NotReady

```bash
kubectl exec <pod-A> -- rm /tmp/ready
for i in 1 2 3 4 5 6 7; do
    date --iso-8601=seconds
    kubectl get pods -l app=cs554-midterm
    sleep 3
done
kubectl describe pod <pod-A>
kubectl exec <pod-A> -- wget -qO- http://127.0.0.1:8080/
kubectl exec <pod-A> -- wget -qO- http://127.0.0.1:8080/health || echo "health exit=$?"
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o yaml
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -sS --max-time 5 http://cs554-midterm/; echo; done'
```

A became `0/1 Running` with zero restarts after two consecutive failing probes (about ten seconds with this period, plus status propagation; a rehearsal first showed `0/1` at twelve seconds). Its probe failed with HTTP 503, but a direct root request still succeeded with count 5, continuing from 4. A remained listed in the EndpointSlice with `ready: false` and `serving: false`; B stayed `ready: true`. All ten Service-DNS requests reached B. This tests ready-backend eligibility through ClusterIP routing; port-forward is not used because it pins to one Pod.

### Restore and prove process continuity

```bash
kubectl exec <pod-A> -- touch /tmp/ready
kubectl wait --for=condition=Ready pod/<pod-A> --timeout=30s
kubectl get pods -l app=cs554-midterm
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o yaml
kubectl exec <pod-A> -- wget -qO- http://127.0.0.1:8080/
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -sS --max-time 5 http://cs554-midterm/; echo; done'
kubectl get deploy cs554-midterm -o jsonpath='{.metadata.generation}'
```

This is a short random sample, not a distribution guarantee; one hostname in a short sample, especially right after a change, is not a failure.

A recovered within one probe period, both endpoints became ready, and Service requests again reached both hostnames. A's next direct request counted 6: readiness had not restarted the process or reset its state. Pod names, UIDs, container IDs, start times, and zero restarts matched the baseline; Deployment generation stayed 2 and its template was identical throughout. Every temporary change was restored by recreating the file. Both environments remain running on image `1.1`; complete captures and the unchanged probe/resource excerpt are in `evidence/04-readiness-554.md`.

Optional: repeat the continuity snapshots after recovery. Both `cmp` commands exit 0 when the recorded Pod identities and Deployment generation/spec are unchanged:

```bash
kubectl get pods -l app=cs554-midterm -o json | jq -S '[.items[] | {name:.metadata.name,uid:.metadata.uid,containerID:.status.containerStatuses[0].containerID,restarts:.status.containerStatuses[0].restartCount,startedAt:.status.containerStatuses[0].state.running.startedAt}] | sort_by(.name)' > .qualification/pods-after.json
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > .qualification/deploy-after.json
cmp .qualification/pods-before.json .qualification/pods-after.json
cmp .qualification/deploy-before.json .qualification/deploy-after.json
```

## Full teardown

From the checkout root, after the walkthrough is recorded:

```bash
cd ~/CS-554-MidTerm
kubectl delete -f k8s/client-pod.yaml -f k8s/service.yaml -f k8s/deployment.yaml
docker compose -f compose/compose.yaml down
k3d cluster delete cs554
docker rmi cs554-midterm:1.1
docker ps -a
docker image ls
docker compose ls --all
k3d cluster list
```

What remains: the checkout, the ignored `compose/.env`, the `$HOME/cs554-issue5-*` captures, any `.qualification/` snapshots, and the pulled base and tool images (`node:22-alpine`, `rancher/k3s`, the k3d helper images). Remove only what you created; do not prune shared images.

## Report (LaTeX)

The report source is [docs/report/main.tex](docs/report/main.tex), with its bibliography in [docs/report/references.bib](docs/report/references.bib). Overleaf uses GitHub Sync with this repository; the report source is managed there. To compile locally with pdfLaTeX, BibTeX, and `latexmk`, run:

Compile on a machine with pdfLaTeX, BibTeX, and `latexmk`; the VM recipe does not install TeX. CI compiles the report on every push, so the VM is not needed for it.

```text
cd docs/report
latexmk -pdf main.tex
```

CI compiles the report on every push and pull request and publishes the PDF as the `report-pdf` workflow artifact. Open [Actions](https://github.com/RemyMartinRosenhoover/CS-554-MidTerm/actions), select the latest successful `ci` run, and download `report-pdf` under Artifacts. `docs/report/main.pdf` is committed at submission time; until then use the CI artifact. The editable diagram source is [docs/diagram.svg](docs/diagram.svg).

## Report and evidence

- [Report source](docs/report/main.tex): LaTeX source for the deployment analysis, diagram, OpenStack plan, and CS 554 interpretation.
- [Compiled report](https://github.com/RemyMartinRosenhoover/CS-554-MidTerm/actions): latest successful `ci` run, then Artifacts, then `report-pdf`.
- [Deployment diagram](docs/diagram.svg): host, VM, Compose container, k3d cluster, and request paths with addresses and ports.
- [Walkthrough Demonstration Guide](docs/report/recording-runbook.pdf): the procedure behind the recorded walkthrough, usable to reproduce the demonstration step by step (source `docs/report/recording-runbook.tex`).
- [References](docs/references.md): numbered source list mirrored from the report's BibTeX bibliography.
- [Evidence index](evidence/README.md): capture format and file map.
- [Host and VM](evidence/00-host-vm.md): VM configuration, tools, networking, reachability, and TLS verification.
- [Docker Compose](evidence/01-compose.md): image build, requests, health, logs, counter restart, and cleanup.
- [Kubernetes](evidence/02-kubernetes.md): image import, two ready replicas, Service traffic, resources, and automatic Pod replacement.
- [Selector troubleshooting](evidence/03-selector-break.md): baseline, intentional mismatch, client failure, diagnosis, correction, and recovery.
- [CS 554 readiness](evidence/04-readiness-554.md): image 1.1 rollout, one running NotReady replica, ready-backend traffic, recovery, and process continuity.

## Manual setup steps

No interactive Ubuntu installation was needed; cloud-init used `DataSourceVMware [seed=guestinfo]` and completed successfully. The first import produced virtual hardware version 99, which Workstation rejected before boot. With the VM powered off, it was corrected to 21; the recipe now supplies `--maxVirtualHardwareVersion=21` to reproduce the correction.

The imported serial device was initially disconnected. It was connected using `vmrun connectNamedDevice ... serial0`; the recipe now sets `serial0.startConnected = "TRUE"`. Serial output goes to `$env:USERPROFILE\codex-work\logs\cs554-vm-serial.log`. Early first-boot messages were recovered from `/var/log/cloud-init-output.log` because the serial log did not capture that period; those messages are not serial-console evidence. For startup troubleshooting, inspect the new VM's `vmware.log`, the serial log and `cloud-init status --long` without changing host settings.

All seven in-VM TLS endpoints validated with public CA issuers before provisioning; no extra root certificate was needed. Recheck TLS on a different network before downloads. If validation fails, stop for the appropriate approved trust configuration; never disable certificate verification. No guest VM fallback route, host software install, or host configuration change was required.
