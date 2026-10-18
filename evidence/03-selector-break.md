# 03 — Controlled troubleshooting: Service selector (Part 4)

Must contain:

- [x] Baseline: the Service's selector (`kubectl get svc <service> -o yaml`, selector section), Pod labels (`kubectl get pods --show-labels`), an EndpointSlice with two endpoints, and one successful request through the Service
- [x] The exact change: `diff k8s/service.yaml k8s/service-broken.yaml`, then `kubectl apply -f k8s/service-broken.yaml`
- [x] If port forwarding is the access method: the old `port-forward` session stopped and a new one started **after** the change
- [x] Symptom seen by the client, verbatim: the `curl` error or the `port-forward` error text
- [x] At least two observations (more is better): Pods still `1/1 Running` and Ready; Pod labels unchanged; the Service selector now mismatched; `kubectl get endpointslices` for the Service showing no endpoints; `kubectl describe svc <service>` showing `Endpoints: <none>`; application logs showing no new request lines
- [x] Correction: `kubectl apply -f k8s/service.yaml`, the EndpointSlice repopulating, forwarding re-established if used, and a successful request after recovery

## Captures

### Working baseline

VM/cluster over SSH at 2026-10-18T15:19:38.3870852-05:00. Two ready Pods match the Service selector and populate two endpoints. The in-cluster request succeeds; Pod identity snapshots establish the comparison baseline.

```text
$ set -e
kubectl get pods -l app=cs554-midterm --show-labels
kubectl get svc cs554-midterm -o yaml | sed -n '/^spec:/,$p'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl describe svc cs554-midterm | grep -E 'Selector|Endpoints'
kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/
printf '\n'
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > /home/student/cs554-issue5-deploy-before.json
kubectl get pods -l app=cs554-midterm -o json | jq -S '[.items[] | {name:.metadata.name,uid:.metadata.uid,labels:.metadata.labels,restarts:.status.containerStatuses[0].restartCount}] | sort_by(.name)' > /home/student/cs554-issue5-pods-before.json
cat /home/student/cs554-issue5-pods-before.json
NAME                            READY   STATUS    RESTARTS   AGE   LABELS
cs554-midterm-64fccd9c5-qkbzg   1/1     Running   0          79m   app=cs554-midterm,pod-template-hash=64fccd9c5,tier=web
cs554-midterm-64fccd9c5-zfhl2   1/1     Running   0          79m   app=cs554-midterm,pod-template-hash=64fccd9c5,tier=web
spec:
  clusterIP: 10.43.197.200
  clusterIPs:
  - 10.43.197.200
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - port: 80
    protocol: TCP
    targetPort: http
  selector:
    app: cs554-midterm
  sessionAffinity: None
  type: ClusterIP
status:
  loadBalancer: {}
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS               AGE
cs554-midterm-q55pw   IPv4          8080    10.42.0.14,10.42.0.16   79m
Selector:                 app=cs554-midterm
Endpoints:                10.42.0.14:8080,10.42.0.16:8080
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-zfhl2","requestCount":1}
[
  {
    "labels": {
      "app": "cs554-midterm",
      "pod-template-hash": "64fccd9c5",
      "tier": "web"
    },
    "name": "cs554-midterm-64fccd9c5-qkbzg",
    "restarts": 0,
    "uid": "110199b7-7264-4dc9-b803-70ebad86e0a5"
  },
  {
    "labels": {
      "app": "cs554-midterm",
      "pod-template-hash": "64fccd9c5",
      "tier": "web"
    },
    "name": "cs554-midterm-64fccd9c5-zfhl2",
    "restarts": 0,
    "uid": "cd99ebd8-b472-412b-9c5f-808cc8f26f55"
  }
]
[Exit code: 0]
```

### Fresh baseline port-forward

VM/cluster over SSH at 2026-10-18T15:20:44.7079469-05:00. A new forwarder selects a matching Pod and serves one request; it is explicitly stopped before the selector change.

```text
$ set -e
kubectl port-forward svc/cs554-midterm 18080:80 > /home/student/cs554-issue5-baseline-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 30); do
    if grep -q 'Forwarding from' /home/student/cs554-issue5-baseline-forward.log; then break; fi
    sleep 1
done
curl -sS --max-time 5 http://127.0.0.1:18080/
printf '\n'
cat /home/student/cs554-issue5-baseline-forward.log
kill "$forward_pid"
wait "$forward_pid" || true
trap - EXIT
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-qkbzg","requestCount":1}
Forwarding from 127.0.0.1:18080 -> 8080
Forwarding from [::1]:18080 -> 8080
Handling connection for 18080
[Exit code: 0]
```

### Exact selector change

VM/cluster over SSH at 2026-10-18T15:21:56.1072659-05:00. Only app: cs554-midterm becomes app: cs554-midterm-typo. Diff exit 1 means the expected difference. The apply succeeds; the subsequent agent query fails because .endpoints[] cannot iterate null, corrected in the next capture without changing cluster state.

```text
$ set -e
cd /home/student/CS-554-MidTerm
set +e
diff -u k8s/service.yaml k8s/service-broken.yaml
diff_status=$?
set -e
printf 'diff exit=%s (1 means files differ)\n' "$diff_status"
test "$diff_status" -eq 1
date --iso-8601=seconds > /home/student/cs554-issue5-failure-start.txt
cat /home/student/cs554-issue5-failure-start.txt
kubectl apply -f k8s/service-broken.yaml
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector}'
printf '\n'
for attempt in $(seq 1 20); do
    count=$(kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq '[.items[].endpoints[]] | length')
    if [ "$count" -eq 0 ]; then break; fi
    sleep 1
done
test "$count" -eq 0
--- k8s/service.yaml	2026-10-18 19:28:08.807924562 +0000
+++ k8s/service-broken.yaml	2026-10-18 19:28:08.807924562 +0000
@@ -5,7 +5,7 @@
 spec:
   type: ClusterIP
   selector:
-    app: cs554-midterm
+    app: cs554-midterm-typo
   ports:
     - port: 80
       targetPort: http
diff exit=1 (1 means files differ)
2026-10-18T20:21:56+00:00
service/cs554-midterm configured
{"app":"cs554-midterm-typo"}
jq: error (at <stdin>:39): Cannot iterate over null (null)
[Exit code: 5]
```

### In-cluster client symptoms

VM/cluster over SSH at 2026-10-18T15:23:03.6045026-05:00. The Service has zero backends; all three curls fail with exit 7. Kubectl 1.37 represents an empty EndpointSlice endpoint set as null; the optional iterator counts it as zero.

```text
$ set -e
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq '{slices:[.items[] | {name:.metadata.name,endpoints:.endpoints}],endpointCount:[.items[].endpoints[]?] | length}'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq -e '[.items[].endpoints[]?] | length == 0'
for i in 1 2 3; do
    date --iso-8601=seconds
    set +e
    kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/
    status=$?
    set -e
    printf 'exit=%s\n' "$status"
    test "$status" -eq 7 -o "$status" -eq 28
done
{
  "slices": [
    {
      "name": "cs554-midterm-q55pw",
      "endpoints": null
    }
  ],
  "endpointCount": 0
}
true
2026-10-18T20:23:04+00:00
curl: (7) Failed to connect to cs554-midterm port 80 after 0 ms: Could not connect to server
command terminated with exit code 7
exit=7
2026-10-18T20:23:04+00:00
curl: (7) Failed to connect to cs554-midterm port 80 after 0 ms: Could not connect to server
command terminated with exit code 7
exit=7
2026-10-18T20:23:04+00:00
curl: (7) Failed to connect to cs554-midterm port 80 after 0 ms: Could not connect to server
command terminated with exit code 7
exit=7
[Exit code: 0]
```

### Fresh port-forward failure

VM/cluster over SSH at 2026-10-18T15:23:26.6364969-05:00. A new session starts after the selector change, waits at most 5 seconds for a matching Pod, and exits 1 with its exact timeout error; the local curl exits 7. This is not a reused forwarding session.

```text
$ set -e
kubectl port-forward --pod-running-timeout=5s svc/cs554-midterm 18080:80 > /home/student/cs554-issue5-broken-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
sleep 6
set +e
curl -sS --max-time 5 http://127.0.0.1:18080/
curl_status=$?
wait "$forward_pid"
forward_status=$?
set -e
printf 'curl exit=%s\nport-forward exit=%s\n' "$curl_status" "$forward_status"
cat /home/student/cs554-issue5-broken-forward.log
trap - EXIT
test "$curl_status" -ne 0
test "$forward_status" -ne 0
curl: (7) Failed to connect to 127.0.0.1 port 18080 after 0 ms: Couldn't connect to server
curl exit=7
port-forward exit=1
error: timed out waiting for the condition
[Exit code: 0]
```

### Failure diagnosis

VM/cluster over SSH at 2026-10-18T15:25:25.0265682-05:00. Pods remain ready with zero restarts and unchanged labels; Deployment UID/generation/spec are unchanged. Kubectl 1.37 renders zero endpoints as <unset> and a blank Endpoints: line rather than <none> as in older versions. Collected logs from both Pods since the failure-start timestamp contain only health probes and zero root requests.

```text
$ set -e
kubectl get pods -l app=cs554-midterm
kubectl get pods --show-labels
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector}'
printf '\n'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl describe svc cs554-midterm | grep Endpoints
kubectl get deploy cs554-midterm
kubectl logs deploy/cs554-midterm --since=2m
failure_start=$(cat /home/student/cs554-issue5-failure-start.txt)
printf 'Exact failure window starts at %s\n' "$failure_start"
kubectl logs -l app=cs554-midterm --since-time="$failure_start" --timestamps --prefix --tail=-1 > /home/student/cs554-issue5-failure-logs.txt
cat /home/student/cs554-issue5-failure-logs.txt
root_count=$(grep -c '"path":"/"' /home/student/cs554-issue5-failure-logs.txt || true)
printf 'GET / lines across both Pods during failure=%s\n' "$root_count"
test "$root_count" -eq 0
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > /home/student/cs554-issue5-deploy-during.json
cmp /home/student/cs554-issue5-deploy-before.json /home/student/cs554-issue5-deploy-during.json
printf 'Deployment UID, generation, and spec unchanged\n'
NAME                            READY   STATUS    RESTARTS   AGE
cs554-midterm-64fccd9c5-qkbzg   1/1     Running   0          85m
cs554-midterm-64fccd9c5-zfhl2   1/1     Running   0          85m
NAME                            READY   STATUS    RESTARTS   AGE   LABELS
client                          1/1     Running   0          85m   <none>
cs554-midterm-64fccd9c5-qkbzg   1/1     Running   0          85m   app=cs554-midterm,pod-template-hash=64fccd9c5,tier=web
cs554-midterm-64fccd9c5-zfhl2   1/1     Running   0          85m   app=cs554-midterm,pod-template-hash=64fccd9c5,tier=web
{"app":"cs554-midterm-typo"}
NAME                  ADDRESSTYPE   PORTS     ENDPOINTS   AGE
cs554-midterm-q55pw   IPv4          <unset>   <unset>     85m
Endpoints:                
NAME            READY   UP-TO-DATE   AVAILABLE   AGE
cs554-midterm   2/2     2            2           85m
Found 2 pods, using pod/cs554-midterm-64fccd9c5-qkbzg
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
{"method":"GET","path":"/health","status":200}
Exact failure window starts at 2026-10-18T20:21:56+00:00
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:21:59.413992163Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:04.414304783Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:09.414476485Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:14.414664859Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:19.417805722Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:24.417483343Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:29.415369565Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:34.414210564Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:39.414994620Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:44.414253916Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:49.416316105Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:54.414556872Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:22:59.414588043Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:04.413861219Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:09.414260775Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:14.415333042Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:19.415109563Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:24.414237943Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:29.417999873Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:34.414057727Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:39.414841417Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:44.414398219Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:49.415930904Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:54.414053654Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:23:59.415012500Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:04.414876133Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:09.414293047Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:14.415635785Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:19.414849171Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:24.414943602Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:29.413979818Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:34.413809085Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:39.413910656Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:44.415369679Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:49.415772498Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:54.415299481Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:24:59.414251276Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:25:04.414229542Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:25:09.414297981Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:25:14.413439513Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:25:19.413649100Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-qkbzg/web] 2026-10-18T20:25:24.414066144Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:21:59.414466990Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:04.414334090Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:09.415038127Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:14.415182746Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:19.417001345Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:24.415830197Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:29.415308579Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:34.414237192Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:39.414927929Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:44.413972473Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:49.416245535Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:54.414250286Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:22:59.414773029Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:04.413460371Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:09.414287592Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:14.415372545Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:19.415301054Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:24.417254688Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:29.414308210Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:34.414084874Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:39.414819112Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:44.415571574Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:49.415476016Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:54.414080581Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:23:59.415060868Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:04.414930782Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:09.415035030Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:14.415164612Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:19.414901532Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:24.414750759Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:29.414194471Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:34.413833652Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:39.413940209Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:44.414272130Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:49.415168390Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:54.414725925Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:24:59.415372428Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:25:04.413846777Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:25:09.414810602Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:25:14.413826448Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:25:19.413962761Z {"method":"GET","path":"/health","status":200}
[pod/cs554-midterm-64fccd9c5-zfhl2/web] 2026-10-18T20:25:24.414696345Z {"method":"GET","path":"/health","status":200}
GET / lines across both Pods during failure=0
Deployment UID, generation, and spec unchanged
[Exit code: 0]
```

### Correct selector and recovery

VM/cluster over SSH at 2026-10-18T15:29:24.6946965-05:00. Only the working Service is reapplied; two ready endpoints return and the in-cluster request succeeds. Names, UIDs, labels, restart counts, and Deployment snapshots match the baseline, proving no Pod restart or recreation.

```text
$ set -e
cd /home/student/CS-554-MidTerm
date --iso-8601=seconds
kubectl apply -f k8s/service.yaml
for attempt in $(seq 1 20); do
    count=$(kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq '[.items[].endpoints[]? | select(.conditions.ready == true)] | length')
    if [ "$count" -eq 2 ]; then break; fi
    sleep 1
done
test "$count" -eq 2
kubectl get svc cs554-midterm -o jsonpath='{.spec.selector}'
printf '\n'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide
kubectl describe svc cs554-midterm | grep -E 'Selector|Endpoints'
kubectl exec client -- curl -sS --max-time 5 http://cs554-midterm/
printf '\n'
kubectl get pods -l app=cs554-midterm --show-labels
kubectl get pods -l app=cs554-midterm -o json | jq -S '[.items[] | {name:.metadata.name,uid:.metadata.uid,labels:.metadata.labels,restarts:.status.containerStatuses[0].restartCount}] | sort_by(.name)' > /home/student/cs554-issue5-pods-after.json
cmp /home/student/cs554-issue5-pods-before.json /home/student/cs554-issue5-pods-after.json
printf 'Pod names, UIDs, labels, and restart counts unchanged\n'
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > /home/student/cs554-issue5-deploy-after.json
cmp /home/student/cs554-issue5-deploy-before.json /home/student/cs554-issue5-deploy-after.json
printf 'Deployment UID, generation, and spec unchanged after recovery\n'
2026-10-18T20:29:25+00:00
service/cs554-midterm configured
{"app":"cs554-midterm"}
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS               AGE
cs554-midterm-q55pw   IPv4          8080    10.42.0.16,10.42.0.14   89m
Selector:                 app=cs554-midterm
Endpoints:                10.42.0.16:8080,10.42.0.14:8080
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-zfhl2","requestCount":2}
NAME                            READY   STATUS    RESTARTS   AGE   LABELS
cs554-midterm-64fccd9c5-qkbzg   1/1     Running   0          89m   app=cs554-midterm,pod-template-hash=64fccd9c5,tier=web
cs554-midterm-64fccd9c5-zfhl2   1/1     Running   0          89m   app=cs554-midterm,pod-template-hash=64fccd9c5,tier=web
Pod names, UIDs, labels, and restart counts unchanged
Deployment UID, generation, and spec unchanged after recovery
[Exit code: 0]
```

### Fresh recovery forwarder and final state

VM/cluster over SSH at 2026-10-18T15:32:04.6955152-05:00. A new forwarder now selects a Pod and succeeds, then is stopped. Correct selector, two ready endpoints, unchanged running Pods/client, and healthy Compose remain for the next task.

```text
$ set -e
kubectl port-forward svc/cs554-midterm 18080:80 > /home/student/cs554-issue5-recovery-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 30); do
    if grep -q 'Forwarding from' /home/student/cs554-issue5-recovery-forward.log; then break; fi
    sleep 1
done
curl -sS --max-time 5 http://127.0.0.1:18080/
printf '\n'
cat /home/student/cs554-issue5-recovery-forward.log
kill "$forward_pid"
wait "$forward_pid" || true
trap - EXIT
kubectl get deploy,rs,pods,svc -o wide
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq -e '[.items[].endpoints[]? | select(.conditions.ready == true)] | length == 2'
cd /home/student/CS-554-MidTerm
docker compose -f compose/compose.yaml ps
git status --short --branch
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-qkbzg","requestCount":2}
Forwarding from 127.0.0.1:18080 -> 8080
Forwarding from [::1]:18080 -> 8080
Handling connection for 18080
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES              SELECTOR
deployment.apps/cs554-midterm   2/2     2            2           92m   web          cs554-midterm:1.0   app=cs554-midterm

NAME                                      DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES              SELECTOR
replicaset.apps/cs554-midterm-64fccd9c5   2         2         2       92m   web          cs554-midterm:1.0   app=cs554-midterm,pod-template-hash=64fccd9c5

NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
pod/client                          1/1     Running   0          92m   10.42.0.15   k3d-cs554-server-0   <none>           <none>
pod/cs554-midterm-64fccd9c5-qkbzg   1/1     Running   0          92m   10.42.0.14   k3d-cs554-server-0   <none>           <none>
pod/cs554-midterm-64fccd9c5-zfhl2   1/1     Running   0          92m   10.42.0.16   k3d-cs554-server-0   <none>           <none>

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE    SELECTOR
service/cs554-midterm   ClusterIP   10.43.197.200   <none>        80/TCP    92m    app=cs554-midterm
service/kubernetes      ClusterIP   10.43.0.1       <none>        443/TCP   116m   <none>
true
NAME            IMAGE               COMMAND                  SERVICE   CREATED       STATUS                 PORTS
compose-web-1   cs554-midterm:1.0   "docker-entrypoint.s…"   web       4 hours ago   Up 4 hours (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
## codex/5-selector-break...origin/main
[Exit code: 0]
```

## Cause And Correction

The Service selector became a query for app=cs554-midterm-typo, but both application Pods still carried app=cs554-midterm. The EndpointSlice controller therefore computed an empty backend set. DNS and the ClusterIP still existed, but kube-proxy had no eligible destination for Service traffic, and a fresh port-forward could not select a matching Pod. Restoring service.yaml corrected that label query; endpoints and both client paths recovered without changing the Deployment or restarting either application process.

## Why Healthy Pods Are Not Enough

Readiness tells Kubernetes that a particular application process can serve requests; it does not validate every route a client might use to reach it. A Service has a separate selector and endpoint set. These Pods remained healthy while the typo excluded all of them, so requests failed before reaching the application. A useful diagnosis must compare Service selectors with Pod labels and inspect EndpointSlices, then test a client path that actually depends on that match. Healthy Pod status alone cannot prove Service connectivity.
