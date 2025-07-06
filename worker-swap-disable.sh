#!/usr/bin/env bash
# 关闭 swap 并确保重启后不再启用，同时重启 kubelet

set -euo pipefail

echo "[1/5] 临时关闭 swap"
sudo swapoff -a

echo "[2/5] 注释 /etc/fstab 中的 swap 行（防止开机挂载）"
sudo sed -i.bak '/\sswap\s/s/^/#/' /etc/fstab

echo "[3/5] 屏蔽或禁用 systemd 中可能存在的 swap 单元"
sudo systemctl disable --now swap.target || true
sudo systemctl mask swap.img.swap || true
sudo systemctl disable --now dev-zram0.swap || true
sudo systemctl disable --now zramswap.service || true

echo "[4/5] 重载 systemd 配置"
sudo systemctl daemon-reexec
sudo systemctl daemon-reload

echo "[5/5] 重启 kubelet 服务"
sudo systemctl restart kubelet

echo -e "\n✅ swap 已彻底关闭，kubelet 已重启"
swapon --summary || true

