#!/usr/bin/env bash
# setup-master.sh — Kubernetes master 一键安装脚本（国内镜像、修复 containerd 配置）
# -----------------------------------------------------------------------------
# USAGE:  sudo ./setup-master.sh [MASTER_IP] [POD_CIDR] [K8S_VERSION]
#         例如： sudo ./setup-master.sh 192.168.10.2 10.244.0.0/16 v1.33.2
# 若参数省略，将使用默认值。
# -----------------------------------------------------------------------------
set -euo pipefail

# === 参数 ===
MASTER_IP=${1:-$(hostname -I | awk '{print $1}')}
POD_CIDR=${2:-"10.244.0.0/16"}
K8S_VERSION=${3:-"v1.33.2"}
K8S_MINOR=$(echo "${K8S_VERSION#v}" | cut -d. -f1,2)   # 1.33
IMAGE_REPO="registry.cn-hangzhou.aliyuncs.com/google_containers"
PAUSE_VERSION="3.10"

step() { echo -e "\e[32m[STEP]\e[0m $*"; }

step "参数确认"
echo "Master IP      : $MASTER_IP"
echo "Pod CIDR       : $POD_CIDR"
echo "Kubernetes ver : $K8S_VERSION"
echo "Image Repo     : $IMAGE_REPO"

# -----------------------------------------------------------------------------
# 1. 关闭 swap
# -----------------------------------------------------------------------------
step "关闭 swap"
swapoff -a || true
sed -i '/ swap / s/^/#/' /etc/fstab || true

# -----------------------------------------------------------------------------
# 2. 系统参数调优
# -----------------------------------------------------------------------------
step "内核参数 & 模块"
modprobe br_netfilter || true
cat <<EOF >/etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

# -----------------------------------------------------------------------------
# 3. 安装 containerd 并修复 sandbox_image
# -----------------------------------------------------------------------------
step "安装 containerd"
apt-get update -y
apt-get install -y containerd
mkdir -p /etc/containerd
after_gen=/etc/containerd/config.toml
containerd config default | tee $after_gen >/dev/null

# 启用 systemd cgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' $after_gen
# 替换 sandbox_image，确保带双引号且无换行
sed -i "s#sandbox_image *=.*#sandbox_image = \"${IMAGE_REPO}/pause:${PAUSE_VERSION}\"#" $after_gen

systemctl daemon-reload
systemctl restart containerd
systemctl enable containerd

# -----------------------------------------------------------------------------
# 4. 安装 Kubernetes 组件（kubeadm kubelet kubectl）
# -----------------------------------------------------------------------------
step "添加 Kubernetes APT 源"
apt-get install -y apt-transport-https ca-certificates curl gnupg
mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /" \
  >/etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

# -----------------------------------------------------------------------------
# 5. 预拉取所需镜像（国内镜像源）
# -----------------------------------------------------------------------------
step "预拉取 Kubernetes 镜像"
IMAGES=(kube-apiserver kube-controller-manager kube-scheduler kube-proxy etcd coredns/coredns)
for name in "${IMAGES[@]}"; do
   full="${IMAGE_REPO}/${name}:${K8S_VERSION}"
   ctr -n k8s.io i pull docker.io/${full} || true
   # 打 tag 为官方地址供 kubeadm 使用
   dst="registry.k8s.io/${name}:${K8S_VERSION}"
   ctr -n k8s.io i tag docker.io/${full} ${dst} || true
   echo "✔ Pushed tag ${dst}"
done
# pause 镜像已在 config.toml 指定，无需重复

# -----------------------------------------------------------------------------
# 6. 初始化控制平面
# -----------------------------------------------------------------------------
step "初始化 kubeadm"
kubeadm init \
  --apiserver-advertise-address=${MASTER_IP} \
  --pod-network-cidr=${POD_CIDR} \
  --kubernetes-version=${K8S_VERSION} \
  --image-repository=${IMAGE_REPO}

# -----------------------------------------------------------------------------
# 7. 配置 kubectl
# -----------------------------------------------------------------------------
step "配置 kubectl"
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

# -----------------------------------------------------------------------------
# 8. 安装 Flannel 网络插件（替换镜像为 docker hub flannelio）
# -----------------------------------------------------------------------------
step "安装 Flannel CNI"
FLANNEL_YAML=/tmp/kube-flannel.yml
curl -L https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml -o $FLANNEL_YAML
sed -i 's#quay.io/coreos#docker.io/flannelio#g' $FLANNEL_YAML
kubectl apply -f $FLANNEL_YAML

# -----------------------------------------------------------------------------
# 9. 生成 Worker 加入脚本
# -----------------------------------------------------------------------------
step "生成 join.sh"
kubeadm token create --print-join-command >/root/join.sh
chmod +x /root/join.sh
cat /root/join.sh

echo -e "\n✅  控制平面初始化完成！请将 /root/join.sh 复制到 Worker 节点并执行。"

