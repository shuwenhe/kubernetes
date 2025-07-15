#!/usr/bin/env bash
# fix-worker.sh - 强制升级 Worker 节点为 v1.33.2 并重新加入集群

set -euo pipefail

K8S_VERSION="v1.33.2"
K8S_VERSION_DEB="${K8S_VERSION#v}-00"
IMAGE_REPO="registry.cn-hangzhou.aliyuncs.com/google_containers"
PAUSE_VERSION="3.10"

# 你需要替换以下为当前 join 命令（或 export JOIN_COMMAND）
JOIN_CMD="kubeadm join 192.168.10.2:6443 --token <你的token> --discovery-token-ca-cert-hash sha256:<你的hash>"

echo -e "\n[INFO] 开始强制升级 worker 节点为 $K8S_VERSION"

echo "[STEP] 清除已有 Kubernetes 安装"
systemctl stop kubelet || true
kubeadm reset -f || true
apt-get purge -y kubeadm kubelet kubectl
apt-get autoremove -y
rm -rf /etc/kubernetes /var/lib/kubelet /etc/containerd

echo "[STEP] 重新安装 containerd"
apt-get update -y
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i "s#sandbox_image.*#sandbox_image = \"${IMAGE_REPO}/pause:${PAUSE_VERSION}\"#" /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

echo "[STEP] 添加 Kubernetes 源并安装固定版本 $K8S_VERSION_DEB"
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" > \
  /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet=${K8S_VERSION_DEB} kubeadm=${K8S_VERSION_DEB} kubectl=${K8S_VERSION_DEB}
apt-mark hold kubelet kubeadm kubectl

echo "[STEP] 关闭 swap"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

echo "[STEP] 调整内核参数"
modprobe br_netfilter || true
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

echo "[STEP] 加入 Kubernetes 集群"
$JOIN_CMD --image-repository ${IMAGE_REPO} --kubernetes-version ${K8S_VERSION}

echo "✅ Worker 节点已强制升级并加入集群：$K8S_VERSION"

