#!/usr/bin/env bash
# setup-worker.sh - Kubernetes worker node automated installer (国内镜像优化版)
# --------------------------------------------------------------
# 用法示例：
#   1. 在 master 节点执行： kubeadm token create --print-join-command > join.sh
#   2. scp join.sh worker:/root/
#   3. 在 worker 上：
#        chmod +x setup-worker.sh /root/join.sh
#        sudo JOIN_COMMAND="$(cat /root/join.sh)" ./setup-worker.sh
#   --- 或直接传位置参数 ---
#        sudo ./setup-worker.sh <master-ip> <token> <hash> [k8sVersion] [imageRepo]
# --------------------------------------------------------------

set -euo pipefail

# ========= 参数解析 =========
JOIN_CMD="${JOIN_COMMAND:-}"

if [[ -z "$JOIN_CMD" && $# -ge 3 ]]; then
  MASTER_IP=$1
  TOKEN=$2
  HASH=$3
  JOIN_CMD="kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH}"
  shift 3
fi

K8S_VERSION="${1:-v1.33.2}"
IMAGE_REPO="${2:-registry.cn-hangzhou.aliyuncs.com/google_containers}"
PAUSE_VERSION="3.10"  # 与 master 保持一致

if [[ -z "$JOIN_CMD" ]]; then
  echo "[ERROR] 需要通过 JOIN_COMMAND 环境变量或位置参数提供完整的 kubeadm join 命令！"
  exit 1
fi

step() { echo -e "\e[32m[STEP]\e[0m $*"; }

step "节点参数确认"
echo "Kubernetes 版本 : $K8S_VERSION"
echo "镜像仓库       : $IMAGE_REPO"
echo "Join Command   : $JOIN_CMD"

############################################
# 1. 关闭 swap
############################################
step "关闭 swap"
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

############################################
# 2. 内核参数设置
############################################
step "配置内核参数"
modprobe br_netfilter || true
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
EOF
sysctl --system

############################################
# 3. 安装 containerd 并使用国内 pause 镜像
############################################
step "安装 containerd"
apt-get update -y
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml
sed -i "s#registry.k8s.io/pause:.*#${IMAGE_REPO}/pause:${PAUSE_VERSION}#" /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

############################################
# 4. 安装 kubeadm / kubelet / kubectl
############################################
step "安装 kube 组件"
apt-get install -y apt-transport-https ca-certificates curl gnupg
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:${K8S_VERSION#v}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:${K8S_VERSION#v}/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

############################################
# 5. 加入集群（使用国内镜像仓库）
############################################
step "加入 Kubernetes 集群"
# shellcheck disable=SC2086
$JOIN_CMD --image-repository ${IMAGE_REPO} --kubernetes-version ${K8S_VERSION}

step "✅ Worker 节点已成功加入集群！"

