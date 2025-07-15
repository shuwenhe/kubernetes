#!/usr/bin/env bash
# 检查 Kubernetes 控制面运行状态
# 建议配置为 systemd 启动项或定时任务执行

LOG_FILE="/var/log/k8s-cluster-health.log"
echo "⏱️ $(date) - 检查集群状态开始" >> $LOG_FILE

# 检查 kube-apiserver 健康
if curl -s --max-time 3 https://127.0.0.1:6443/healthz --insecure | grep ok >/dev/null; then
    echo "[OK] kube-apiserver 正常" >> $LOG_FILE
else
    echo "[ERR] kube-apiserver 不可用！" >> $LOG_FILE
fi

# 检查节点状态
echo "🧩 节点状态：" >> $LOG_FILE
kubectl get nodes -o wide >> $LOG_FILE 2>&1 || echo "[ERR] kubectl get nodes 失败" >> $LOG_FILE

# 检查核心 Pod 状态
echo "📦 核心 Pod 状态：" >> $LOG_FILE
kubectl get pods -A >> $LOG_FILE 2>&1 || echo "[ERR] kubectl get pods 失败" >> $LOG_FILE

echo "✅ $(date) - 集群状态检查结束" >> $LOG_FILE

