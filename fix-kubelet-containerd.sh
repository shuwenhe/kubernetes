#!/bin/bash
set -e

echo "🛠️ 开始修复 kubelet + containerd 配置..."

# Step 1: 启动并设置 containerd 开机自启
echo "🚀 启动 containerd 服务..."
sudo systemctl enable containerd --now

# Step 2: 拉取 Kubernetes sandbox 镜像
echo "📦 拉取 sandbox 镜像 (pause:3.9)..."
sudo ctr -n k8s.io images pull registry.aliyuncs.com/google_containers/pause:3.9

# Step 3: 配置 kubelet 使用 containerd 作为 runtime
echo "🔧 配置 kubelet 使用 containerd..."
sudo mkdir -p /etc/systemd/system/kubelet.service.d
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service.d/10-runtime.conf
[Service]
Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
EOF

# Step 4: 重载 systemd 配置并重启 kubelet
echo "♻️ 重启 kubelet 服务..."
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable kubelet
sudo systemctl restart kubelet

# Step 5: 显示 kubelet 当前状态
echo "✅ kubelet 当前状态如下："
sudo systemctl status kubelet --no-pager

echo "🎉 修复完成！请在主节点运行 'kubectl get nodes' 检查该节点状态是否为 Ready。"

