#!/usr/bin/env bash
# setup-master.sh - Kubernetes master node automated installer
# Usage: sudo ./setup-master.sh [MASTER_IP] [POD_CIDR] [K8S_VERSION]
#   MASTER_IP   : 控制平面节点在局域网中的 IP（默认取本机第一块非回环网卡 IP）
#   POD_CIDR    : Pod 网络段（默认 10.244.0.0/16，匹配 Flannel 默认）
#   K8S_VERSION : 次版本号，例如 1.33（默认 1.33）

set -euo pipefail

MASTER_IP=${1:-$(hostname -I | awk '{print $1}')}
POD_CIDR=${2:-"10.244.0.0/16"}
K8S_VERSION=${3:-"1.33"}

step() { echo -e "\e[32m[STEP]\e[0m $*"; }

step "参数确认"
echo "Master IP      : $MASTER_IP"
echo "Pod CIDR       : $POD_CIDR"
echo "Kubernetes ver : $K8S_VERSION"

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
# 5. 初始化控制平面
############################################
step "kubeadm init"
kubeadm init --apiserver-advertise-address=${MASTER_IP} --pod-network-cidr=${POD_CIDR} -v 5

############################################
# 6. 配置 kubectl
############################################
step "配置 kubectl"
mkdir -p $HOME/.kube
cp /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

############################################
# 7. 安装 Flannel 网络插件
############################################
step "安装 Flannel CNI"
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

############################################
# 8. 生成 worker join 脚本
############################################
step "生成 join.sh"
kubeadm token create --print-join-command >/root/join.sh
chmod +x /root/join.sh

step "完成！"
echo "=============================================================="
echo "已在 /root/join.sh 生成工作节点加入脚本，请复制到 worker 节点执行。"
echo "或者在运行 setup-worker.sh 时，将 join 命令作为环境变量传递。"
echo "=============================================================="
