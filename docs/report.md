# Technical Report — CS 554 Midterm Mini-Project

**Student:** TODO · **Date:** TODO · **Repository:** https://github.com/RemyMartinRosenhoover/CS-544-MidTerm

> Outline only. Each section is written once its evidence exists. Target length: about two pages for sections 1–4, 500–750 words for section 5, and 200–300 words for section 6. Evidence and references do not count toward length.

## 1. Deployment overview and diagram (Part 2)

TODO. Introduce the four layers (physical host → VM → container → application process), where each environment lives, and refer to `diagram.svg`. The diagram shows the host, the VM, the container, the application, and the path a request takes from the host, with ports and addresses labeled.

## 2. Docker Compose inside the VM: what was observed (Part 2)

TODO. Configuration through environment variables, the published port, requests from inside the VM and from the host (networking mode and forwarding), service status and logs, and what happened to the process-local request counter on restart.

## 3. Kubernetes: Deployment, Service, and Pod replacement (Part 3)

TODO. Where the cluster runs relative to the host and VM; how the image reached it; two ready replicas; what happened when one Pod was deleted; **why** Kubernetes creates a replacement; how that compares with restarting the Compose service; and what the chosen access method does and does not demonstrate (port forwarding versus traffic distribution).

## 4. Controlled troubleshooting: the Service selector (Part 4)

TODO. Working baseline; the exact configuration change; the symptom a client saw; at least two observations (Pod readiness, Pod labels, Service selector, EndpointSlices, forwarding errors, application logs); the cause; the correction; a successful request after recovery; and why healthy application Pods do not, by themselves, prove a client can reach them through a Service.

## 5. OpenStack deployment analysis (Part 5, 500–750 words)

### 5.1 Resources and choices
TODO. Image, flavor, key pair, tenant network/subnet, router to the external network, security group, floating IP. Justify a modest VM size. State what is created versus already supplied by the administrator. Whether persistent block storage is needed for this workload.

### 5.2 Service responsibilities
TODO. Keystone, Glance, Nova, Neutron in authenticating, selecting an image, creating the instance, and providing connectivity. Where Docker Compose fits once the VM exists. Cinder only if proposed, with its purpose.

### 5.3 Request path
TODO. External client → floating IP → router/NAT → security group → VM → published container port → application. Identify the security-group rule for the application port and distinguish it from SSH and optional ICMP.

### 5.4 Failure analysis
TODO. The instance runs but the external client cannot reach the service: a layered sequence of checks separating application/container problems from VM and cloud-network problems, with the evidence collected at each layer.

### 5.5 Operational complexity
TODO. Why operating an OpenStack cloud involves more components and dependencies than deploying into a working cloud, with one example from the class demonstration or troubleshooting discussion, distinguishing an infrastructure setup problem from an application deployment problem.

### Closing comparison
TODO. When a VM with Compose is sufficient, and what additional behavior Kubernetes provided in this experiment.

## 6. CS 554 extension (200–300 words)

TODO. The CPU and memory requests and limits chosen and why; request versus limit; the readiness probe on `/health` and how readiness affects Service traffic versus restarting a container; interpretation of the readiness experiment (baseline, one replica NotReady while running, exclusion from ready endpoints, recovery).

## References

See `references.md`.
