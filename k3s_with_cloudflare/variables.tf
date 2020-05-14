variable "auth_token" {
    description = "Packet API Key"
    type = string
}

variable "organization_id" {
    description = "Packet Organization ID"
    type = string
}

variable "project_name" {
    description = "The name you want to give to your new Packet Project"
    default = "my-project"
    type = string
}

variable "cluster_name" {
    description = "The name of the k3s cluster"
    default = "my-cluster"
    type = string
}

variable "operating_system" {
    description = "The Operating system of the node (Only Ubuntu 16.04 has been tested)"
    default = "ubuntu_20_04"
    type = string
}

variable "billing_cycle" {
    description = "How the node will be billed (Not usually changed)"
    default = "hourly"
    type = string
}

variable "plan"{
    description = "The server type to deploy"
    default = "c2.medium.x86"
    type = string
}
variable "facility" {
    description = "The location of the servers"
    default = "sjc1"
    type = string
}

variable "k3s_version" {
    description = "The GitHub release version of k3s to install"
    default = "v1.18.2+k3s1"
    type = string
}

variable "helm_version" {
    description = "The GitHub release version of helm to install"
    default = "v3.2.1"
    type = string
}

variable "bgp_asn" {
    description = "BGP ASN to peer with Packet"
    default = 65000
    type = number
}

variable "node_pool_name" {
    description = "Node Pool name for Kubernetes cluster autoscaler"
    default = "pool0"
    type = string
}

variable "autoscaler_image_version" {
    description = "The version of the autoscaler docker image to use"
    default = "v1.17.0"
    type = string
}

variable "worker_count" {
    description = "How many worker nodes would you like?"
    default = 3
    type = number
}

variable "min_nodes" {
    description = "Minimum number of nodes in the cluster"
    default = 3
    type = number
}

variable "max_nodes" {
    description = "Maximum number of nodes in the cluster"
    default = 10
    type = number
}

variable "fission_version" {
    description = "Version of Fission to deploy"
    default = "1.9.0"
    type = string
}


variable "cloudflare_email" {
    type = string
    description = "EMail address used for cloudflare authentication"
}

variable "cloudflare_api_key" {
    type = string
    description = "API key used for cloudflare authentication"
}

variable "cloudflare_zone_id" {
    type = string
    description = "Zone ID to create DNS record for"
}

variable "dns_domain" {
    type = string
    description = "DNS domain to create DNS record for"
}

variable "cert_manager_version" {
    description = "Version of Cert Manager to deploy"
    default = "v0.14.3"
    type = string
}
