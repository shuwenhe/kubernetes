#!/bin/bash
set -e

CONF=/etc/systemd/system/kubelet.service.d/10-runtime.conf

if [ -f "$CONF" ]; then
  echo "[INFO] Patching $CONF to remove --container-runtime"
  sudo sed -i '/--container-runtime/d' "$CONF"
  sudo systemctl daemon-reexec
  sudo systemctl daemon-reload
  sudo systemctl restart kubelet
  echo "[OK] kubelet restarted successfully."
else
  echo "[WARN] File not found: $CONF"
fi

