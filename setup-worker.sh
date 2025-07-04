#!/usr/bin/env bash
# setup-worker.sh - Kubernetes worker node automated installer
# 使用方法 1：
#   sudo JOIN_COMMAND="kubeadm join <master-ip>:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>" ./setup-worker.sh [K8S_VERSION]
# 使用方法 2：
#   sudo ./setup-worker.sh <master-ip> <token> <hash> [K8S_VERSION]

set -euo pipefail

# 读取 join 命令
JOIN_CMD="${JOIN_COMMAND:-}"
if [ -z "$JOIN_CMD" ] && [ $# -ge 3 ]; then
  MASTER_IP=$1
  TOKEN=$2
  HASH=$3
  JOIN_CMD="kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH}"
  shift 3
fi

K8S_VERSION=${1:-"1.33"}

if [ -z "$JOIN_CMD" ]; then
  echo "ERROR: 请通过环境变量 JOIN_COMMAND 或者位置参数提供完整的 kubeadm join 命令！"
  exit 1
fi

step() { echo -e "\e[32m[STEP]\e[0m $*"; }

############################################
# 1. 关闭 swap
############################################
step "关闭 swap"
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

############################################
# 2. 内核参数设置
############################################
step "配置内核参数"
modprobe br_netfilter
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
sysctl --system

############################################
# 3. 安装 containerd
############################################
step "安装 containerd"
apt-get update -y
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

############################################
# 4. 安装 kubeadm / kubelet / kubectl
############################################
step "安装 kube 组件"
apt-get install -y apt-transport-https ca-certificates curl gnupg
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

############################################
# 5. 加入集群
############################################
step "加入 Kubernetes 集群"
# shellcheck disable=SC2086
$JOIN_CMD

step "完成！Worker 节点已成功加入集群。"
