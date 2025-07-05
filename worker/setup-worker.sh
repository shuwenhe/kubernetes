#!/usr/bin/env bash
# setup-worker.sh - Kubernetes worker node 安装脚本 (国内镜像版)

set -euo pipefail

# ===================== 参数解析 =====================
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
PAUSE_VERSION="3.10"

if [[ -z "$JOIN_CMD" ]]; then
  echo "[ERROR] 必须提供 kubeadm join 命令，使用环境变量 JOIN_COMMAND 或传入 <ip> <token> <hash>"
  exit 1
fi

step() { echo -e "\e[32m[STEP]\e[0m $*"; }

step "确认参数"
echo "Kubernetes 版本 : $K8S_VERSION"
echo "镜像仓库         : $IMAGE_REPO"
echo "Join Command     : $JOIN_CMD"

# ===================== 1. 关闭 swap =====================
step "关闭 swap"
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

# ===================== 2. 设置内核参数 =====================
step "配置内核参数"
modprobe br_netfilter || true
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

# ===================== 3. 安装 containerd =====================
step "安装 containerd"
apt-get update -y
apt-get install -y containerd

mkdir -p /etc/containerd
containerd config default >/etc/containerd/config.toml

# ✅ 安全替换 pause 镜像，防止 TOML 错误
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

# ===================== 4. 安装 kube 组件 =====================
step "安装 kubelet / kubeadm / kubectl"
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL "https://pkgs.k8s.io/core:/stable:${K8S_VERSION#v}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:${K8S_VERSION#v}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# ===================== 5. 加入集群 =====================
step "加入 Kubernetes 集群"
$JOIN_CMD --image-repository ${IMAGE_REPO} --kubernetes-version ${K8S_VERSION}

step "✅ Worker 节点已成功加入 Kubernetes 集群"

