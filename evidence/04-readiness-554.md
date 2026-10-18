# 04 — Resource settings and readiness experiment (CS 554)

Must contain:

- [x] The container's `resources` (requests and limits) and `readinessProbe` as deployed: the relevant excerpt of `kubectl get deploy <name> -o yaml`
- [x] Baseline: both Pods `1/1 Running` and Ready; the Service's EndpointSlice showing two endpoints with `ready: true` (`kubectl get endpointslices -l kubernetes.io/service-name=<service> -o yaml`)
- [x] The per-Pod readiness toggle, exactly as applied to **one** Pod (the documented application-level toggle or a per-Pod change), with the command used. The Deployment template is not modified. The Pod is not deleted or crashed.
- [x] Failure state: `kubectl get pods` showing that Pod `0/1 Running` with `RESTARTS 0` (process still running) and the other Pod `1/1`; `kubectl describe pod <pod>` events showing the readiness probe failing; the EndpointSlice showing that endpoint `ready: false` while the other stays `ready: true`
- [x] Traffic eligibility, tested from inside the cluster: requests by Service DNS name from `k8s/client-pod.yaml` (a loop of `curl` calls) showing only the ready Pod's hostname in responses
- [x] Recovery: the toggle reverted; that Pod back to `1/1`; the EndpointSlice showing both endpoints `ready: true`; in-cluster requests reaching both Pods again
- [x] A closing line confirming every temporary change was restored

## Captures

### Service tests

VM/cluster over SSH at 2026-10-18T16:49:07.2645429-05:00. Both the original test and one added file-toggle test pass in Node 22; GET / counter behavior is unchanged.

```text
$ cd /home/student/CS-554-MidTerm && docker run --rm -v /home/student/CS-554-MidTerm/app:/app:ro -w /app node:22-alpine npm test

> cs454-midterm-starter@1.0.0 test
> node --test test/service.test.js

TAP version 13
# {"method":"GET","path":"/","status":200}
# {"method":"GET","path":"/health","status":200}
# {"method":"GET","path":"/","status":200}
# {"method":"GET","path":"/missing","status":404}
# {"method":"GET","path":"/","status":200}
# Subtest: configured responses, local counter, health, and fresh instance
ok 1 - configured responses, local counter, health, and fresh instance
  ---
  duration_ms: 63.330202
  type: 'test'
  ...
# {"method":"GET","path":"/health","status":503}
# {"method":"GET","path":"/","status":200}
# {"method":"GET","path":"/health","status":200}
# {"method":"GET","path":"/","status":200}
# {"method":"GET","path":"/health","status":503}
# {"method":"GET","path":"/","status":200}
# Subtest: readiness file toggles health without resetting the root counter
ok 2 - readiness file toggles health without resetting the root counter
  ---
  duration_ms: 15.925911
  type: 'test'
  ...
1..2
# tests 2
# suites 0
# pass 2
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 134.216999
[Exit code: 0]
```

### Build image 1.1

VM/cluster over SSH at 2026-10-18T17:01:09.2297273-05:00. The unchanged Dockerfile builds the additive readiness toggle. Earlier 1.0 image is retained; the legacy-builder warning is captured verbatim.

```text
$ cd /home/student/CS-554-MidTerm && docker build -t cs554-midterm:1.1 app && docker image ls cs554-midterm
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/

Sending build context to Docker daemon   7.68kB

Step 1/7 : FROM node:22-alpine
 ---> 0a7108bf6c7b
Step 2/7 : WORKDIR /app
 ---> Using cache
 ---> cc03e6e6feb2
Step 3/7 : COPY package.json ./
 ---> Using cache
 ---> eb83e0838b20
Step 4/7 : COPY src ./src
 ---> 513820016bf4
Step 5/7 : USER node
 ---> Running in 097914a9f660
 ---> Removed intermediate container 097914a9f660
 ---> 05f669bfc7b9
Step 6/7 : EXPOSE 8080
 ---> Running in f45928521d63
 ---> Removed intermediate container f45928521d63
 ---> b6aa6ae4347c
Step 7/7 : CMD ["node", "src/server.js"]
 ---> Running in f7082c1eb1f1
 ---> Removed intermediate container f7082c1eb1f1
 ---> 668d84e326e5
Successfully built 668d84e326e5
Successfully tagged cs554-midterm:1.1
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE               ID             DISK USAGE   CONTENT SIZE   EXTRA
cs554-midterm:1.0   90066b40b204        238MB         60.7MB   U    
cs554-midterm:1.1   668d84e326e5        238MB         60.7MB        
[Exit code: 0]
```

### Compose upgrade

VM/cluster over SSH at 2026-10-18T17:06:45.4935345-05:00. Compose rolls to 1.1 and both endpoints succeed; READINESS_FILE is unset, preserving the original health behavior.

```text
$ set -e
cd /home/student/CS-554-MidTerm/compose
docker compose config
docker compose up -d
docker compose up -d --wait --wait-timeout 90
docker compose ps
curl -sS --max-time 5 http://localhost:8080/
printf '\n'
curl -i --max-time 5 http://localhost:8080/health
docker compose exec -T web sh -c 'if [ -z "${READINESS_FILE:-}" ]; then echo READINESS_FILE=unset; else exit 1; fi'
name: compose
services:
  web:
    build:
      context: /home/student/CS-554-MidTerm/app
      dockerfile: Dockerfile
    environment:
      MESSAGE: Hello from Compose inside the VM
      PORT: "8080"
      SERVICE_NAME: cs554-compose
    healthcheck:
      test:
        - CMD
        - wget
        - -qO-
        - http://127.0.0.1:8080/health
      timeout: 3s
      interval: 10s
      retries: 3
    image: cs554-midterm:1.1
    networks:
      default: null
    ports:
      - mode: ingress
        target: 8080
        published: "8080"
        protocol: tcp
    restart: unless-stopped
networks:
  default:
    name: compose_default
 Container compose-web-1  Recreate
 Container compose-web-1  Recreated
 Container compose-web-1  Starting
 Container compose-web-1  Started
 Container compose-web-1  Running
 Container compose-web-1  Waiting
 Container compose-web-1  Healthy
NAME            IMAGE               COMMAND                  SERVICE   CREATED          STATUS                    PORTS
compose-web-1   cs554-midterm:1.1   "docker-entrypoint.s…"   web       10 seconds ago   Up 10 seconds (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"9577b9f64fc0","requestCount":1}
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100    15    0    15    0     0   6195      0 --:--:-- --:--:-- --:--:--  7500
HTTP/1.1 200 OK
Content-Type: application/json
Date: Sun, 18 Oct 2026 22:06:56 GMT
Connection: keep-alive
Keep-Alive: timeout=5
Transfer-Encoding: chunked

{"status":"ok"}READINESS_FILE=unset
[Exit code: 0]
```

### Import the same image into k3d

VM/cluster over SSH at 2026-10-18T17:07:43.9335186-05:00. Image 1.1 is imported into the existing cluster and confirmed on the node; k3d removes its temporary import archive.

```text
$ k3d image import cs554-midterm:1.1 -c cs554 && docker exec k3d-cs554-server-0 crictl images | grep cs554-midterm
[36mINFO[0m[0000] Importing image(s) into cluster 'cs554'      
[36mINFO[0m[0000] Starting new tools node...                   
[36mINFO[0m[0000] Starting node 'k3d-cs554-tools'              
[36mINFO[0m[0000] Saving 1 image(s) from runtime...            
[36mINFO[0m[0001] Importing images into nodes...               
[36mINFO[0m[0001] Importing images from tarball '/k3d/images/k3d-cs554-images-20261018220744.tar' into node 'k3d-cs554-server-0'... 
[36mINFO[0m[0002] Removing the tarball(s) from image volume... 
[36mINFO[0m[0003] Removing k3d-tools node...                   
[36mINFO[0m[0003] Successfully imported image(s)               
[36mINFO[0m[0003] Successfully imported 1 image(s) into 1 cluster(s) 
docker.io/library/cs554-midterm              1.0                     e83fcacd399fd       60.7MB
docker.io/library/cs554-midterm              1.1                     8a1443ab27b9c       60.7MB
[Exit code: 0]
```

### Manifest validation

VM/cluster over SSH at 2026-10-18T17:07:45.2475531-05:00. Client dry-run and the unchanged CI kubeconform invocation pass; readiness probe/resources and Service manifests are unchanged.

```text
$ cd /home/student/CS-554-MidTerm && kubectl apply --dry-run=client -f k8s/deployment.yaml && docker run --rm -v /home/student/CS-554-MidTerm/k8s:/k8s:ro ghcr.io/yannh/kubeconform:latest -strict -summary -ignore-missing-schemas /k8s
deployment.apps/cs554-midterm configured (dry run)
Summary: 4 resources found in 4 files - Valid: 4, Invalid: 0, Errors: 0, Skipped: 0
[Exit code: 0]
```

### Pre-experiment rollout and deployed settings

VM/cluster over SSH at 2026-10-18T17:13:05.2579694-05:00. The image/env/postStart template change is rolled out before baseline. Generation becomes 2. One old terminating Pod appears in this immediate rollout capture; the following stable baseline contains only the two new running Pods. Probe/resources match the earlier configuration.

```text
$ set -e
cd /home/student/CS-554-MidTerm
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deploy/cs554-midterm --timeout=120s
kubectl get pods -l app=cs554-midterm -o wide
kubectl get deploy cs554-midterm -o yaml
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > /home/student/cs554-issue6-deploy-baseline.json
deployment.apps/cs554-midterm configured
Waiting for deployment "cs554-midterm" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "cs554-midterm" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "cs554-midterm" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "cs554-midterm" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "cs554-midterm" rollout to finish: 1 old replicas are pending termination...
Waiting for deployment "cs554-midterm" rollout to finish: 1 old replicas are pending termination...
deployment "cs554-midterm" successfully rolled out
NAME                             READY   STATUS        RESTARTS   AGE     IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-zfhl2    1/1     Terminating   0          3h13m   10.42.0.16   k3d-cs554-server-0   <none>           <none>
cs554-midterm-67c66d7b5d-98k98   1/1     Running       0          6s      10.42.0.18   k3d-cs554-server-0   <none>           <none>
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running       0          12s     10.42.0.17   k3d-cs554-server-0   <none>           <none>
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: "2"
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"name":"cs554-midterm","namespace":"default"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"cs554-midterm"}},"template":{"metadata":{"labels":{"app":"cs554-midterm","tier":"web"}},"spec":{"containers":[{"env":[{"name":"PORT","value":"8080"},{"name":"SERVICE_NAME","value":"cs554-k8s"},{"name":"MESSAGE","value":"Hello from Kubernetes inside the VM"},{"name":"READINESS_FILE","value":"/tmp/ready"}],"image":"cs554-midterm:1.1","imagePullPolicy":"Never","lifecycle":{"postStart":{"exec":{"command":["sh","-c","touch /tmp/ready"]}}},"name":"web","ports":[{"containerPort":8080,"name":"http"}],"readinessProbe":{"failureThreshold":2,"httpGet":{"path":"/health","port":"http"},"initialDelaySeconds":2,"periodSeconds":5,"successThreshold":1},"resources":{"limits":{"cpu":"250m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}}]}}}}
  creationTimestamp: "2026-10-18T18:59:58Z"
  generation: 2
  name: cs554-midterm
  namespace: default
  resourceVersion: "6488"
  uid: 2ae9ee2a-b7bd-4d72-9235-13da39608384
spec:
  progressDeadlineSeconds: 600
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: cs554-midterm
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: cs554-midterm
        tier: web
    spec:
      containers:
      - env:
        - name: PORT
          value: "8080"
        - name: SERVICE_NAME
          value: cs554-k8s
        - name: MESSAGE
          value: Hello from Kubernetes inside the VM
        - name: READINESS_FILE
          value: /tmp/ready
        image: cs554-midterm:1.1
        imagePullPolicy: Never
        lifecycle:
          postStart:
            exec:
              command:
              - sh
              - -c
              - touch /tmp/ready
        name: web
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
        readinessProbe:
          failureThreshold: 2
          httpGet:
            path: /health
            port: http
            scheme: HTTP
          initialDelaySeconds: 2
          periodSeconds: 5
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          limits:
            cpu: 250m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
status:
  availableReplicas: 2
  conditions:
  - lastTransitionTime: "2026-10-18T19:00:04Z"
    lastUpdateTime: "2026-10-18T19:00:04Z"
    message: Deployment has minimum availability.
    reason: MinimumReplicasAvailable
    status: "True"
    type: Available
  - lastTransitionTime: "2026-10-18T18:59:58Z"
    lastUpdateTime: "2026-10-18T22:13:17Z"
    message: ReplicaSet "cs554-midterm-67c66d7b5d" has successfully progressed.
    reason: NewReplicaSetAvailable
    status: "True"
    type: Progressing
  observedGeneration: 2
  readyReplicas: 2
  replicas: 2
  terminatingReplicas: 0
  updatedReplicas: 2
[Exit code: 0]
```

### Both replicas Ready

VM/cluster over SSH at 2026-10-18T17:14:54.6888976-05:00. Both ready EndpointSlice entries and ten Service requests reaching both hostnames establish the baseline. A is 98k98, B is l2ffr. The direct A request is count 4; container identity/start time snapshots are retained.

```text
$ set -e
kubectl get pods -l app=cs554-midterm -o wide
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o yaml
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -sS --max-time 5 http://cs554-midterm/; echo; done' | tee /home/student/cs554-issue6-baseline-traffic.jsonl
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- ls -l /tmp/ready
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- wget -qO- http://127.0.0.1:8080/ | tee /home/student/cs554-issue6-counter-before.json
printf '\n'
kubectl get pods -l app=cs554-midterm -o json | jq -S '[.items[] | {name:.metadata.name,uid:.metadata.uid,containerID:.status.containerStatuses[0].containerID,restarts:.status.containerStatuses[0].restartCount,startedAt:.status.containerStatuses[0].state.running.startedAt}] | sort_by(.name)' > /home/student/cs554-issue6-pods-before.json
cat /home/student/cs554-issue6-pods-before.json
kubectl get deploy cs554-midterm -o jsonpath='{.metadata.generation}'
printf '\n'
NAME                             READY   STATUS    RESTARTS   AGE    IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          104s   10.42.0.18   k3d-cs554-server-0   <none>           <none>
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          110s   10.42.0.17   k3d-cs554-server-0   <none>           <none>
apiVersion: v1
items:
- addressType: IPv4
  apiVersion: discovery.k8s.io/v1
  endpoints:
  - addresses:
    - 10.42.0.17
    conditions:
      ready: true
      serving: true
      terminating: false
    nodeName: k3d-cs554-server-0
    targetRef:
      kind: Pod
      name: cs554-midterm-67c66d7b5d-l2ffr
      namespace: default
      uid: c038ad79-bf80-457b-aa89-d0f4c0f2599c
  - addresses:
    - 10.42.0.18
    conditions:
      ready: true
      serving: true
      terminating: false
    nodeName: k3d-cs554-server-0
    targetRef:
      kind: Pod
      name: cs554-midterm-67c66d7b5d-98k98
      namespace: default
      uid: 7c5511ab-da0c-4b90-8117-d0601cd4dc0f
  kind: EndpointSlice
  metadata:
    annotations:
      endpoints.kubernetes.io/last-change-trigger-time: "2026-10-18T22:13:17Z"
    creationTimestamp: "2026-10-18T18:59:58Z"
    generateName: cs554-midterm-
    generation: 15
    labels:
      endpointslice.kubernetes.io/managed-by: endpointslice-controller.k8s.io
      kubernetes.io/service-name: cs554-midterm
    name: cs554-midterm-q55pw
    namespace: default
    ownerReferences:
    - apiVersion: v1
      blockOwnerDeletion: true
      controller: true
      kind: Service
      name: cs554-midterm
      uid: 827bdb3e-959b-4197-9d8e-4116818b8da7
    resourceVersion: "6489"
    uid: 3f9afee3-0f9a-4b66-b00d-decb0096c91a
  ports:
  - name: ""
    port: 8080
    protocol: TCP
kind: List
metadata:
  resourceVersion: ""
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":1}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":1}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":2}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":3}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":4}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":2}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":3}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":5}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":6}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":7}
-rw-r--r--    1 node     node             0 Oct 18 22:13 /tmp/ready
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":4}
[
  {
    "containerID": "containerd://02d61a33087b7fafaeb61010848e6c00a42afae25063de9def9b674a43e901dd",
    "name": "cs554-midterm-67c66d7b5d-98k98",
    "restarts": 0,
    "startedAt": "2026-10-18T22:13:12Z",
    "uid": "7c5511ab-da0c-4b90-8117-d0601cd4dc0f"
  },
  {
    "containerID": "containerd://9d8fa1344f83cec82e721357f1c28add3e15a5586bc342cc0ad4a7f0c9dedf76",
    "name": "cs554-midterm-67c66d7b5d-l2ffr",
    "restarts": 0,
    "startedAt": "2026-10-18T22:13:06Z",
    "uid": "c038ad79-bf80-457b-aa89-d0f4c0f2599c"
  }
]
2
[Exit code: 0]
```

### One NotReady replica keeps running

VM/cluster over SSH at 2026-10-18T17:23:15.2621349-05:00. Only A loses /tmp/ready. It is 0/1 Running with zero restarts, probe HTTP 503, and a successful direct root request with count 5. Its EndpointSlice entry remains listed but ready:false/serving:false, while B stays ready. All ten Service-DNS responses are B; the Deployment UID/generation/spec compare unchanged.

```text
$ set -e
date --iso-8601=seconds
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- rm /tmp/ready
for i in 1 2 3 4 5 6 7; do
    date --iso-8601=seconds
    kubectl get pods -l app=cs554-midterm
    sleep 3
done
kubectl describe pod cs554-midterm-67c66d7b5d-98k98
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- wget -qO- http://127.0.0.1:8080/ | tee /home/student/cs554-issue6-counter-during.json
printf '\n'
set +e
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- wget -qO- http://127.0.0.1:8080/health
health_status=$?
set -e
printf 'health exit=%s\n' "$health_status"
test "$health_status" -ne 0
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o yaml
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -sS --max-time 5 http://cs554-midterm/; echo; done' | tee /home/student/cs554-issue6-failure-traffic.jsonl
jq -s -e 'length == 10 and all(.[]; .hostname == "cs554-midterm-67c66d7b5d-l2ffr")' /home/student/cs554-issue6-failure-traffic.jsonl
kubectl get pods -l app=cs554-midterm -o json | jq -e '[.items[] | select(.metadata.name == "cs554-midterm-67c66d7b5d-98k98")][0] | .status.phase == "Running" and .status.containerStatuses[0].ready == false and .status.containerStatuses[0].restartCount == 0'
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > /home/student/cs554-issue6-deploy-during.json
cmp /home/student/cs554-issue6-deploy-baseline.json /home/student/cs554-issue6-deploy-during.json
printf 'Deployment UID, generation, and template unchanged during failure\n'
2026-10-18T22:23:15+00:00
2026-10-18T22:23:15+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
2026-10-18T22:23:18+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
2026-10-18T22:23:21+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
2026-10-18T22:23:24+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   0/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
2026-10-18T22:23:28+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   0/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
2026-10-18T22:23:31+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   0/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
2026-10-18T22:23:34+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   0/1     Running   0          10m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          10m
Name:             cs554-midterm-67c66d7b5d-98k98
Namespace:        default
Priority:         0
Service Account:  default
Node:             k3d-cs554-server-0/172.19.0.2
Start Time:       Sun, 18 Oct 2026 22:13:11 +0000
Labels:           app=cs554-midterm
                  pod-template-hash=67c66d7b5d
                  tier=web
Annotations:      <none>
Status:           Running
IP:               10.42.0.18
IPs:
  IP:           10.42.0.18
Controlled By:  ReplicaSet/cs554-midterm-67c66d7b5d
Containers:
  web:
    Container ID:   containerd://02d61a33087b7fafaeb61010848e6c00a42afae25063de9def9b674a43e901dd
    Image:          cs554-midterm:1.1
    Image ID:       sha256:8a1443ab27b9cf9663774d9046ab98ab8e12c4e4a78b5cd6cdfd21c7354b5426
    Port:           8080/TCP (http)
    Host Port:      0/TCP (http)
    State:          Running
      Started:      Sun, 18 Oct 2026 22:13:12 +0000
    Ready:          False
    Restart Count:  0
    Limits:
      cpu:     250m
      memory:  128Mi
    Requests:
      cpu:      50m
      memory:   64Mi
    Readiness:  http-get http://:http/health delay=2s timeout=1s period=5s successThreshold=1 failureThreshold=2
    Environment:
      PORT:            8080
      SERVICE_NAME:    cs554-k8s
      MESSAGE:         Hello from Kubernetes inside the VM
      READINESS_FILE:  /tmp/ready
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-sflrz (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       False 
  ContainersReady             False 
  PodScheduled                True 
Volumes:
  kube-api-access-sflrz:
    Type:                    Projected (a volume that contains injected data from multiple sources)
    TokenExpirationSeconds:  3607
    ConfigMapName:           kube-root-ca.crt
    Optional:                false
    DownwardAPI:             true
QoS Class:                   Burstable
Node-Selectors:              <none>
Tolerations:                 node.kubernetes.io/not-ready:NoExecute op=Exists for 300s
                             node.kubernetes.io/unreachable:NoExecute op=Exists for 300s
Events:
  Type     Reason     Age               From               Message
  ----     ------     ----              ----               -------
  Normal   Scheduled  10m               default-scheduler  Successfully assigned default/cs554-midterm-67c66d7b5d-98k98 to k3d-cs554-server-0
  Normal   Pulled     10m               kubelet            spec.containers{web}: Container image "cs554-midterm:1.1" already present on machine and can be accessed by the pod
  Normal   Created    10m               kubelet            spec.containers{web}: Container created
  Normal   Started    10m               kubelet            spec.containers{web}: Container started
  Warning  Unhealthy  5s (x5 over 20s)  kubelet            spec.containers{web}: Readiness probe failed: HTTP probe failed with statuscode: 503
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":5}
wget: server returned error: HTTP/1.1 503 Service Unavailable
command terminated with exit code 1
health exit=1
apiVersion: v1
items:
- addressType: IPv4
  apiVersion: discovery.k8s.io/v1
  endpoints:
  - addresses:
    - 10.42.0.17
    conditions:
      ready: true
      serving: true
      terminating: false
    nodeName: k3d-cs554-server-0
    targetRef:
      kind: Pod
      name: cs554-midterm-67c66d7b5d-l2ffr
      namespace: default
      uid: c038ad79-bf80-457b-aa89-d0f4c0f2599c
  - addresses:
    - 10.42.0.18
    conditions:
      ready: false
      serving: false
      terminating: false
    nodeName: k3d-cs554-server-0
    targetRef:
      kind: Pod
      name: cs554-midterm-67c66d7b5d-98k98
      namespace: default
      uid: 7c5511ab-da0c-4b90-8117-d0601cd4dc0f
  kind: EndpointSlice
  metadata:
    annotations:
      endpoints.kubernetes.io/last-change-trigger-time: "2026-10-18T22:23:22Z"
    creationTimestamp: "2026-10-18T18:59:58Z"
    generateName: cs554-midterm-
    generation: 16
    labels:
      endpointslice.kubernetes.io/managed-by: endpointslice-controller.k8s.io
      kubernetes.io/service-name: cs554-midterm
    name: cs554-midterm-q55pw
    namespace: default
    ownerReferences:
    - apiVersion: v1
      blockOwnerDeletion: true
      controller: true
      kind: Service
      name: cs554-midterm
      uid: 827bdb3e-959b-4197-9d8e-4116818b8da7
    resourceVersion: "6744"
    uid: 3f9afee3-0f9a-4b66-b00d-decb0096c91a
  ports:
  - name: ""
    port: 8080
    protocol: TCP
kind: List
metadata:
  resourceVersion: ""
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":8}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":9}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":10}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":11}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":12}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":13}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":14}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":15}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":16}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":17}
true
true
Deployment UID, generation, and template unchanged during failure
[Exit code: 0]
```

### File restored and process state survives

VM/cluster over SSH at 2026-10-18T17:24:51.8472964-05:00. Touching A restores readiness, both endpoints and both Service hostnames. A direct count 6 continues from 4/5; names, UIDs, container IDs/start times and zero restarts match. Deployment generation stays 2 and the template is unchanged.

```text
$ set -e
date --iso-8601=seconds
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- touch /tmp/ready
for i in 1 2 3 4; do
    date --iso-8601=seconds
    kubectl get pods -l app=cs554-midterm
    sleep 3
done
kubectl wait --for=condition=Ready pod/cs554-midterm-67c66d7b5d-98k98 --timeout=30s
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o yaml
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- wget -qO- http://127.0.0.1:8080/ | tee /home/student/cs554-issue6-counter-after.json
printf '\n'
kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10; do curl -sS --max-time 5 http://cs554-midterm/; echo; done' | tee /home/student/cs554-issue6-recovery-traffic.jsonl
jq -s -e 'length == 10 and ([.[].hostname] | unique | length == 2)' /home/student/cs554-issue6-recovery-traffic.jsonl
kubectl get pods -l app=cs554-midterm -o json | jq -S '[.items[] | {name:.metadata.name,uid:.metadata.uid,containerID:.status.containerStatuses[0].containerID,restarts:.status.containerStatuses[0].restartCount,startedAt:.status.containerStatuses[0].state.running.startedAt}] | sort_by(.name)' > /home/student/cs554-issue6-pods-after.json
cmp /home/student/cs554-issue6-pods-before.json /home/student/cs554-issue6-pods-after.json
printf 'Pod names, UIDs, container IDs, start times, and zero restarts unchanged\n'
kubectl get deploy cs554-midterm -o json | jq -S '{uid:.metadata.uid,generation:.metadata.generation,spec:.spec}' > /home/student/cs554-issue6-deploy-after.json
cmp /home/student/cs554-issue6-deploy-baseline.json /home/student/cs554-issue6-deploy-after.json
kubectl get deploy cs554-midterm -o jsonpath='{.metadata.generation}'
printf '\n'
kubectl exec cs554-midterm-67c66d7b5d-98k98 -- ls -l /tmp/ready
printf 'Every temporary change restored: Pod A readiness file exists again; no template change during the experiment.\n'
2026-10-18T22:24:52+00:00
2026-10-18T22:24:52+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   0/1     Running   0          11m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          11m
2026-10-18T22:24:55+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          11m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          11m
2026-10-18T22:24:58+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          11m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          11m
2026-10-18T22:25:01+00:00
NAME                             READY   STATUS    RESTARTS   AGE
cs554-midterm-67c66d7b5d-98k98   1/1     Running   0          11m
cs554-midterm-67c66d7b5d-l2ffr   1/1     Running   0          11m
pod/cs554-midterm-67c66d7b5d-98k98 condition met
apiVersion: v1
items:
- addressType: IPv4
  apiVersion: discovery.k8s.io/v1
  endpoints:
  - addresses:
    - 10.42.0.17
    conditions:
      ready: true
      serving: true
      terminating: false
    nodeName: k3d-cs554-server-0
    targetRef:
      kind: Pod
      name: cs554-midterm-67c66d7b5d-l2ffr
      namespace: default
      uid: c038ad79-bf80-457b-aa89-d0f4c0f2599c
  - addresses:
    - 10.42.0.18
    conditions:
      ready: true
      serving: true
      terminating: false
    nodeName: k3d-cs554-server-0
    targetRef:
      kind: Pod
      name: cs554-midterm-67c66d7b5d-98k98
      namespace: default
      uid: 7c5511ab-da0c-4b90-8117-d0601cd4dc0f
  kind: EndpointSlice
  metadata:
    annotations:
      endpoints.kubernetes.io/last-change-trigger-time: "2026-10-18T22:24:54Z"
    creationTimestamp: "2026-10-18T18:59:58Z"
    generateName: cs554-midterm-
    generation: 17
    labels:
      endpointslice.kubernetes.io/managed-by: endpointslice-controller.k8s.io
      kubernetes.io/service-name: cs554-midterm
    name: cs554-midterm-q55pw
    namespace: default
    ownerReferences:
    - apiVersion: v1
      blockOwnerDeletion: true
      controller: true
      kind: Service
      name: cs554-midterm
      uid: 827bdb3e-959b-4197-9d8e-4116818b8da7
    resourceVersion: "6801"
    uid: 3f9afee3-0f9a-4b66-b00d-decb0096c91a
  ports:
  - name: ""
    port: 8080
    protocol: TCP
kind: List
metadata:
  resourceVersion: ""
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":6}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":7}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":18}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":19}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":20}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":21}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":8}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":22}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":23}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-l2ffr","requestCount":24}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-67c66d7b5d-98k98","requestCount":9}
true
Pod names, UIDs, container IDs, start times, and zero restarts unchanged
2
-rw-r--r--    1 node     node             0 Oct 18 22:24 /tmp/ready
Every temporary change restored: Pod A readiness file exists again; no template change during the experiment.
[Exit code: 0]
```

### Final restored state

VM/cluster over SSH at 2026-10-18T17:32:20.4232596-05:00. Both readiness files exist, two endpoints are ready, Service health succeeds, counter continuity is verified, and Compose runs the exact built 1.1 image. Every temporary change is restored.

```text
$ set -e
cd /home/student/CS-554-MidTerm
kubectl get deploy cs554-midterm -o json | jq -e '.metadata.generation == 2 and .status.readyReplicas == 2 and .spec.template.spec.containers[0].image == "cs554-midterm:1.1" and .spec.template.spec.containers[0].imagePullPolicy == "Never"'
kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o json | jq -e '[.items[].endpoints[]? | select(.conditions.ready == true)] | length == 2'
for pod in cs554-midterm-67c66d7b5d-98k98 cs554-midterm-67c66d7b5d-l2ffr; do
    kubectl exec "$pod" -- test -f /tmp/ready
done
jq -s -e '.[0].requestCount == 4 and .[1].requestCount == 5 and .[2].requestCount == 6' /home/student/cs554-issue6-counter-before.json /home/student/cs554-issue6-counter-during.json /home/student/cs554-issue6-counter-after.json
kubectl exec client -- curl -fsS --max-time 5 http://cs554-midterm/health
printf '\n'
docker compose -f compose/compose.yaml ps
docker inspect compose-web-1 --format '{{.Config.Image}} {{.Image}}'
docker image inspect cs554-midterm:1.1 --format '{{.Id}}'
docker compose -f compose/compose.yaml --env-file compose/.env.example config --quiet
sha256sum app/src/server.js app/test/service.test.js compose/compose.yaml k8s/deployment.yaml
git status --short --branch
true
true
true
{"status":"ok"}
NAME            IMAGE               COMMAND                  SERVICE   CREATED          STATUS                    PORTS
compose-web-1   cs554-midterm:1.1   "docker-entrypoint.s…"   web       25 minutes ago   Up 25 minutes (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
cs554-midterm:1.1 sha256:668d84e326e5aabeb56553299ef7370d4def3c577e1d4a681900c54026b20421
sha256:668d84e326e5aabeb56553299ef7370d4def3c577e1d4a681900c54026b20421
3233babb9d7dd66bb304a596d2d9b28e47f5612eaa869aa6090fdb884addfeca  app/src/server.js
b31f9afedfffa0ee39f3609fbeb6091eaaf24fe82d313ad3a9d56b5de4d8cb1c  app/test/service.test.js
dc895d1997cd9af86a18ed65d126f98550577b21f6134256f630079a94fdc88c  compose/compose.yaml
025ad236bb816e60c5c1f523963bb38372bb3feb817828af81f0d1ecaffa6590  k8s/deployment.yaml
## codex/6-readiness...origin/main
 M app/src/server.js
 M app/test/service.test.js
 M compose/compose.yaml
 M k8s/deployment.yaml
[Exit code: 0]
```

## Method And Interpretation

A readiness probe in an existing Pod spec is immutable, so a per-Pod probe patch is not supported here. Changing the shared Deployment template would roll replicas and would not isolate one running process. The permitted application-level alternative adds READINESS_FILE only to the existing /health branch: missing file yields 503, present file yields 200, unset variable preserves the original behavior. Kubernetes postStart creates /tmp/ready in each container before the stable baseline. The experiment changes only that file in A, not the Pod or Deployment specification.

Readiness controls whether a running Pod is eligible for Service traffic; it is not a restart instruction. The failed Pod still answered GET / directly and its counter advanced 4 to 5 to 6 across failure and recovery. Its UID, container ID, start timestamp and zero restarts stayed fixed. A remained in the EndpointSlice with ready:false, but was excluded from the ready backend set: all in-cluster Service requests went to B until the file was recreated. No port-forward was used to claim traffic eligibility. The observed requests show backend selection, not guaranteed round-robin behavior.

Every temporary change was restored by recreating /tmp/ready in A. Both replicas and endpoints are Ready, the correct Service remains applied, and both environments are left running on cs554-midterm:1.1. The intentional health failure did not crash, restart, or replace a Pod; Deployment generation stayed 2 throughout the experiment.
