#!/bin/bash

# UBUNTU_VERSION: "" -> use LTS version
# Use `multipass find` to list possible version values
UBUNTU_VERSION=${UBUNTU_VERSION:-"20.04"}
# UBUNTU_VERSION=22.04

# Start preparing the cluster

echo "K3S using version : $K3S_VERSION ($K3S_LABEL)" | tee -a ./logs/summary.log
echo "  latest version  : $K3S_LATEST" | tee -a ./logs/summary.log
echo "  known working   : $K3S_WORKING" | tee -a ./logs/summary.log

echo "K3S cluster running on multipass virtual machines" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

if [ $MULTINODE -ne 0 ]; then 
  # Multi node cluster
  echo "Multi node: 1 master, 2 worker nodes" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  multipass launch --name k3s-master "$UBUNTU_VERSION" --cpus 1 --mem 2048M --disk 10G
  multipass launch --name k3s-node1 "$UBUNTU_VERSION" --cpus 1 --mem 2048M --disk 15G
  multipass launch --name k3s-node2 "$UBUNTU_VERSION" --cpus 1 --mem 2048M --disk 15G
  multipass exec k3s-master -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_KUBECONFIG_MODE=644 sh -"
  export K3S_TOKEN="$(multipass exec k3s-master -- /bin/bash -c "sudo cat /var/lib/rancher/k3s/server/node-token")"
  export K3S_IP_SERVER="https://$(multipass info k3s-master | grep "IPv4" | awk -F' ' '{print $2}'):6443"
  multipass exec k3s-node1 -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_IP_SERVER} sh -"
  multipass exec k3s-node2 -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_TOKEN=${K3S_TOKEN} K3S_URL=${K3S_IP_SERVER} sh -"
else
  # Single node cluster
  echo "Single node: 1 master/worker" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log
  multipass launch --name k3s-master "$UBUNTU_VERSION" --cpus 1 --mem 2048M --disk 20G
  multipass exec k3s-master -- /bin/bash -c "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VERSION K3S_KUBECONFIG_MODE=644 sh -"
fi

# Extract kubeconfig
export K3S_IP_SERVER="https://$(multipass info k3s-master | grep "IPv4" | awk -F' ' '{print $2}'):6443"
multipass exec k3s-master -- /bin/bash -c "cat /etc/rancher/k3s/k3s.yaml" | sed "s%https://127.0.0.1:6443%${K3S_IP_SERVER}%g" | sed "s/default/k3s/g" > ./kubeconfig.yaml
export KUBECONFIG=./kubeconfig.yaml

echo "Waiting control plane to be ready initially"
TEST_EXEC=""
I=10
while [ $I -ne 0 ] && [ "$TEST_EXEC" == "" ]; do
  sleep 3
  TEST_EXEC=$(kubectl get nodes 2>/dev/null ||:)
  let I=I-1
  echo -n "."
done
if [ "$TEST_EXEC" == "" ]; then
  echo "Control plane not available"
  exit 1
fi

# Node information

echo "K3S cluster deployed" | ts '[%Y-%m-%d %H:%M:%S]' | tee -a ./logs/summary.log

multipass exec k3s-master -- lsb_release -a | ts '[%Y-%m-%d %H:%M:%S]  ' | tee -a ./logs/summary.log
multipass exec k3s-master -- uname -r | ts '[%Y-%m-%d %H:%M:%S]   Kernel: ' | tee -a ./logs/summary.log
