#!/bin/bash

# Script to set up a Kubernetes Worker node on macOS using Multipass
# Installs containerd, kubeadm, kubelet, and kubectl, and joins an existing Kubernetes cluster

# Exit on any error
set -e

# Variables
VM_NAME="k8s-worker"
CPUS=2
MEMORY="4G"
DISK="20G"
UBUNTU_RELEASE="22.04"  # Specify Ubuntu LTS version explicitly to avoid "release" error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print error and exit
error_exit() {
    echo -e "${RED}Error: $1${NC}" >&2
    exit 1
}

# Check if Multipass is installed
if ! command_exists multipass; then
    echo -e "${RED}Multipass is not installed. Installing it...${NC}"
    brew install multipass || error_exit "Failed to install Multipass"
fi

# Check network connectivity to Ubuntu image repository
echo "Checking network connectivity to Ubuntu image repository..."
if ! ping -c 1 cloud-images.ubuntu.com >/dev/null 2>&1; then
    echo -e "${RED}Cannot reach cloud-images.ubuntu.com. Please check your network connection.${NC}"
    exit 1
fi

# Launch Multipass VM with explicit image
echo "Launching Multipass VM: $VM_NAME..."
multipass launch --name "$VM_NAME" --cpus "$CPUS" --memory "$MEMORY" --disk "$DISK" "$UBUNTU_RELEASE" || {
    error_exit "Failed to launch Multipass VM. Ensure Multipass is configured correctly and try specifying the image (e.g., '22.04')."
}

# Wait for VM to be ready
echo "Waiting for VM to start..."
sleep 10
until multipass info "$VM_NAME" | grep -q "Running"; do
    echo "VM is still starting..."
    sleep 5
done

# Install dependencies inside the VM
echo "Setting up containerd, kubeadm, kubelet, and kubectl in the VM..."
multipass exec "$VM_NAME" -- /bin/bash -c "
    set -e

    # Update system
    sudo apt update && sudo apt upgrade -y

    # Install containerd
    sudo apt install -y containerd || { echo 'Failed to install containerd'; exit 1; }

    # Configure containerd
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml
    sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    sudo systemctl restart containerd
    sudo systemctl enable containerd

    # Install kubeadm, kubelet, and kubectl
    sudo apt install -y apt-transport-https ca-certificates curl
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    echo 'deb [signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee /etc/apt/sources.list.d/kubernetes.list
    sudo apt update
    sudo apt install -y kubeadm kubelet kubectl
    sudo apt-mark hold kubeadm kubelet kubectl

    # Disable swap
    sudo swapoff -a
    sudo sed -i '/swap/s/^/#/' /etc/fstab

    # Verify installations
    containerd --version && kubeadm version && kubelet --version && kubectl version --client
"

# Prompt for kubeadm join command
echo -e "${GREEN}VM setup complete!${NC}"
echo "Please provide the 'kubeadm join' command from your Kubernetes control plane."
echo "Run this on your control plane to get it: 'kubeadm token create --print-join-command'"
read -p "Enter the kubeadm join command: " JOIN_COMMAND

# Join the Kubernetes cluster
if [ -n "$JOIN_COMMAND" ]; then
    echo "Joining the Kubernetes cluster..."
    multipass exec "$VM_NAME" -- sudo bash -c "$JOIN_COMMAND" || error_exit "Failed to join the Kubernetes cluster"
else
    error_exit "No kubeadm join command provided"
fi

# Print success message
echo -e "${GREEN}Kubernetes Worker node setup complete!${NC}"
echo "Verify the node in your control plane with: kubectl get nodes"

# Provide cleanup instructions
echo "To delete the VM when done, run:"
echo "multipass delete $VM_NAME && multipass purge"
