#!/bin/bash
# fix-flannel.sh

echo "🚨 正在删除旧 flannel..."
kubectl delete -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml || true

sleep 5

echo "🧱 重新部署 flannel..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

echo "🔁 重启各节点 kubelet 和 containerd（请手动在每个节点执行以下命令）"
echo "sudo systemctl restart kubelet && sudo systemctl restart containerd"

echo "✅ 请几秒后执行：kubectl get pods -n kube-flannel -o wide"

