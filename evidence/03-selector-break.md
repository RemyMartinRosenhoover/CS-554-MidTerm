# 03 — Controlled troubleshooting: Service selector (Part 4)

Must contain:

- [ ] Baseline: the Service's selector (`kubectl get svc <service> -o yaml`, selector section), Pod labels (`kubectl get pods --show-labels`), an EndpointSlice with two endpoints, and one successful request through the Service
- [ ] The exact change: `diff k8s/service.yaml k8s/service-broken.yaml`, then `kubectl apply -f k8s/service-broken.yaml`
- [ ] If port forwarding is the access method: the old `port-forward` session stopped and a new one started **after** the change
- [ ] Symptom seen by the client, verbatim: the `curl` error or the `port-forward` error text
- [ ] At least two observations (more is better): Pods still `1/1 Running` and Ready; Pod labels unchanged; the Service selector now mismatched; `kubectl get endpointslices` for the Service showing no endpoints; `kubectl describe svc <service>` showing `Endpoints: <none>`; application logs showing no new request lines
- [ ] Correction: `kubectl apply -f k8s/service.yaml`, the EndpointSlice repopulating, forwarding re-established if used, and a successful request after recovery

## Captures

TODO
