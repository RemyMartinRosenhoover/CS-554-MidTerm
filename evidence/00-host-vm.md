# 00 — Host, VM, and tool versions

Must contain:

- [x] VM facts: Linux distribution and version, vCPU, RAM, disk, VMware Workstation networking mode (NAT or bridged) — `cat /etc/os-release`, `nproc`, `free -h`, `df -h /`
- [x] VM address as seen from inside: `ip -4 addr` (the interface on the VMware network)
- [x] Host side of the same network: the VMnet8 (NAT) or bridged adapter address from `ipconfig` (scrub hostname and username)
- [x] Docker Engine and Compose versions inside the VM: `docker version`, `docker compose version`
- [x] Kubernetes distribution and version, and a one-sentence statement of where the cluster runs relative to the host and the VM: `kubectl version`, plus `kind version` or `k3s --version` as applicable
- [x] A first host → VM reachability check (ping or an SSH session banner), before any service exists

## Captures

The cluster will run inside `cs554-vm` as k3d-managed Docker containers. The installed k3d reports default k3s `v1.35.5-k3s1`; kubectl is `v1.37.1`. No Kubernetes cluster exists yet, so these are installed client/default versions, not a live server version. Choose compatible client/server versions during cluster creation.

### VM facts and installed tools

Observed inside `cs554-vm` at 2026-10-18T07:04:49+00:00, before any service, application image or cluster exists. VMware NAT (VMnet8) is the configured networking mode; guest IP is assigned by DHCP. The virtual disk is 25 GiB and the root filesystem approximately 24 GiB.

```text

$ date -Is
2026-10-18T07:04:49+00:00

$ cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.5 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
UBUNTU_CODENAME=noble
LOGO=ubuntu-logo

$ hostname
cs554-vm

$ nproc
2

$ free -h
               total        used        free      shared  buff/cache   available
Mem:           3.8Gi       505Mi       2.4Gi       1.2Mi       1.1Gi       3.3Gi
Swap:             0B          0B          0B

$ lsblk -b -o NAME,SIZE,TYPE
NAME           SIZE TYPE
fd0            4096 disk
sda     26843545600 disk
├─sda1  25768738304 part
├─sda14     4194304 part
├─sda15   111149056 part
└─sda16   957350400 part
sr0      1073741312 rom

$ df -h /
Filesystem      Size  Used Avail Use% Mounted on
/dev/sda1        24G  2.4G   21G  11% /

$ ip -4 addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: ens192: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    altname enp11s0
    inet 192.168.197.134/24 metric 100 brd 192.168.197.255 scope global dynamic ens192
       valid_lft 1509sec preferred_lft 1509sec
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever

$ cloud-init status --long
status: done
extended_status: done
boot_status_code: enabled-by-generator
last_update: Thu, 01 Jan 1970 00:00:40 +0000
detail: DataSourceVMware [seed=guestinfo]
errors: []
recoverable_errors: {}

$ docker version
Client:
 Version:           29.1.3
 API version:       1.52
 Go version:        go1.24.4
 Git commit:        29.1.3-0ubuntu3~24.04.2
 Built:             Wed Apr 29 16:41:06 2026
 OS/Arch:           linux/amd64
 Context:           default

Server:
 Engine:
  Version:          29.1.3
  API version:      1.52 (minimum version 1.44)
  Go version:       go1.24.4
  Git commit:       29.1.3-0ubuntu3~24.04.2
  Built:            Wed Apr 29 16:41:06 2026
  OS/Arch:          linux/amd64
  Experimental:     false
 containerd:
  Version:          2.2.1
  GitCommit:        
 runc:
  Version:          1.3.4-0ubuntu1~24.04.1
  GitCommit:        
 docker-init:
  Version:          0.19.0
  GitCommit:        

$ docker compose version
Docker Compose version 2.40.3+ds1-0ubuntu1~24.04.1

$ kubectl version --client
Client Version: v1.37.1
Kustomize Version: v5.8.1

$ k3d version
k3d version v5.9.0
k3s version v1.35.5-k3s1 (default)

$ k3d cluster list
NAME   SERVERS   AGENTS   LOADBALANCER

$ docker ps -a
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES

$ docker image ls
IMAGE   ID             DISK USAGE   CONTENT SIZE   EXTRA

$ sudo grep selected-first-boot-lines /var/log/cloud-init-output.log
Cloud-init v. 26.1-0ubuntu1~24.04.1 running 'init-local' at Sun, 18 Oct 2026 06:59:55 +0000. Up 9.20 seconds.
Cloud-init v. 26.1-0ubuntu1~24.04.1 running 'init' at Sun, 18 Oct 2026 06:59:57 +0000. Up 11.28 seconds.
Cloud-init v. 26.1-0ubuntu1~24.04.1 running 'modules:config' at Sun, 18 Oct 2026 06:59:59 +0000. Up 12.86 seconds.
Cloud-init v. 26.1-0ubuntu1~24.04.1 running 'modules:final' at Sun, 18 Oct 2026 07:00:01 +0000. Up 14.66 seconds.
CS554 cloud-init finished after 40.95 seconds

```

### Host side of VMnet8

Observed on the Windows host on 2026-10-18 at about 02:06 -05:00. Only the VMnet8 adapter was selected.

```text
$ ipconfig | Select-String -Pattern 'Ethernet adapter VMware Network Adapter VMnet8:' -Context 0,5

> Ethernet adapter VMware Network Adapter VMnet8:
  
     Connection-specific DNS Suffix  . : 
     Link-local IPv6 Address . . . . . : fe80::15c3:c500:d98b:8785%20
     IPv4 Address. . . . . . . . . . . : 192.168.197.1
     Subnet Mask . . . . . . . . . . . : 255.255.255.0



```

### Host to VM reachability

Observed on the Windows host on 2026-10-18 at about 02:05 -05:00. SSH key login also succeeded and returned cloud-init status done plus hostname cs554-vm; no application service was deployed.

```text
$ Test-NetConnection 192.168.197.134 -Port 22 | Select-Object RemoteAddress, RemotePort, TcpTestSucceeded


RemoteAddress    : 192.168.197.134
RemotePort       : 22
TcpTestSucceeded : True




```
