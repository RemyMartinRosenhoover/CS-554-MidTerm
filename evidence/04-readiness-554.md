# 04 — Resource settings and readiness experiment (CS 554)

Must contain:

- [ ] The container's `resources` (requests and limits) and `readinessProbe` as deployed: the relevant excerpt of `kubectl get deploy <name> -o yaml`
- [ ] Baseline: both Pods `1/1 Running` and Ready; the Service's EndpointSlice showing two endpoints with `ready: true` (`kubectl get endpointslices -l kubernetes.io/service-name=<service> -o yaml`)
- [ ] The per-Pod readiness toggle, exactly as applied to **one** Pod (the documented application-level toggle or a per-Pod change), with the command used. The Deployment template is not modified. The Pod is not deleted or crashed.
- [ ] Failure state: `kubectl get pods` showing that Pod `0/1 Running` with `RESTARTS 0` (process still running) and the other Pod `1/1`; `kubectl describe pod <pod>` events showing the readiness probe failing; the EndpointSlice showing that endpoint `ready: false` while the other stays `ready: true`
- [ ] Traffic eligibility, tested from inside the cluster: requests by Service DNS name from `k8s/client-pod.yaml` (a loop of `curl` calls) showing only the ready Pod's hostname in responses
- [ ] Recovery: the toggle reverted; that Pod back to `1/1`; the EndpointSlice showing both endpoints `ready: true`; in-cluster requests reaching both Pods again
- [ ] A closing line confirming every temporary change was restored

## Captures

TODO
