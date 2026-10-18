#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
    printf 'Run this script with sudo inside the project VM.\n' >&2
    exit 1
fi
bash "$(dirname "$0")/vm-tls-probe.sh"

# Course exercise-04-local-kubernetes/INSTALL.md: official Kubernetes APT repository.
apt-get update
apt-get install -y ca-certificates curl gnupg
install -d -m 755 /etc/apt/keyrings
if [[ ! -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.37/deb/Release.key \
        | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
fi
chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
printf '%s\n' 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.37/deb/ /' \
    > /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubectl
if ! command -v k3d >/dev/null 2>&1; then
    curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi
usermod -aG docker student
systemctl enable --now docker
docker version
docker compose version
kubectl version --client
k3d version
printf 'Tools provisioned; no service, application image or Kubernetes cluster created.\n'
