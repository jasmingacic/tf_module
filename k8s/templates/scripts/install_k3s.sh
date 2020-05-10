#!/bin/bash
cd ~

K3S_VER='${k3s_version}'
MASTER_NODE_IP='${master_node_ip}'
WORKER_NODE_IPS='${worker_node_ips}'
SSH_PRIVATE_KEY='${ssh_private_key}'

WORKER_NODE_IPS=$(echo $WORKER_NODE_IPS | sed "s/\[//g")
WORKER_NODE_IPS=$(echo $WORKER_NODE_IPS | sed "s/\]//g")
WORKER_NODE_IPS=$(echo $WORKER_NODE_IPS | sed "s/\"//g")
WORKER_NODE_IPS=$(echo $WORKER_NODE_IPS | sed "s/\,/ /g")

echo "write Private Key to file"
cat <<EOF >/root/.ssh/id_rsa
$SSH_PRIVATE_KEY
EOF
chmod 0400 /root/.ssh/id_rsa

echo "Set SSH config to not do StrictHostKeyChecking"
cat <<EOF >/root/.ssh/config
Host *
    StrictHostKeyChecking no
EOF
chmod 0400 /root/.ssh/config

echo "Install k3s without Traefik"
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VER INSTALL_K3S_EXEC="server --disable traefik --disable local-storage --disable-cloud-controller --kubelet-arg cloud-provider=external" sh -

echo "Wait for k3s token to exist"
until [ -f /var/lib/rancher/k3s/server/node-token ]; do sleep 1; done
echo "Wait until the kubeconfig is generated"
until [ -f /etc/rancher/k3s/k3s.yaml ]; do sleep 1; done

echo "Gather token and install k3s on worker node via SSH"
TOKEN=`cat /var/lib/rancher/k3s/server/node-token`
URL="https://$MASTER_NODE_IP:6443"
echo "Starting ssh commands"
for worker_node in $WORKER_NODE_IPS; do
    echo "Deploying $worker_node as a k3s worker"
    ssh root@$worker_node "curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$k3s_ver K3S_URL=$URL K3S_TOKEN=$TOKEN INSTALL_K3S_EXEC='agent --kubelet-arg cloud-provider=external' sh -"
done
