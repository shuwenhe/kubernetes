#!/bin/bash
set -e

# === 参数配置 ===
MASTER_IP="192.168.10.2"
POD_CIDR="10.244.0.0/16"
K8S_VERSION="v1.33.2"
PAUSE_VERSION="3.10"
ETCD_VERSION="3.5.10-0"
COREDNS_VERSION="v1.11.1"
IMAGE_REPO="registry.cn-hangzhou.aliyuncs.com/google_containers"

echo "[STEP] 开始安装 Kubernetes 主节点"
echo "Master IP      : $MASTER_IP"
echo "Pod CIDR       : $POD_CIDR"
echo "Kubernetes ver : $K8S_VERSION"

# === 关闭 swap ===
echo "[STEP] 关闭 swap"
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab

# === 安装依赖 ===
echo "[STEP] 安装依赖组件"
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

# === 安装 containerd ===
echo "[STEP] 安装 containerd"
sudo apt-get install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# 修改 pause 镜像源
sudo sed -i 's#registry.k8s.io/pause:.*#registry.aliyuncs.com/google_containers/pause:'$PAUSE_VERSION'#' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# === 添加 Kubernetes 仓库 ===
echo "[STEP] 添加 Kubernetes 仓库"
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/${K8S_VERSION%.*}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION%.*}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# === 安装 kubeadm, kubelet, kubectl ===
echo "[STEP] 安装 kubeadm kubelet kubectl"
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# === 拉取并替换镜像 ===
echo "[STEP] 拉取 Kubernetes 镜像并替换 tag"
images=(
  kube-apiserver:$K8S_VERSION
  kube-controller-manager:$K8S_VERSION
  kube-scheduler:$K8S_VERSION
  kube-proxy:$K8S_VERSION
  pause:$PAUSE_VERSION
  etcd:$ETCD_VERSION
  coredns:$COREDNS_VERSION
)

for image in "${images[@]}"; do
  src_image="$IMAGE_REPO/${image}"
  dst_image="registry.k8s.io/${image}"
  echo "拉取镜像 $src_image 并标记为 $dst_image"
  sudo ctr -n k8s.io i pull docker.io/${src_image}
  sudo ctr -n k8s.io i tag docker.io/${src_image} ${dst_image}
done

# === 初始化 Kubernetes 主节点 ===
echo "[STEP] 初始化 Kubernetes Master 节点"
sudo kubeadm init \
  --apiserver-advertise-address=${MASTER_IP} \
  --image-repository=${IMAGE_REPO} \
  --kubernetes-version=${K8S_VERSION} \
  --pod-network-cidr=${POD_CIDR}

# === 配置 kubectl ===
echo "[STEP] 设置 kubectl 配置"
mkdir -p $HOME/.kube
sudo cp /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# === 安装 Flannel 网络插件 ===
echo "[STEP] 安装 Flannel 网络插件（国内源）"
wget https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml -O kube-flannel.yml
sed -i 's#quay.io/coreos#docker.io/flannelio#g' kube-flannel.yml
kubectl apply -f kube-flannel.yml

echo "✅ 主节点初始化完成！"
echo "请将以下 join 命令复制到 Worker 节点执行："
kubeadm token create --print-join-command

