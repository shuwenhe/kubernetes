#!/bin/bash
# restart-all-nodes.sh - 自动重启集群中所有节点的 kubelet 和 containerd

# 节点 IP 列表（排除主节点可选）
NODES=(
  "192.168.10.3"  # shuwen2
  "192.168.10.4"  # shuwen3
)

USERNAME="shuwen1"

echo "🚀 正在重启 kubelet 和 containerd 服务（远程节点）..."

for ip in "${NODES[@]}"; do
  echo "🔧 连接 $ip ..."
  ssh "${USERNAME}@${ip}" "sudo systemctl restart containerd && sudo systemctl restart kubelet"
  if [ $? -eq 0 ]; then
    echo "✅ $ip 重启成功"
  else
    echo "❌ $ip 重启失败，请检查 SSH 连接或权限"
  fi
done

echo "🎉 所有节点已处理完毕"

