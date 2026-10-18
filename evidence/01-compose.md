# 01 — Docker Compose inside the VM (Part 2)

Must contain:

- [x] Image build inside the VM: `docker build -t <image>:<tag> app` and `docker image ls <image>`
- [x] Resolved configuration showing the environment variables and the published port: `docker compose config`
- [x] Start: `docker compose up -d`
- [x] From inside the VM, both endpoints: `curl -s http://localhost:<port>/` (JSON with service name, hostname, count) and `curl -i http://localhost:<port>/health` (HTTP 200)
- [x] From the host, the same request: `curl.exe http://<vm-address>:<port>/` from PowerShell, with a one-line statement of the VM networking mode and any port forwarding used (none, if the host reaches the VM's NAT or bridged address directly)
- [x] Status and logs: `docker compose ps`, `docker compose logs` showing the startup line and request lines
- [x] Counter behavior: several `GET /` requests showing the count climb, then `docker compose restart`, then `GET /` again showing the count reset, and logs showing the new startup line
- [x] Cleanup: `docker compose down`

## Captures

### Image build

VM over SSH at 2026-10-18T11:32:04.4865489-05:00. Built inside the VM from the unchanged app/Dockerfile. Docker reported a legacy-builder deprecation warning. The PowerShell capture includes a RemoteException text artifact from an empty stderr line; the build exited 0.

```text
$ cd /home/student/CS-554-MidTerm && docker build -t cs554-midterm:1.0 app
DEPRECATED: The legacy builder is deprecated and will be removed in a future release.
            Install the buildx component to build images with BuildKit:
            https://docs.docker.com/go/buildx/
System.Management.Automation.RemoteException
Sending build context to Docker daemon   7.68kB

Step 1/7 : FROM node:22-alpine
22-alpine: Pulling from library/node
d39db1cf9caa: Pulling fs layer
f7f2d304681a: Pulling fs layer
e2de96513ba9: Pulling fs layer
e554276b05e6: Pulling fs layer
15c907cd5cbc: Download complete
707399b387b7: Download complete
d39db1cf9caa: Download complete
e554276b05e6: Download complete
e2de96513ba9: Download complete
e2de96513ba9: Pull complete
f7f2d304681a: Download complete
f7f2d304681a: Pull complete
d39db1cf9caa: Pull complete
e554276b05e6: Pull complete
Digest: sha256:0a7108bf6c7bf5de370ffb1a3ed6be93d405b43ff159f681a8d18c0e2bc2e402
Status: Downloaded newer image for node:22-alpine
 ---> 0a7108bf6c7b
Step 2/7 : WORKDIR /app
 ---> Running in 0671632d0b56
 ---> Removed intermediate container 0671632d0b56
 ---> cc03e6e6feb2
Step 3/7 : COPY package.json ./
 ---> eb83e0838b20
Step 4/7 : COPY src ./src
 ---> 17c2250fdcae
Step 5/7 : USER node
 ---> Running in 24baab191b2a
 ---> Removed intermediate container 24baab191b2a
 ---> 01b71c3bd0f8
Step 6/7 : EXPOSE 8080
 ---> Running in ece835a57e89
 ---> Removed intermediate container ece835a57e89
 ---> 32b52c0e1120
Step 7/7 : CMD ["node", "src/server.js"]
 ---> Running in 8b0bc7460361
 ---> Removed intermediate container 8b0bc7460361
 ---> 90066b40b204
Successfully built 90066b40b204
Successfully tagged cs554-midterm:1.0
```

### Built image tag

VM over SSH at 2026-10-18T11:35:55.1995302-05:00. The image tagged cs554-midterm:1.0 is retained inside the VM for Kubernetes.

```text
$ docker image ls cs554-midterm 2>&1
WARNING: This output is designed for human readability. For machine-readable output, please use --format.
IMAGE               ID             DISK USAGE   CONTENT SIZE   EXTRA
cs554-midterm:1.0   90066b40b204        238MB         60.7MB        
```

### Resolved Compose configuration

VM over SSH at 2026-10-18T11:35:59.1837822-05:00. The real .env was copied from the committed example inside the VM and remains ignored.

```text
$ cd /home/student/CS-554-MidTerm/compose && cp .env.example .env && docker compose config 2>&1
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
    image: cs554-midterm:1.0
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
```

### Start the service

VM over SSH at 2026-10-18T11:36:25.3938744-05:00. Compose created one web service and its network inside the VM.

```text
$ cd /home/student/CS-554-MidTerm/compose && docker compose up -d 2>&1
 Network compose_default  Creating
 Network compose_default  Created
 Container compose-web-1  Creating
 Container compose-web-1  Created
 Container compose-web-1  Starting
 Container compose-web-1  Started
```

### Healthy service status

VM over SSH at 2026-10-18T11:36:46.3477962-05:00. The explicit wait completed successfully before application requests.

```text
$ cd /home/student/CS-554-MidTerm/compose && docker compose up -d --wait --wait-timeout 90 2>&1 && docker compose ps 2>&1
 Container compose-web-1  Running
 Container compose-web-1  Waiting
 Container compose-web-1  Healthy
NAME            IMAGE               COMMAND                  SERVICE   CREATED          STATUS                    PORTS
compose-web-1   cs554-midterm:1.0   "docker-entrypoint.s…"   web       22 seconds ago   Up 21 seconds (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
```

### VM requests and health

VM over SSH at 2026-10-18T11:37:01.7188627-05:00. Counts climb 1, 2, 3; the health endpoint returns HTTP 200. The service emits no trailing newline, so responses run together; raw output is preserved.

```text
$ cd /home/student/CS-554-MidTerm/compose && curl -s http://localhost:8080/ && curl -s http://localhost:8080/ && curl -s http://localhost:8080/ && curl -i http://localhost:8080/health 2>&1
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"864d1c1b9d87","requestCount":1}{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"864d1c1b9d87","requestCount":2}{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"864d1c1b9d87","requestCount":3}  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed

  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0
100    15    0    15    0     0  16759      0 --:--:-- --:--:-- --:--:-- 15000
HTTP/1.1 200 OK
Content-Type: application/json
Date: Sun, 18 Oct 2026 16:37:02 GMT
Connection: keep-alive
Keep-Alive: timeout=5
Transfer-Encoding: chunked

{"status":"ok"}
```

### Windows host request

Windows host at 2026-10-18T11:37:22.5793695-05:00. VMware NAT on VMnet8; direct guest address 192.168.197.134, no port forwarding. The same container returns count 4.

```text
$ curl.exe -s http://192.168.197.134:8080/
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"864d1c1b9d87","requestCount":4}
```

### Windows host health

Windows host at 2026-10-18T11:37:23.4286389-05:00. The host receives HTTP 200. The PowerShell stderr capture contains a RemoteException text artifact on an empty progress line; curl exited 0.

```text
$ curl.exe -i http://192.168.197.134:8080/health
  % Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
System.Management.Automation.RemoteException
  0      0   0      0   0      0      0      0                              0
100     15   0     15   0      0   6105      0                              0
100     15   0     15   0      0   5802      0                              0
100     15   0     15   0      0   5553      0                              0
HTTP/1.1 200 OK
Content-Type: application/json
Date: Sun, 18 Oct 2026 16:37:23 GMT
Connection: keep-alive
Keep-Alive: timeout=5
Transfer-Encoding: chunked

{"status":"ok"}
```

### Startup and request logs

VM over SSH at 2026-10-18T11:37:41.1475130-05:00. Automatic health checks and manual /health requests are logged, but only GET / increments the counter.

```text
$ cd /home/student/CS-554-MidTerm/compose && docker compose logs 2>&1
web-1  | Listening on port 8080
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
```

### Restart and counter reset

VM over SSH at 2026-10-18T11:37:53.2517812-05:00. Count 5 becomes 1 after restarting the process in the same container. Logs include SIGTERM and a new Listening on port 8080 line. Output remains concatenated where the response has no newline.

```text
$ cd /home/student/CS-554-MidTerm/compose && curl -s http://localhost:8080/ && docker compose restart 2>&1 && docker compose up -d --wait --wait-timeout 90 2>&1 && docker compose ps 2>&1 && curl -s http://localhost:8080/ && docker compose logs --since 2m 2>&1
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"864d1c1b9d87","requestCount":5} Container compose-web-1  Restarting
 Container compose-web-1  Started
 Container compose-web-1  Running
 Container compose-web-1  Waiting
 Container compose-web-1  Healthy
NAME            IMAGE               COMMAND                  SERVICE   CREATED              STATUS                    PORTS
compose-web-1   cs554-midterm:1.0   "docker-entrypoint.s…"   web       About a minute ago   Up 10 seconds (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
{"service":"cs554-compose","message":"Hello from Compose inside the VM","hostname":"864d1c1b9d87","requestCount":1}web-1  | Listening on port 8080
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/","status":200}
web-1  | Received SIGTERM; stopping.
web-1  | Listening on port 8080
web-1  | {"method":"GET","path":"/health","status":200}
web-1  | {"method":"GET","path":"/","status":200}
```

### Cleanup demonstration

VM over SSH at 2026-10-18T11:38:37.9624215-05:00. The container and Compose network were removed; ps shows an empty service list.

```text
$ cd /home/student/CS-554-MidTerm/compose && docker compose down 2>&1 && docker compose ps 2>&1
 Container compose-web-1  Stopping
 Container compose-web-1  Stopped
 Container compose-web-1  Removing
 Container compose-web-1  Removed
 Network compose_default  Removing
 Network compose_default  Removed
NAME      IMAGE     COMMAND   SERVICE   CREATED   STATUS    PORTS
```

### Final running state

VM over SSH at 2026-10-18T11:38:49.3921632-05:00. The service was brought back up and left healthy for the walkthrough.

```text
$ cd /home/student/CS-554-MidTerm/compose && docker compose up -d 2>&1 && docker compose up -d --wait --wait-timeout 90 2>&1 && docker compose ps 2>&1
 Network compose_default  Creating
 Network compose_default  Created
 Container compose-web-1  Creating
 Container compose-web-1  Created
 Container compose-web-1  Starting
 Container compose-web-1  Started
 Container compose-web-1  Running
 Container compose-web-1  Waiting
 Container compose-web-1  Healthy
NAME            IMAGE               COMMAND                  SERVICE   CREATED          STATUS                    PORTS
compose-web-1   cs554-midterm:1.0   "docker-entrypoint.s…"   web       11 seconds ago   Up 10 seconds (healthy)   0.0.0.0:8080->8080/tcp, [::]:8080->8080/tcp
```
