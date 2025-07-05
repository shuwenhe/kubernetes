#!/usr/bin/env bash
# setup-worker.sh - Kubernetes Worker 自动安装脚本（适配 v1.30.2 + 国内镜像）

set -euo pipefail

# ========== 参数解析 ==========
JOIN_CMD="${JOIN_COMMAND:-}"

if [[ -z "$JOIN_CMD" && $# -ge 3 ]]; then
  MASTER_IP=$1
  TOKEN=$2
  HASH=$3
  JOIN_CMD="kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH}"
  shift 3
fi

K8S_VERSION="${1:-v1.30.2}"
IMAGE_REPO="${2:-registry.cn-hangzhou.aliyuncs.com/google_containers}"
PAUSE_VERSION="3.10"

if [[ -z "$JOIN_CMD" ]]; then
  echo "[ERROR] 需要通过 JOIN_COMMAND 环境变量或位置参数提供 kubeadm join 命令"
  exit 1
fi

step() { echo -e "\e[32m[STEP]\e[0m $*"; }

step "确认参数"
echo "Kubernetes 版本 : $K8S_VERSION"
echo "镜像仓库         : $IMAGE_REPO"
echo "Join Command     : $JOIN_CMD"

# ========== 1. 关闭 swap ==========
step "关闭 swap"
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

# ========== 2. 设置内核参数 ==========
step "配置内核参数"
modprobe br_netfilter || true
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# ========== 3. 安装 containerd ==========
step "安装 containerd"
apt-get update -y
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# ✅ 替换 sandbox 镜像为国内源
awk -v img="${IMAGE_REPO}/pause:${PAUSE_VERSION}" '
{
    if ($1 == "sandbox_image" && $2 == "=") {
        print "    sandbox_image = \"" img "\""
    } else {
        print $0
    }
}
' /etc/containerd/config.toml | sudo tee /etc/containerd/config.toml.new > /dev/null
sudo mv /etc/containerd/config.toml.new /etc/containerd/config.toml

systemctl daemon-reexec
systemctl restart containerd
systemctl enable containerd

# ========== 4. 安装 kubelet / kubeadm / kubectl ==========
step "安装 kube 组件"
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# 使用官方密钥源
curl -fsSL https://mirrors.aliyun.com/kubernetes/apt/doc/apt-key.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 添加国内镜像仓库源
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://mirrors.aliyun.com/kubernetes/apt/ kubernetes-xenial main" | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

# 更新 apt 并安装 Kubernetes 组件
apt-get update -y
apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# ========== 5. 加入集群 ==========
step "加入 Kubernetes 集群"
$JOIN_CMD --image-repository ${IMAGE_REPO} --kubernetes-version ${K8S_VERSION}

step "✅ Worker 节点已成功加入 Kubernetes 集群"

