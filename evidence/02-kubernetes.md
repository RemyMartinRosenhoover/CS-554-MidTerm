# 02 — Kubernetes Deployment and Service (Part 3)

Must contain:

- [x] Image loading into the cluster: the exact command (for example `kind load docker-image <image>:<tag>`) and proof the node has the image afterwards
- [x] Apply: `kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml`
- [x] Two ready replicas: `kubectl get deploy,rs,pods,svc -o wide` showing `2/2` and both Pods `1/1 Running`
- [x] Service backends: `kubectl get endpointslices -l kubernetes.io/service-name=<service>` showing two endpoints
- [x] Access through the Service: the access method actually used (for example `kubectl port-forward svc/<service> <local>:<port>` plus `curl`), the JSON response, and one sentence on what that method demonstrates and does not demonstrate (port forwarding can pin requests to a single Pod)
- [x] Optional but recommended: an in-cluster request by Service DNS name from `k8s/client-pod.yaml`, which exercises the Service's selector and load balancing
- [x] Pod replacement: `kubectl delete pod <one-pod>`, then `kubectl get pods -w` (or repeated `get pods`) showing the old Pod terminating, a new Pod with a new name appearing, and the return to two ready replicas; `kubectl get rs` showing desired/current/ready; `kubectl describe deploy <name>` events
- [x] Counter note: `GET /` against the replacement Pod shows a fresh count (process-local state did not survive)
- [x] Cleanup: `kubectl delete -f k8s/service.yaml -f k8s/deployment.yaml`

## Captures

### Create the cluster

VM/cluster over SSH at 2026-10-18T13:35:41.5485714-05:00. k3d containers run inside cs554-vm, inside VMware Workstation on the Windows host. The k3s image is pinned; colored log output is retained as captured.

```text
$ k3d cluster create cs554 --image rancher/k3s:v1.37.1-k3s1 --servers 1 --agents 0
[36mINFO[0m[0000] Prep: Network                                
[36mINFO[0m[0000] Created network 'k3d-cs554'                  
[36mINFO[0m[0000] Created image volume k3d-cs554-images        
[36mINFO[0m[0000] Starting new tools node...                   
[36mINFO[0m[0000] Pulling image 'ghcr.io/k3d-io/k3d-tools:5.9.0' 
[36mINFO[0m[0001] Creating node 'k3d-cs554-server-0'           
[36mINFO[0m[0001] Pulling image 'rancher/k3s:v1.37.1-k3s1'     
[36mINFO[0m[0002] Starting node 'k3d-cs554-tools'              
[36mINFO[0m[0008] Creating LoadBalancer 'k3d-cs554-serverlb'   
[36mINFO[0m[0009] Pulling image 'ghcr.io/k3d-io/k3d-proxy:5.9.0' 
[36mINFO[0m[0012] Using the k3d-tools node to gather environment information 
[36mINFO[0m[0012] HostIP: using network gateway 172.19.0.1 address 
[36mINFO[0m[0012] Starting cluster 'cs554'                     
[36mINFO[0m[0012] Starting servers...                          
[36mINFO[0m[0012] Starting node 'k3d-cs554-server-0'           
[36mINFO[0m[0015] All agents already running.                  
[36mINFO[0m[0015] Starting helpers...                          
[36mINFO[0m[0015] Starting node 'k3d-cs554-serverlb'           
[36mINFO[0m[0022] Injecting records for hostAliases (incl. host.k3d.internal) and for 2 network members into CoreDNS configmap... 
[36mINFO[0m[0024] Cluster 'cs554' created successfully!        
[36mINFO[0m[0024] You can now use it like this:                
kubectl cluster-info
```

### Cluster and compatible versions

VM/cluster over SSH at 2026-10-18T13:38:24.2289334-05:00. The single server node is Ready, with client 1.37.1 and server 1.37.1+k3s1.

```text
$ kubectl cluster-info && kubectl get nodes -o wide && kubectl version
Kubernetes control plane is running at https://0.0.0.0:41579
CoreDNS is running at https://0.0.0.0:41579/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:41579/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
NAME                 STATUS   ROLES           AGE     VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE           KERNEL-VERSION              CONTAINER-RUNTIME
k3d-cs554-server-0   Ready    control-plane   2m27s   v1.37.1+k3s1   172.19.0.2    <none>        K3s v1.37.1+k3s1   6.8.0-147-generic (amd64)   containerd://2.3.4-k3s1
Client Version: v1.37.1
Kustomize Version: v5.8.1
Server Version: v1.37.1+k3s1
```

### Manifest client dry-run

VM/cluster over SSH at 2026-10-18T13:38:32.4687699-05:00. All four manifests validate; the duplicate Service output is a dry-run of the working and broken variants, not an apply.

```text
$ cd /home/student/CS-554-MidTerm && kubectl apply --dry-run=client -f k8s/
pod/client created (dry run)
deployment.apps/cs554-midterm created (dry run)
service/cs554-midterm created (dry run)
service/cs554-midterm created (dry run)
```

### Import the same application image

VM/cluster over SSH at 2026-10-18T13:41:58.6540992-05:00. k3d imports the image built for Compose; crictl proves it is present on the node. k3d removes its temporary import tarball. No archive is committed.

```text
$ k3d image import cs554-midterm:1.0 -c cs554 && docker exec k3d-cs554-server-0 crictl images | grep cs554-midterm
[36mINFO[0m[0000] Importing image(s) into cluster 'cs554'      
[36mINFO[0m[0000] Starting new tools node...                   
[36mINFO[0m[0000] Starting node 'k3d-cs554-tools'              
[36mINFO[0m[0000] Saving 1 image(s) from runtime...            
[36mINFO[0m[0001] Importing images into nodes...               
[36mINFO[0m[0001] Importing images from tarball '/k3d/images/k3d-cs554-images-20261018184159.tar' into node 'k3d-cs554-server-0'... 
[36mINFO[0m[0004] Removing the tarball(s) from image volume... 
[36mINFO[0m[0005] Removing k3d-tools node...                   
[36mINFO[0m[0005] Successfully imported image(s)               
[36mINFO[0m[0005] Successfully imported 1 image(s) into 1 cluster(s) 
docker.io/library/cs554-midterm              1.0                     e83fcacd399fd       60.7MB
```

### CI schema validation

VM/cluster over SSH at 2026-10-18T13:41:59.9563488-05:00. The unchanged CI kubeconform invocation validates all four resources, with no skipped schema.

```text
$ docker run --rm -v /home/student/CS-554-MidTerm/k8s:/k8s:ro ghcr.io/yannh/kubeconform:latest -strict -summary -ignore-missing-schemas /k8s
Unable to find image 'ghcr.io/yannh/kubeconform:latest' locally
latest: Pulling from yannh/kubeconform
be8b6fa8070b: Pulling fs layer
db0f07ce641d: Pulling fs layer
4e2b705e3bec: Pulling fs layer
4e2b705e3bec: Download complete
4e2b705e3bec: Pull complete
be8b6fa8070b: Download complete
db0f07ce641d: Download complete
db0f07ce641d: Pull complete
be8b6fa8070b: Pull complete
Digest: sha256:faffaf43f95aa6425306e1ab8d6fcad72acb9049158f38e574c085ea1ec0f64e
Status: Downloaded newer image for ghcr.io/yannh/kubeconform:latest
Summary: 4 resources found in 4 files - Valid: 4, Invalid: 0, Errors: 0, Skipped: 0
```

### Apply and two ready replicas

VM/cluster over SSH at 2026-10-18T13:42:18.2301638-05:00. Only Deployment, working Service, and client Pod are applied. The Deployment is 2/2 and both application Pods are 1/1 Running.

```text
$ cd /home/student/CS-554-MidTerm && kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/client-pod.yaml && kubectl rollout status deploy/cs554-midterm --timeout=120s && kubectl wait --for=condition=Ready pod/client --timeout=120s && kubectl get deploy,rs,pods,svc -o wide
deployment.apps/cs554-midterm created
service/cs554-midterm created
pod/client created
Waiting for deployment "cs554-midterm" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "cs554-midterm" rollout to finish: 1 of 2 updated replicas are available...
deployment "cs554-midterm" successfully rolled out
pod/client condition met
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES              SELECTOR
deployment.apps/cs554-midterm   2/2     2            2           7s    web          cs554-midterm:1.0   app=cs554-midterm

NAME                                      DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES              SELECTOR
replicaset.apps/cs554-midterm-64fccd9c5   2         2         2       7s    web          cs554-midterm:1.0   app=cs554-midterm,pod-template-hash=64fccd9c5

NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
pod/client                          1/1     Running   0          7s    10.42.0.11   k3d-cs554-server-0   <none>           <none>
pod/cs554-midterm-64fccd9c5-mkspb   1/1     Running   0          7s    10.42.0.12   k3d-cs554-server-0   <none>           <none>
pod/cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          7s    10.42.0.10   k3d-cs554-server-0   <none>           <none>

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE     SELECTOR
service/cs554-midterm   ClusterIP   10.43.102.231   <none>        80/TCP    7s      app=cs554-midterm
service/kubernetes      ClusterIP   10.43.0.1       <none>        443/TCP   6m29s   <none>
```

### Service backends

VM/cluster over SSH at 2026-10-18T13:42:34.0246023-05:00. The selector matches app=cs554-midterm and the EndpointSlice contains two application addresses on port 8080.

```text
$ kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide && kubectl describe svc cs554-midterm
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS               AGE
cs554-midterm-z5gdp   IPv4          8080    10.42.0.10,10.42.0.12   16s
Name:                     cs554-midterm
Namespace:                default
Labels:                   <none>
Annotations:              <none>
Selector:                 app=cs554-midterm
Type:                     ClusterIP
IP Family Policy:         SingleStack
IP Families:              IPv4
IP:                       10.43.102.231
IPs:                      10.43.102.231
Port:                     <unset>  80/TCP
TargetPort:               http/TCP
Endpoints:                10.42.0.10:8080,10.42.0.12:8080
Session Affinity:         None
Internal Traffic Policy:  Cluster
Events:                   <none>
```

### In-cluster Service requests

VM/cluster over SSH at 2026-10-18T13:48:01.4061737-05:00. Service DNS and ClusterIP routing reach both ndjs4 and mkspb Pod hostnames, with independent counters. This demonstrates ready-backend selection across replicas, not guaranteed round-robin ordering or fairness.

```text
$ kubectl exec client -- sh -c 'for i in 1 2 3 4 5 6; do curl -s http://cs554-midterm/; echo; done'
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-ndjs4","requestCount":1}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-mkspb","requestCount":1}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-mkspb","requestCount":2}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-mkspb","requestCount":3}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-ndjs4","requestCount":2}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-ndjs4","requestCount":3}
```

### VM-local Service port-forward

VM/cluster over SSH at 2026-10-18T13:49:41.8417342-05:00. All three replies come from mkspb. Port-forward uses the Service selector and target port to choose a Pod, then forwards through the API server directly to it; it does not test ClusterIP packet routing or replica distribution. The temporary forwarder is stopped on exit.

```text
$ set -e
kubectl port-forward svc/cs554-midterm 18080:80 > /home/student/cs554-issue4-port-forward.log 2>&1 &
forward_pid=$!
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 30); do
    if grep -q 'Forwarding from' /home/student/cs554-issue4-port-forward.log; then break; fi
    sleep 1
done
for i in 1 2 3; do
    curl -fsS http://127.0.0.1:18080/
    printf '\n'
done
cat /home/student/cs554-issue4-port-forward.log
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-mkspb","requestCount":4}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-mkspb","requestCount":5}
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-mkspb","requestCount":6}
Forwarding from 127.0.0.1:18080 -> 8080
Forwarding from [::1]:18080 -> 8080
Handling connection for 18080
Handling connection for 18080
Handling connection for 18080
```

### Deployed resources and readiness

VM/cluster over SSH at 2026-10-18T13:53:39.8767564-05:00. Requests 50m/64Mi and limits 250m/128Mi differ, giving Burstable QoS. The /health readiness probe has the requested timing and default 1-second timeout; no liveness probe is configured. Readiness controls traffic eligibility, not process restart.

```text
$ kubectl get deploy cs554-midterm -o jsonpath='{.spec.template.spec.containers[0].resources}'
printf '\n'
kubectl get deploy cs554-midterm -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'
printf '\n'
kubectl describe pod cs554-midterm-64fccd9c5-mkspb
{"limits":{"cpu":"250m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}
{"failureThreshold":2,"httpGet":{"path":"/health","port":"http","scheme":"HTTP"},"initialDelaySeconds":2,"periodSeconds":5,"successThreshold":1,"timeoutSeconds":1}
Name:             cs554-midterm-64fccd9c5-mkspb
Namespace:        default
Priority:         0
Service Account:  default
Node:             k3d-cs554-server-0/172.19.0.2
Start Time:       Sun, 18 Oct 2026 18:42:18 +0000
Labels:           app=cs554-midterm
                  pod-template-hash=64fccd9c5
                  tier=web
Annotations:      <none>
Status:           Running
IP:               10.42.0.12
IPs:
  IP:           10.42.0.12
Controlled By:  ReplicaSet/cs554-midterm-64fccd9c5
Containers:
  web:
    Container ID:   containerd://88faa3019334de3b3277cd4c4bfb4671f0d852773ac69730f0f7b20479d64f62
    Image:          cs554-midterm:1.0
    Image ID:       sha256:e83fcacd399fdb9c32dc39968b45fdf1a4dab58f3563cefc5c596e9463b0a46e
    Port:           8080/TCP (http)
    Host Port:      0/TCP (http)
    State:          Running
      Started:      Sun, 18 Oct 2026 18:42:19 +0000
    Ready:          True
    Restart Count:  0
    Limits:
      cpu:     250m
      memory:  128Mi
    Requests:
      cpu:      50m
      memory:   64Mi
    Readiness:  http-get http://:http/health delay=2s timeout=1s period=5s successThreshold=1 failureThreshold=2
    Environment:
      PORT:          8080
      SERVICE_NAME:  cs554-k8s
      MESSAGE:       Hello from Kubernetes inside the VM
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-vgq7s (ro)
Conditions:
  Type                        Status
  PodReadyToStartContainers   True 
  Initialized                 True 
  Ready                       True 
  ContainersReady             True 
  PodScheduled                True 
Volumes:
  kube-api-access-vgq7s:
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
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  11m   default-scheduler  Successfully assigned default/cs554-midterm-64fccd9c5-mkspb to k3d-cs554-server-0
  Normal  Pulled     11m   kubelet            spec.containers{web}: Container image "cs554-midterm:1.0" already present on machine and can be accessed by the pod
  Normal  Created    11m   kubelet            spec.containers{web}: Container created
  Normal  Started    11m   kubelet            spec.containers{web}: Container started
```

### Automatic Pod replacement

VM/cluster over SSH at 2026-10-18T13:54:10.2938877-05:00. The old mkspb Pod is Terminating while new 2jmll is ContainerCreating, then Running at 3 seconds and ready at 6 seconds. ReplicaSet reconciliation restores desired/current/ready 2 and records SuccessfulCreate; it creates a new Pod automatically, unlike the earlier explicit Compose restart of the same container process.

```text
$ set -e
kubectl get pods -l app=cs554-midterm -o wide
kubectl delete pod cs554-midterm-64fccd9c5-mkspb --wait=false
for i in $(seq 1 10); do
    date --iso-8601=seconds
    kubectl get pods -l app=cs554-midterm -o wide
    sleep 3
done
kubectl rollout status deploy/cs554-midterm --timeout=120s
kubectl get rs
kubectl describe deploy cs554-midterm
kubectl describe rs cs554-midterm-64fccd9c5
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-mkspb   1/1     Running   0          11m   10.42.0.12   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          11m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
pod "cs554-midterm-64fccd9c5-mkspb" deleted from default namespace
2026-10-18T18:54:10+00:00
NAME                            READY   STATUS              RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   0/1     ContainerCreating   0          0s    <none>       k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-mkspb   1/1     Terminating         0          11m   10.42.0.12   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running             0          11m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:13+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   0/1     Running   0          3s    10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          11m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:16+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          6s    10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          11m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:19+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          9s    10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:22+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          12s   10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:25+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          16s   10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:29+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          19s   10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:32+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          22s   10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:35+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          25s   10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
2026-10-18T18:54:38+00:00
NAME                            READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
cs554-midterm-64fccd9c5-2jmll   1/1     Running   0          28s   10.42.0.13   k3d-cs554-server-0   <none>           <none>
cs554-midterm-64fccd9c5-ndjs4   1/1     Running   0          12m   10.42.0.10   k3d-cs554-server-0   <none>           <none>
deployment "cs554-midterm" successfully rolled out
NAME                      DESIRED   CURRENT   READY   AGE
cs554-midterm-64fccd9c5   2         2         2       12m
Name:                   cs554-midterm
Namespace:              default
CreationTimestamp:      Sun, 18 Oct 2026 18:42:18 +0000
Labels:                 <none>
Annotations:            deployment.kubernetes.io/revision: 1
Selector:               app=cs554-midterm
Replicas:               2 desired | 2 updated | 2 total | 2 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=cs554-midterm
           tier=web
  Containers:
   web:
    Image:      cs554-midterm:1.0
    Port:       8080/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:     250m
      memory:  128Mi
    Requests:
      cpu:      50m
      memory:   64Mi
    Readiness:  http-get http://:http/health delay=2s timeout=1s period=5s successThreshold=1 failureThreshold=2
    Environment:
      PORT:          8080
      SERVICE_NAME:  cs554-k8s
      MESSAGE:       Hello from Kubernetes inside the VM
    Mounts:          <none>
  Volumes:           <none>
  Node-Selectors:    <none>
  Tolerations:       <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Progressing    True    NewReplicaSetAvailable
  Available      True    MinimumReplicasAvailable
OldReplicaSets:  <none>
NewReplicaSet:   cs554-midterm-64fccd9c5 (2/2 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  12m   deployment-controller  Scaled up replica set cs554-midterm-64fccd9c5 from 0 to 2
Name:           cs554-midterm-64fccd9c5
Namespace:      default
Selector:       app=cs554-midterm,pod-template-hash=64fccd9c5
Labels:         app=cs554-midterm
                pod-template-hash=64fccd9c5
                tier=web
Annotations:    deployment.kubernetes.io/desired-replicas: 2
                deployment.kubernetes.io/max-replicas: 3
                deployment.kubernetes.io/revision: 1
Controlled By:  Deployment/cs554-midterm
Replicas:       2 current / 2 desired
Pods Status:    2 Running / 0 Waiting / 0 Succeeded / 0 Failed
Pod Template:
  Labels:  app=cs554-midterm
           pod-template-hash=64fccd9c5
           tier=web
  Containers:
   web:
    Image:      cs554-midterm:1.0
    Port:       8080/TCP (http)
    Host Port:  0/TCP (http)
    Limits:
      cpu:     250m
      memory:  128Mi
    Requests:
      cpu:      50m
      memory:   64Mi
    Readiness:  http-get http://:http/health delay=2s timeout=1s period=5s successThreshold=1 failureThreshold=2
    Environment:
      PORT:          8080
      SERVICE_NAME:  cs554-k8s
      MESSAGE:       Hello from Kubernetes inside the VM
    Mounts:          <none>
  Volumes:           <none>
  Node-Selectors:    <none>
  Tolerations:       <none>
Events:
  Type    Reason            Age   From                   Message
  ----    ------            ----  ----                   -------
  Normal  SuccessfulCreate  12m   replicaset-controller  Created pod: cs554-midterm-64fccd9c5-ndjs4
  Normal  SuccessfulCreate  12m   replicaset-controller  Created pod: cs554-midterm-64fccd9c5-mkspb
  Normal  SuccessfulCreate  31s   replicaset-controller  Created pod: cs554-midterm-64fccd9c5-2jmll
```

### Replacement process counter

VM/cluster over SSH at 2026-10-18T13:55:04.9156544-05:00. The replacement Pod answers its first root request with count 1; process-local state did not survive. This direct Pod request tests the counter, not Service routing.

```text
$ kubectl exec cs554-midterm-64fccd9c5-2jmll -- wget -qO- http://127.0.0.1:8080/
{"service":"cs554-k8s","message":"Hello from Kubernetes inside the VM","hostname":"cs554-midterm-64fccd9c5-2jmll","requestCount":1}
```

### Application cleanup

VM/cluster over SSH at 2026-10-18T13:55:16.1091600-05:00. Only the default kubernetes Service remains; the cluster itself is retained.

```text
$ cd /home/student/CS-554-MidTerm && kubectl delete -f k8s/client-pod.yaml -f k8s/service.yaml -f k8s/deployment.yaml && kubectl get all
pod "client" deleted from default namespace
service "cs554-midterm" deleted from default namespace
deployment.apps "cs554-midterm" deleted from default namespace
NAME                 TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
service/kubernetes   ClusterIP   10.43.0.1    <none>        443/TCP   19m
```

### Final restored state

VM/cluster over SSH at 2026-10-18T13:59:57.5945429-05:00. The three working resources are reapplied and left running with two ready replicas, two endpoints, and the client Pod. Compose remains healthy; the broken Service and readiness experiment are not applied.

```text
$ cd /home/student/CS-554-MidTerm && kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml -f k8s/client-pod.yaml && kubectl rollout status deploy/cs554-midterm --timeout=120s && kubectl wait --for=condition=Ready pod/client --timeout=120s && kubectl get deploy,rs,pods,svc -o wide && kubectl get endpointslices -l kubernetes.io/service-name=cs554-midterm -o wide && docker compose -f compose/compose.yaml ps
deployment.apps/cs554-midterm created
service/cs554-midterm created
pod/client created
Waiting for deployment "cs554-midterm" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "cs554-midterm" rollout to finish: 1 of 2 updated replicas are available...
deployment "cs554-midterm" successfully rolled out
pod/client condition met
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES              SELECTOR
deployment.apps/cs554-midterm   2/2     2            2           6s    web          cs554-midterm:1.0   app=cs554-midterm

NAME                                      DESIRED   CURRENT   READY   AGE   CONTAINERS   IMAGES              SELECTOR
replicaset.apps/cs554-midterm-64fccd9c5   2         2         2       6s    web          cs554-midterm:1.0   app=cs554-midterm,pod-template-hash=64fccd9c5

NAME                                READY   STATUS    RESTARTS   AGE   IP           NODE                 NOMINATED NODE   READINESS GATES
pod/client                          1/1     Running   0          6s    10.42.0.15   k3d-cs554-server-0   <none>           <none>
pod/cs554-midterm-64fccd9c5-qkbzg   1/1     Running   0          6s    10.42.0.14   k3d-cs554-server-0   <none>           <none>
pod/cs554-midterm-64fccd9c5-zfhl2   1/1     Running   0          6s    10.42.0.16   k3d-cs554-server-0   <none>           <none>

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR
service/cs554-midterm   ClusterIP   10.43.197.200   <none>        80/TCP    6s    app=cs554-midterm
service/kubernetes      ClusterIP   10.43.0.1       <none>        443/TCP   24m   <none>
NAME                  ADDRESSTYPE   PORTS   ENDPOINTS               AGE
cs554-midterm-q55pw   IPv4          8080    10.42.0.14,10.42.0.16   6s
NAME            IMAGE               COMMAND                  SERVICE   CREATED       STATUS                 PORTS
compose-web-1   cs554-midterm:1.0   "docker-entrypoint.s…"   web       2 hours ago   Up 2 hours (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
```
