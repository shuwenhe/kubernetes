#!/usr/bin/env bash
# work-auto-start.sh - Kubernetes Worker 节点自动启动&修复脚本
# 适用于：containerd + kubeadm v1.30+ 节点，如 shuwen2

set -euo pipefail

MASTER_IP="${MASTER_IP:-192.168.10.2}"  # 可通过环境变量覆盖
TOKEN="${TOKEN:-}"                     # kubeadm token
DISCOVERY_HASH="${DISCOVERY_HASH:-}"   # sha256 开头的 discovery token hash

echo "🚀 [1/5] 正在修复 kubelet 启动参数..."
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/10-runtime.conf >/dev/null
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart kubelet

sleep 2
if ! systemctl is-active --quiet kubelet; then
  echo "❌ kubelet 启动失败，请检查日志"
  exit 1
fi
echo "✅ kubelet 已启动"

echo "🔍 [2/5] 检查是否已经加入集群..."
if [[ -f /etc/kubernetes/kubelet.conf ]]; then
  echo "✅ 本节点已加入过集群，跳过 join"
  exit 0
fi

if [[ -z "$TOKEN" || -z "$DISCOVERY_HASH" ]]; then
  echo "❌ 未提供 TOKEN 或 HASH，请设置环境变量："
  echo "  export TOKEN=xxx"
  echo "  export DISCOVERY_HASH=sha256:xxx"
  exit 1
fi

echo "🔗 [3/5] 开始加入 Kubernetes 集群：$MASTER_IP ..."
sudo kubeadm reset -f
sudo systemctl restart containerd
sudo systemctl restart kubelet

sudo kubeadm join "$MASTER_IP:6443" \
  --token "$TOKEN" \
  --discovery-token-ca-cert-hash "$DISCOVERY_HASH"

echo "✅ 已成功加入集群"


