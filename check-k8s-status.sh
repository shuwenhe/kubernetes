#!/usr/bin/env bash
# check-k8s-status.sh — 检查当前节点是否正确安装并加入 Kubernetes 集群
# 可用于 master 和 worker 节点

set -euo pipefail

GREEN="\e[32m"
RED="\e[31m"
RESET="\e[0m"

title() {
  echo -e "\n${GREEN}==> $*${RESET}"
}

error() {
  echo -e "${RED}[✗] $*${RESET}"
}

ok() {
  echo -e "${GREEN}[✓] $*${RESET}"
}

# 1. 检查 kube 组件是否安装
title "检查 kubeadm / kubelet / kubectl 是否已安装"
for cmd in kubeadm kubelet kubectl; do
  if ! command -v $cmd &>/dev/null; then
    error "$cmd 未安装"
  else
    ver=$($cmd version --client --short 2>/dev/null || $cmd version --short 2>/dev/null)
    ok "$cmd 安装成功: $ver"
  fi
done

# 2. 检查 containerd 是否运行中
title "检查 containerd 状态"
if systemctl is-active --quiet containerd; then
  ok "containerd 正在运行"
else
  error "containerd 未运行"
  systemctl status containerd --no-pager
fi

# 3. 检查 kubelet 是否运行中
title "检查 kubelet 状态"
if systemctl is-active --quiet kubelet; then
  ok "kubelet 正在运行"
else
  error "kubelet 未运行"
  systemctl status kubelet --no-pager
fi

# 4. 判断是否是 master 节点
if [[ -f /etc/kubernetes/manifests/kube-apiserver.yaml ]]; then
  IS_MASTER=true
else
  IS_MASTER=false
fi

# 5. 如果是 master，检查集群节点状态
if $IS_MASTER; then
  title "当前是 Master 节点，列出集群节点："
  if command -v kubectl &>/dev/null; then
    kubectl get nodes -o wide || error "kubectl 获取节点失败"
  else
    error "kubectl 未安装"
  fi
else
  title "当前是 Worker 节点，检查是否加入集群"
  kubelet_status=$(journalctl -u kubelet --no-pager | grep -E "Successfully registered|connection refused" | tail -n 5 || true)
  if echo "$kubelet_status" | grep -q "Successfully registered"; then
    ok "此 Worker 节点已成功加入集群"
  elif echo "$kubelet_status" | grep -q "connection refused"; then
    error "未能连接到 master，可能未 join 或被防火墙阻断"
  else
    error "无法判断 join 状态，请查看 kubelet 日志"
  fi
fi

# 6. 显示节点 IP 与 Hostname
title "节点信息"
echo "主机名：$(hostname)"
echo "内网 IP：$(hostname -I | awk '{print $1}')"

echo -e "\n${GREEN}✅ 检查完成！${RESET}"

