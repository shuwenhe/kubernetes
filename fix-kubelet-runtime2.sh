#!/usr/bin/env bash
# 修复 kubelet 启动失败：移除已废弃的 --container-runtime 参数（适配 v1.30+）
# 适用于使用 containerd 的节点（如 shuwen2）

set -euo pipefail

echo "🛠️ 开始修复 kubelet 启动失败的问题（--container-runtime 已弃用）"

CONF_DIR="/etc/systemd/system/kubelet.service.d"
TARGET_FILE="$CONF_DIR/10-runtime.conf"

# 确保目录存在
if [[ ! -d "$CONF_DIR" ]]; then
  echo "❌ kubelet systemd 配置目录不存在：$CONF_DIR"
  exit 1
fi

# 备份原始配置
if [[ -f "$TARGET_FILE" ]]; then
  cp "$TARGET_FILE" "$TARGET_FILE.bak"
  echo "📦 已备份原文件为：$TARGET_FILE.bak"
fi

# 写入新配置
cat <<EOF | sudo tee "$TARGET_FILE" > /dev/null
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

echo "✅ 已更新 kubelet 启动参数，移除 --container-runtime"

# 重载并重启服务
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# 等待并验证 kubelet 状态
sleep 3
echo "🔍 当前 kubelet 状态："
sudo systemctl --no-pager --full status kubelet | head -n 20

echo "✅ 修复完成。现在可以执行 kubeadm join 重新加入集群。"

