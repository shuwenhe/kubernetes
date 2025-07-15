#!/usr/bin/env bash
# 自动配置 Kubernetes 节点服务自启
# 适用于所有节点：Master + Worker

set -euo pipefail

echo "🟢 启用 containerd 和 kubelet 开机自启..."
sudo systemctl enable containerd
sudo systemctl enable kubelet

echo "🔄 重启 containerd 和 kubelet..."
sudo systemctl restart containerd
sudo systemctl restart kubelet

echo "✅ containerd 和 kubelet 设置完毕。"

# 记录当前节点信息
echo "🖥️ 节点名: $(hostname)"
echo "📦 容器运行时: $(which containerd)"
echo "🔧 Kubelet 状态:"
sudo systemctl status kubelet | grep Active

echo "✅ [01-enable-k8s-autostart.sh] 已完成。"

