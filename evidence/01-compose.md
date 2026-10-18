# 01 — Docker Compose inside the VM (Part 2)

Must contain:

- [ ] Image build inside the VM: `docker build -t <image>:<tag> app` and `docker image ls <image>`
- [ ] Resolved configuration showing the environment variables and the published port: `docker compose config`
- [ ] Start: `docker compose up -d`
- [ ] From inside the VM, both endpoints: `curl -s http://localhost:<port>/` (JSON with service name, hostname, count) and `curl -i http://localhost:<port>/health` (HTTP 200)
- [ ] From the host, the same request: `curl.exe http://<vm-address>:<port>/` from PowerShell, with a one-line statement of the VM networking mode and any port forwarding used (none, if the host reaches the VM's NAT or bridged address directly)
- [ ] Status and logs: `docker compose ps`, `docker compose logs` showing the startup line and request lines
- [ ] Counter behavior: several `GET /` requests showing the count climb, then `docker compose restart`, then `GET /` again showing the count reset, and logs showing the new startup line
- [ ] Cleanup: `docker compose down`

## Captures

TODO
