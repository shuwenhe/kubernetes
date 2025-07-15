#!/usr/bin/env bash
# setup-kubeconfig-metrics.sh
# 作用：一键配置 ~/.kube/config 并安装 metrics-server（国内镜像 + TLS 参数）

set -euo pipefail

GREEN() { echo -e "\e[32m$*\e[0m"; }

############################################################
# 1. 拷贝 admin.conf 至当前用户 ~/.kube/config
############################################################
GREEN "[1/4] 配置 kubeconfig ..."
mkdir -p "$HOME/.kube"
sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
sudo chown "$(id -u)":"$(id -g)" "$HOME/.kube/config"

############################################################
# 2. 安装 metrics‑server
############################################################
GREEN "[2/4] 安装 metrics-server ..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# 等待 Deployment 创建完毕
sleep 5

############################################################
# 3. 替换为阿里云镜像并添加启动参数
############################################################
GREEN "[3/4] 替换国内镜像 & 补充启动参数 ..."
IMAGE_CN="registry.aliyuncs.com/google_containers/metrics-server:v0.7.0"

kubectl -n kube-system set image deployment/metrics-server \
  metrics-server="${IMAGE_CN}"

# 给容器追加启动参数
kubectl -n kube-system patch deployment metrics-server \
  --type=json \
  -p='[
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
    {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP"}
  ]'

GREEN "  ▶ metrics-server 镜像已替换为: ${IMAGE_CN}"
GREEN "  ▶ 已添加 --kubelet-insecure-tls 与 address 参数"

############################################################
# 4. 等待 Pod 就绪并验证
############################################################
GREEN "[4/4] 等待 metrics-server Pod 就绪 ..."
kubectl wait --for=condition=Available -n kube-system deployment/metrics-server --timeout=90s

GREEN "\n✅ 配置完成！下面展示节点实时资源："
kubectl top nodes || echo "❌ 仍未获取到指标，请检查 metrics-server 日志。"

