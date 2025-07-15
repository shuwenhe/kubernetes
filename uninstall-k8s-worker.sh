#!/bin/bash

echo "🧹 开始卸载 Kubernetes Worker 节点..."

# Step 1: Reset kubeadm 状态
echo "👉 重置 kubeadm..."
sudo kubeadm reset -f

# Step 2: 停止 kubelet 服务
echo "🛑 停止并禁用 kubelet 服务..."
sudo systemctl stop kubelet
sudo systemctl disable kubelet

# Step 3: 删除配置与数据目录
echo "🗑️ 删除 Kubernetes 相关配置和数据目录..."
sudo rm -rf /etc/kubernetes \
             /var/lib/kubelet \
             /var/lib/etcd \
             /etc/cni \
             /opt/cni \
             /var/lib/cni \
             $HOME/.kube

# Step 4: 卸载 kube 组件
echo "🧼 卸载 kubeadm, kubelet, kubectl..."
sudo apt-get purge -y kubeadm kubelet kubectl
sudo apt-get autoremove -y

# Step 5: 可选卸载 containerd
echo "❓ 是否同时卸载 containerd？(y/n)"
read -r uninstall_containerd
if [[ "$uninstall_containerd" == "y" || "$uninstall_containerd" == "Y" ]]; then
    echo "🗑️ 卸载 containerd..."
    sudo systemctl stop containerd
    sudo apt-get purge -y containerd
    sudo rm -rf /etc/containerd /var/lib/containerd /run/containerd
fi

# Step 6: 可选清理网络与 iptables
echo "❓ 是否清除 CNI 网络接口与 iptables 规则？(y/n)"
read -r clean_net
if [[ "$clean_net" == "y" || "$clean_net" == "Y" ]]; then
    echo "🌐 清理 CNI 网络与 iptables..."
    sudo iptables -F
    sudo iptables -t nat -F
    sudo iptables -t mangle -F
    sudo ip link delete cni0 2>/dev/null || true
    sudo ip link delete flannel.1 2>/dev/null || true
fi

echo "✅ Kubernetes Worker 卸载完成。"

