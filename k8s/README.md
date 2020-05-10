# K3s Deployment on Packet Baremetal
This repo contains [Terraform](http://terraform.io) scripts to deploy [K3s](http://k3s.io) on [Packet](http://packet.com) baremetal servers. By default one master and three workers will be created using t1.small.x86 in Packet's New York datacenter. We then add Packet's CCM and Autoscaler to allow these clusters to adapt to swell and contract to the load they are under. 

## Getting Started
You will need to first clone this repo, second ensure you have [Terraform](http://terraform.io) installed, lastly you will need a [Packet Account](https://app.packet.net/signup) (Use promo code ***cody*** for $30 in free cloud credits.)

You will now need to create a terraform.tfvars file that looks something like this:
```
auth_token="FExVfiQafmhLu3HWHHwh3WZD5drjw45z"
organization_id="ecd6e867-e5fb-3e0b-b90e-090a055437ee"
```
You can also override any variable from the 00_vars.tf file by specifying that variable in the terraform.tfvars file.

Once all this is done. All you have to do now is run ***terraform init && terraform apply --auto-approve*** from the root of this git repo. And your clusters will be created and wired together!

# About some of the tech... 

## Cluster Autoscaler
Packet has developed a [Kubernetes Autoscaler](https://www.packet.com/resources/guides/kubernetes-cluster-autoscaler-on-packet/) that allows you to automatically add and subtract hardware whenever this is resource contention. This is installed automatically in this cluster and is regulated by the ***min_nodes*** & ***max_nodes*** variables for each cluster.

## Cloud Control Manager (CCM)
Packet has developed their [Kubernetes CCM](https://www.packet.com/resources/guides/kubernetes-ccm-for-packet/) which allows the cluster to know more information about the underlying nodes. This is a must have with the Cluster Autoscaler in so that when the Autoscaler removes a node, that node can bed deleted from Kubernetes gracefully.

# TODO
* We need to make sure we have loadbalancer support. (MetalLB should be integrated with the CCM soon)
* We need to create a DNS name for our worker nodes so we can use certbot for ssl encryption
