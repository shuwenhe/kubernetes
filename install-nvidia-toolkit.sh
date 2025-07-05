#!/bin/bash
# install-nvidia-toolkit.sh - 为 Kubernetes 节点安装 NVIDIA GPU 支持 (containerd + toolkit)
# 适用于 Ubuntu 24.04 (noble)，通过 Ubuntu 22.04 (jammy) 源实现兼容

set -euo pipefail

echo -e "\e[32m[1/6] 清理无效旧源（防止 HTML 错误）\e[0m"
sudo rm -f /etc/apt/sources.list.d/nvidia-container-toolkit.list || true

echo -e "\e[32m[2/6] 添加 NVIDIA GPG 密钥\e[0m"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
  sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

echo -e "\e[32m[3/6] 添加 Ubuntu 22.04 (jammy) NVIDIA 源（兼容 noble）\e[0m"
curl -s -L https://nvidia.github.io/libnvidia-container/ubuntu22.04/libnvidia-container.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

echo -e "\e[32m[4/6] 更新软件包列表并安装 nvidia-container-toolkit\e[0m"
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit

echo -e "\e[32m[5/6] 配置 containerd 使用 NVIDIA runtime\e[0m"
sudo nvidia-ctk runtime configure --runtime=containerd

echo -e "\e[32m[6/6] 重启 containerd 服务\e[0m"
sudo systemctl restart containerd

echo -e "\n✅ \e[1m安装完成！请通过以下命令检查 GPU 是否被识别：\e[0m"
echo "   sudo kubectl describe node \$(hostname) | grep -i 'nvidia.com/gpu'"

