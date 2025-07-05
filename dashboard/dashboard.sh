#!/bin/bash

# 1. 安装 Kubernetes Dashboard
echo "部署 Kubernetes Dashboard..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v3.0.0/aio/deploy/recommended.yaml

# 2. 创建 admin 服务账户并赋予管理员权限
echo "创建 admin 服务账户并赋予管理员权限..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

# 3. 获取登录 Dashboard 的 token
echo "获取 admin 用户的 token..."
TOKEN=$(kubectl -n kubernetes-dashboard create token admin-user)

echo "--------------------------"
echo "使用以下 token 登录 Dashboard:"
echo "$TOKEN"
echo "--------------------------"

# 4. 启动 kubectl proxy
echo "启动 kubectl proxy..."
kubectl proxy --address='0.0.0.0' --disable-filter=true --accept-hosts='^*$' &

# 提示用户访问地址
echo "访问 Kubernetes Dashboard: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
echo "使用上面的 token 登录"

