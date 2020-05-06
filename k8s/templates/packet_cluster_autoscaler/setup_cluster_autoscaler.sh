#!/bin/bash
MASTER_IP='${master_ip}'
API_PORT='${api_port}'
K3S_VER='${k3s_version}'

TOKEN=`cat /var/lib/rancher/k3s/server/node-token`
URL="https://$MASTER_IP:$API_PORT"
K3S_SCRIPT=$(cat <<-EOF
#!/bin/bash
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=$K3S_VER K3S_URL=$URL K3S_TOKEN=$TOKEN INSTALL_K3S_EXEC="agent --kubelet-arg cloud-provider=external" sh -
EOF
)
USER_DATA=$(printf "$K3S_SCRIPT" | base64 -w 0)
sed -i "s/__USER_DATA__/$USER_DATA/g" /root/bootstrap/packet_cluster_autoscaler/cluster_autoscaler_secret.yaml
