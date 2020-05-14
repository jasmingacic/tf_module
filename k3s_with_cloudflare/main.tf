provider "packet" {
    auth_token = var.auth_token
}

provider "cloudflare" {
    email   = var.cloudflare_email
    api_key = var.cloudflare_api_key
}

module "create_k3s" {
    source = "./modules/k3s"
    providers = {
        packet = "packet"
    }
    auth_token = var.auth_token
    organization_id = var.organization_id
    project_name = var.project_name
    cluster_name = var.cluster_name
    operating_system = var.operating_system
    billing_cycle = var.billing_cycle
    plan = var.plan
    facility = var.facility
    k3s_version = var.k3s_version
    helm_version = var.helm_version
    bgp_asn = var.bgp_asn
    node_pool_name = var.node_pool_name
    autoscaler_image_version = var.autoscaler_image_version
    worker_count = var.worker_count
    min_nodes = var.min_nodes
    max_nodes = var.max_nodes
    fission_version = var.fission_version
    dns_domain = var.dns_domain
    cert_manager_version = var.cert_manager_version
    email_address = var.cloudflare_email
}

module "dns_record" {
    source = "./modules/cloudflare"
    providers = {
        cloudflare = "cloudflare"
    }
    cloudflare_email = var.cloudflare_email
    cloudflare_api_key = var.cloudflare_api_key
    cloudflare_zone_id = var.cloudflare_zone_id
    dns_name = var.cluster_name
    ip_addresses = module.create_k3s.public_ips
}
