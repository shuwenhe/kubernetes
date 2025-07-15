#!/bin/bash
set -e

echo "🚨 正在卸载 Kubernetes v1.28.2 组件..."

# Step 1: 停止 kubelet 和 containerd
echo "🛑 停止服务..."
sudo systemctl stop kubelet || true
sudo systemctl disable kubelet || true
sudo systemctl stop containerd || true

# Step 2: kubeadm reset
echo "🧹 kubeadm reset 中..."
sudo kubeadm reset -f || true

# Step 3: 卸载 kubelet、kubeadm、kubectl
echo "❌ 卸载 kubeadm kubelet kubectl..."
sudo apt-get purge -y kubeadm kubelet kubectl
sudo apt-get autoremove -y

# Step 4: 删除相关文件和目录
echo "🗑️ 删除相关目录和配置..."
sudo rm -rf \
  ~/.kube \
  /etc/kubernetes \
  /etc/cni \
  /opt/cni \
  /var/lib/etcd \
  /var/lib/kubelet \
  /var/lib/cni \
  /var/run/kubernetes \
  /etc/systemd/system/kubelet.service.d

# Step 5: 删除网络设备（如有）
echo "🔌 删除 CNI 网络设备..."
sudo ip link delete cni0 2>/dev/null || true
sudo ip link delete flannel.1 2>/dev/null || true

# Step 6: 清理 containerd 残留数据
echo "🧼 清除 containerd 数据（可选）..."
sudo rm -rf /var/lib/containerd

echo "✅ Kubernetes v1.28.2 卸载完成。建议执行 'sudo reboot' 以完全清理。"

