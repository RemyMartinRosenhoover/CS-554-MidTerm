# 02 — Kubernetes Deployment and Service (Part 3)

Must contain:

- [ ] Image loading into the cluster: the exact command (for example `kind load docker-image <image>:<tag>`) and proof the node has the image afterwards
- [ ] Apply: `kubectl apply -f k8s/deployment.yaml -f k8s/service.yaml`
- [ ] Two ready replicas: `kubectl get deploy,rs,pods,svc -o wide` showing `2/2` and both Pods `1/1 Running`
- [ ] Service backends: `kubectl get endpointslices -l kubernetes.io/service-name=<service>` showing two endpoints
- [ ] Access through the Service: the access method actually used (for example `kubectl port-forward svc/<service> <local>:<port>` plus `curl`), the JSON response, and one sentence on what that method demonstrates and does not demonstrate (port forwarding can pin requests to a single Pod)
- [ ] Optional but recommended: an in-cluster request by Service DNS name from `k8s/client-pod.yaml`, which exercises the Service's selector and load balancing
- [ ] Pod replacement: `kubectl delete pod <one-pod>`, then `kubectl get pods -w` (or repeated `get pods`) showing the old Pod terminating, a new Pod with a new name appearing, and the return to two ready replicas; `kubectl get rs` showing desired/current/ready; `kubectl describe deploy <name>` events
- [ ] Counter note: `GET /` against the replacement Pod shows a fresh count (process-local state did not survive)
- [ ] Cleanup: `kubectl delete -f k8s/service.yaml -f k8s/deployment.yaml`

## Captures

TODO
