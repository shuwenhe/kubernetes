#!/usr/bin/env bash
# setup-worker.sh — Kubernetes Worker 一键安装脚本（适配 v1.33.2 + 国内镜像）

set -euo pipefail

# ========== 参数解析 ==========
JOIN_CMD="${JOIN_COMMAND:-}"

if [[ -z "$JOIN_CMD" && $# -ge 3 ]]; then
  MASTER_IP=$1
  TOKEN=$2
  HASH=$3
  JOIN_CMD="kubeadm join ${MASTER_IP}:6443 --token ${TOKEN} --discovery-token-ca-cert-hash sha256:${HASH}"
fi

if [[ -z "$JOIN_CMD" ]]; then
  echo "❌ 未提供 Join 参数。请执行方式如下："
  echo "   sudo ./setup-worker.sh <MASTER_IP> <TOKEN> <DISCOVERY_HASH>"
  exit 1
fi

K8S_VERSION="v1.33.2"
K8S_MINOR="1.33"
IMAGE_REPO="registry.cn-hangzhou.aliyuncs.com/google_containers"
PAUSE_VERSION="3.10"

step() { echo -e "\e[36m[STEP]\e[0m $*"; }

# -----------------------------------------------------------------------------
# 1. 关闭 swap
# -----------------------------------------------------------------------------
step "关闭 swap"
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

# -----------------------------------------------------------------------------
# 2. 系统参数 & 加载内核模块
# -----------------------------------------------------------------------------
step "配置内核参数"
modprobe br_netfilter || true
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# -----------------------------------------------------------------------------
# 3. 安装 containerd 并配置 sandbox_image
# -----------------------------------------------------------------------------
step "安装 containerd 并配置 pause 镜像"
apt-get update -y
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改为 systemd cgroup + 阿里云 pause 镜像
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sed -i "s#sandbox_image *=.*#sandbox_image = \"${IMAGE_REPO}/pause:${PAUSE_VERSION}\"#" /etc/containerd/config.toml

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now containerd

# -----------------------------------------------------------------------------
# 4. 安装 Kubernetes 组件（匹配 master）
# -----------------------------------------------------------------------------
step "安装 kubelet/kubeadm/kubectl v${K8S_VERSION}"
apt-get install -y apt-transport-https ca-certificates curl gpg

mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# -----------------------------------------------------------------------------
# 5. 加入 Kubernetes 集群
# -----------------------------------------------------------------------------
step "加入 Kubernetes 集群"
echo "[JOIN_CMD] $JOIN_CMD"
$JOIN_CMD

# -----------------------------------------------------------------------------
# 6. 成功提示
# -----------------------------------------------------------------------------
echo -e "\n✅ 成功加入 Kubernetes 集群！使用 \`kubectl get nodes\` 可在 master 节点验证。"

