#!/bin/bash

echo "[1/6] Resetting kubeadm cluster..."
sudo kubeadm reset -f

echo "[2/6] Stopping and disabling kubelet service..."
sudo systemctl stop kubelet
sudo systemctl disable kubelet

echo "[3/6] Removing Kubernetes packages..."
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni cri-tools
sudo apt-get autoremove -y

echo "[4/6] Removing configuration and data directories..."
sudo rm -rf /etc/kubernetes
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet
sudo rm -rf /etc/cni
sudo rm -rf /opt/cni
sudo rm -rf /var/lib/cni
sudo rm -rf /var/run/flannel
sudo rm -rf ~/.kube
sudo rm -rf /root/.kube

echo "[5/6] Removing CNI network interfaces (if exist)..."
sudo ip link delete cni0 2>/dev/null
sudo ip link delete flannel.1 2>/dev/null

echo "[6/6] Cleaning up containerd Kubernetes containers and images..."
# Delete all running containers created by k8s
sudo ctr -n k8s.io containers list -q | xargs -r sudo ctr -n k8s.io containers delete
# Delete all images pulled for k8s
sudo ctr images list -q | grep -E "k8s.gcr.io|registry.k8s.io" | xargs -r sudo ctr images rm

echo "✅ Kubernetes has been completely uninstalled."

