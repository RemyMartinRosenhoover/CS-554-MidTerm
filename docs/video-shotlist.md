# Walkthrough Shot List

Target: **4:00 total** (20 + 50 + 50 + 40 + 60 + 20 seconds). Six shots; one troubleshooting finding. Rehearsed on 2026-10-19 UTC: shots 2-4 at 17:40-17:51, shot 5 at 19:45 after the recovery fix merged. The running services were not reset just to make the counters look fresh.

Current staging baseline, checked at 19:47 UTC:

| Item | Live value |
|---|---|
| VM address | `192.168.197.134` (VMware NAT; confirm DHCP before recording) |
| VM checkout | `/home/student/CS-554-MidTerm` |
| Same application image in both environments | `cs554-midterm:1.1` |
| Application Pods | `cs554-midterm-67c66d7b5d-2v5mx`, `cs554-midterm-67c66d7b5d-l2ffr` |
| Deployment / Pods | `2/2`; both `1/1 Running`, zero restarts |
| Correct Service selector | `app=cs554-midterm` |
| Service / endpoints | `10.43.197.200:80`; `10.42.0.17`, `10.42.0.19` |
| Compose | `compose-web-1`, healthy; VM port 8080 |

The outputs below are real same-day rehearsal captures, not predictions of exact counters, ages or replacement names. The old Pod `cs554-midterm-67c66d7b5d-98k98` appears only in shots 3-4's earlier captures: it was deleted in shot 4 and replaced by the current `2v5mx` Pod. Do not type that deleted name. Shot 4 selects a current Pod dynamically; its next replacement will have another generated name. A short Service sample may show one hostname; it is not a round-robin or fairness test.

## 1. Open (0:00-0:20)

**Screen:** Public README in the browser, repository layout table and environment summary. No terminal command.

**Expected view:** `app/`, `compose/`, `k8s/`, `docs/`, `evidence/`, `scripts/`; Ubuntu VM with 2 vCPUs and 4096 MiB RAM; Compose and single-node k3d inside that VM; image `cs554-midterm:1.1`.

**Narration:** "This is one small service packaged as one image. Compose and Kubernetes both run inside this Linux VM on Windows, so the host, VM, container and application are separate layers."

## 2. Compose (0:20-1:10)

**Screen:** First SSH session in the VM; then switch to the host PowerShell window.

VM commands:

```bash
cd ~/CS-554-MidTerm/compose
docker compose ps
curl -s localhost:8080/
curl -s localhost:8080/
```

Observed at 17:40 UTC (consecutive JSON responses have no trailing newline):

```text
NAME            IMAGE               COMMAND                  SERVICE   CREATED        STATUS                  PORTS
compose-web-1   cs554-midterm:1.1   "docker-entrypoint.s…"   web       20 hours ago   Up 20 hours (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"9577b9f64fc0","requestCount":2}{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"9577b9f64fc0","requestCount":3}
```

Host PowerShell command, observed at 17:41 UTC:

```powershell
curl.exe -s http://192.168.197.134:8080/
```

```text
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"9577b9f64fc0","requestCount":4}
```

**Narration:** "The Windows host reaches the VM's NAT address directly; no port forwarding is needed on VMware. The hostname stays the same and the count rises from 2 to 3 to 4, because this counter belongs to that application process."

Use the actual consecutive counts while recording, not the rehearsal's absolute values. Compose stayed running; the later state capture shows an older container age without changing its healthy status.

## 3. Kubernetes (1:10-2:00)

**Screen:** Second SSH session in `/home/student/CS-554-MidTerm`.

```bash
cd ~/CS-554-MidTerm
kubectl get deploy,pods,svc
kubectl exec client -- sh -c 'for i in 1 2 3 4; do curl -s http://cs554-midterm/; echo; done'
```

Observed at 17:49 UTC, before the rehearsal's Pod replacement:

```text
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cs554-midterm   2/2     2            2           22h

NAME                                 READY   STATUS    RESTARTS   AGE
pod/client                           1/1     Running   0          22h
pod/cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          19h
pod/cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          19h

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/cs554-midterm   ClusterIP   10.43.197.200   <none>        80/TCP    22h
service/kubernetes      ClusterIP   10.43.0.1       <none>        443/TCP   23h
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":45}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":46}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":30}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":47}
```

**Narration:** "Kubernetes uses the same image, imported with `k3d image import`, and maintains two ready replicas. These in-cluster requests use Service DNS and ClusterIP routing; this sample reached both hostnames with independent counters, not guaranteed round-robin ordering."

The live status now names `2v5mx` instead of deleted `98k98`. No port-forward is used here: a Service port-forward selects one Pod and cannot demonstrate traffic across both replicas.

## 4. Pod Replacement (2:00-2:40)

**Screen:** Keep the second SSH session visible. Select a current Pod, delete only that Pod, watch for about ten seconds, then press Ctrl+C when the new Pod is `1/1`.

```bash
pod_to_delete=$(kubectl get pods -l app=cs554-midterm -o jsonpath='{.items[0].metadata.name}')
printf 'Selected Pod: %s\n' "$pod_to_delete"
kubectl delete pod "$pod_to_delete" --wait=false
kubectl get pods -w
```

After stopping the watch:

```bash
kubectl rollout status deploy/cs554-midterm --timeout=120s
kubectl get pods
```

Observed at 17:51 UTC. The noninteractive rehearsal used `timeout 10s kubectl get pods -w`; exit 124 below is the intentional watch limit, equivalent to stopping the interactive watch with Ctrl+C. The replacement reached `1/1` in seven seconds:

```text
Selected Pod: cs554-midterm-67c66d7b5d-98k98
pod "cs554-midterm-67c66d7b5d-98k98" deleted from default namespace
NAME                             READY   STATUS        RESTARTS   AGE
client                           1/1     Running       0          22h
cs554-midterm-67c66d7b5d-98k98   1/1     Terminating   0          19h
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running       0          19h
cs554-midterm-67c66d7b5d-98k98   0/1     Completed     0          19h
cs554-midterm-67c66d7b5d-2v5mx   0/1     Pending       0          0s
cs554-midterm-67c66d7b5d-2v5mx   0/1     Pending       0          0s
cs554-midterm-67c66d7b5d-2v5mx   0/1     ContainerCreating   0          0s
cs554-midterm-67c66d7b5d-2v5mx   0/1     ContainerCreating   0          1s
cs554-midterm-67c66d7b5d-98k98   0/1     Completed           0          19h
cs554-midterm-67c66d7b5d-98k98   0/1     Completed           0          19h
cs554-midterm-67c66d7b5d-2v5mx   0/1     Running             0          1s
cs554-midterm-67c66d7b5d-2v5mx   1/1     Running             0          7s
Watch exit: 124 (124 means the ten-second recording window ended)
deployment "cs554-midterm" successfully rolled out
NAME                             READY   STATUS    RESTARTS   AGE
client                           1/1     Running   0          22h
cs554-midterm-67c66d7b5d-2v5mx   1/1     Running   0          10s
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          19h
```

**Narration:** "The ReplicaSet controller sees fewer Pods than the Deployment's desired two and creates a new named Pod automatically. Compose's manual restart reused its container and restarted the process; here Kubernetes replaces the Pod, and either new process loses its temporary counter."

Wait for two ready replicas before shot 5; if replacement takes longer, keep the watch running until ready. Do not reuse the captured `98k98` name or expect the next replacement to be called `2v5mx`.

## 5. Troubleshooting Finding (2:40-3:40)

**Screen:** Second SSH session. No port-forward is running. Paste the selector-failure group, show healthy Pods with empty endpoints, then paste the restore group. The bounded zero-endpoint wait is the verified rehearsal's setup; the restore group is the README's complete "Restore and verify" block, unchanged.

Break and diagnose:

```bash
kubectl apply -f k8s/service-broken.yaml
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector.app}'; echo
for attempt in $(seq 1 20); do
    count=$(kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq '[.items[].endpoints[]? | select(.conditions.ready == true)] | length')
    if test "$count" -eq 0; then break; fi
    sleep 1
done
test "$count" -eq 0
failure_exit=0
kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/ || failure_exit=$?
printf 'Expected failed request exit: %s\n' "$failure_exit"
test "$failure_exit" -eq 7
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm
```

Restore and verify, verbatim from the merged README:

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

Observed at 19:45 UTC (the marker separates the failure group from the restore group):

```text
service/cs554-midterm configured
cs554-midterm-typo
curl: (7) Failed to connect to cs554-midterm port 80 after 0 ms: Could not connect to server
command terminated with exit code 7
Expected failed request exit: 7
NAME                             READY   STATUS    RESTARTS   AGE
client                           1/1     Running   0          24h
cs554-midterm-67c66d7b5d-2v5mx   1/1     Running   0          114m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          21h
NAME                  ADDRESSTYPE   PORTS     ENDPOINTS   AGE
cs554-midterm-q55pw   IPv4          <unset>   <unset>     24h

=== Merged README restore block (verbatim) ===
service/cs554-midterm configured
{"app":"cs554-midterm"}NAME                  ADDRESSTYPE   PORTS   ENDPOINTS               AGE
cs554-midterm-q55pw   IPv4          8080    10.42.0.17,10.42.0.19   24h
Selector:                 app=cs554-midterm
Endpoints:                10.42.0.17:8080,10.42.0.19:8080
curl: (7) Failed to connect to cs554-midterm port 80 after 0 ms: Could not connect to server
command terminated with exit code 7
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":50}recovered on attempt 2
NAME                             READY   STATUS    RESTARTS   AGE    LABELS
cs554-midterm-67c66d7b5d-2v5mx   1/1     Running   0          114m   app=cs554-midterm,pod-template-hash=67c66d7b5d,tier=web
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          21h    app=cs554-midterm,pod-template-hash=67c66d7b5d,tier=web
```

**Narration:** "Healthy Pods alone do not prove the Service works: its selector is a label query, and the typo leaves it with no matching endpoints. After correction, endpoints can return before the node's forwarding rules converge; the first recovery request still failed here, and the bounded retry succeeded on attempt 2."

Show the successful JSON and `recovered on attempt N` before moving on. The count can vary: two ready endpoints alone are not the recovery criterion. If it prints `none`, stop the recording and retain the failed output; do not claim recovery. If interrupted while the selector is broken, run this same complete restore group before leaving the session. No Deployment edit or readiness toggle belongs in this shot.

## 6. Close (3:40-4:00)

**Screen:** Public README's "Report and evidence" links and report/PDF instructions. No terminal command.

**Expected view:** Evidence index and `evidence/00` through `04`; report source `docs/report/main.tex`; latest successful `ci` run with downloadable `report-pdf`; diagram and references.

**Narration:** "The deployment and experiments are captured in the evidence files, and the technical report explains the comparison and OpenStack plan. The separate CS 554 readiness experiment is in `evidence/04-readiness-554.md` and section 6 of the report; it is not part of this on-camera selector demonstration."

## Staging Checklist

- [ ] Record only after the README has been independently reproduced and its fix list closed, so the commands on camera are the final ones.
- [ ] Confirm the current DHCP address, a clean checkout at current `main`, and green CI. Confirm the baseline before starting: two application replicas Ready, correct selector, client Pod Running, Compose healthy. Stop any old port-forward before recording; do not tear down the project VM.
- [ ] Open the public README in a browser, one host PowerShell window, one SSH session at `/home/student/CS-554-MidTerm/compose`, and a second SSH session at `/home/student/CS-554-MidTerm` for kubectl. Keep the current Pod names visible; shot 4 selects a live name.
- [ ] Use a readable font at 1080p. Hide personal host paths, account names, tabs, notifications and taskbar details; only public project content and guest terminal output should be visible. Do not show the private agent repository or keys.
- [ ] Recorder: Camtasia, capturing a region that holds the terminals and the browser, microphone on, 1080p. Keep the demonstration windows inside that region when switching between them. Export as MP4.
- [ ] Fallbacks if Camtasia is unavailable: Snipping Tool (Win+Shift+S, video-camera icon, region, microphone), then PowerPoint Record Screen, then a Teams screen-share recording.
- [ ] Aim for four minutes, showing results rather than installation. Do not record the readiness experiment. After shot 4, wait for both replicas; after shot 5, show a successful request and leave the selector correct.
- [ ] Replay the recording for legible output and audible narration. Verify the restored state (correct selector, two ready endpoints, both Pods `1/1` with zero restarts, Compose healthy); leave Compose, the cluster and two replicas running. If a check fails, preserve the output and stop for diagnosis.
- [ ] Upload as an unlisted video or an appropriately shared cloud recording. Test the recording URL in a signed-out/private browser window so the grader does not need to request access; add the real recording link to the README and Canvas note. This shot-list link is not the recording submission.
