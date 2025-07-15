#!/bin/bash
# fix-flannel-network.sh - 自动清理并修复 Flannel 网络插件，附带状态验证

set -e

NODES=("192.168.10.2" "192.168.10.3")  # 所有节点，包括主节点
USER="shuwen"

echo "🚨 Step 1: 删除旧 Flannel..."
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml || true

echo "🧹 Step 2: 清理每个节点的残留网络配置..."
for ip in "${NODES[@]}"; do
  echo "🔧 清理 $ip..."
  ssh ${USER}@${ip} "sudo rm -rf /run/flannel && sudo rm -rf /etc/cni/net.d/*"
done

echo "🔁 Step 3: 重启 containerd 和 kubelet..."
for ip in "${NODES[@]}"; do
  echo "🔄 重启服务 on $ip..."
  ssh ${USER}@${ip} "sudo systemctl restart containerd && sudo systemctl restart kubelet"
done

echo "🧱 Step 4: 重新部署 flannel 网络插件..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "⏳ 等待 Flannel 启动中（30秒）..."
sleep 30

echo "✅ Step 5: 检查 flannel pod 状态..."
kubectl get pods -n kube-flannel -o wide

echo "🔍 Step 6: 检查每个节点是否生成 /run/flannel/subnet.env ..."
for ip in "${NODES[@]}"; do
  echo -n "📦 节点 $ip: "
  if ssh ${USER}@${ip} "test -f /run/flannel/subnet.env"; then
    echo "✅ 存在"
  else
    echo "❌ 缺失（Flannel 网络未成功启动）"
  fi
done

echo "🎉 修复流程已完成，请确认所有节点 flannel 正常运行，Pod 是否恢复启动。"

