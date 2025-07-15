#!/usr/bin/env bash
# worker-auto-fix-cni.sh - 自动修复 CNI 插件丢失问题

set -euo pipefail

echo "[CNI] 下载并安装 CNI 插件到 /opt/cni/bin"

CNI_VERSION="v1.4.0"
ARCH="amd64"
OS="linux"
CNI_URL="https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-${OS}-${ARCH}-${CNI_VERSION}.tgz"

curl -L "${CNI_URL}" -o cni-plugins.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -xzvf cni-plugins.tgz -C /opt/cni/bin

echo "[CNI] 安装完成，重启 kubelet..."
sudo systemctl restart kubelet

