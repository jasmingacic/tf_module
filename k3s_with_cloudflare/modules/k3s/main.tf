resource "random_string" "bgp_password" {
    length = 18
    upper = true
    min_upper = 1 
    lower = true
    min_lower = 1 
    number = true
    min_numeric = 1 
    special = false
}

resource "packet_project" "new_project" {
    name = var.project_name
    organization_id = var.organization_id
    bgp_config {
        deployment_type = "local"
        asn = var.bgp_asn
        md5 = random_string.bgp_password.result
   }
}

resource "tls_private_key" "ssh_key_pair" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "packet_ssh_key" "ssh_pub_key" {
    name = var.project_name
    public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "packet_device" "k3s_master_node" {
    depends_on = [
        packet_ssh_key.ssh_pub_key
    ]
    hostname = format("k8s-%s-master", var.cluster_name) 
    plan = var.plan
    facilities = [var.facility]
    operating_system = var.operating_system
    billing_cycle = var.billing_cycle
    project_id = packet_project.new_project.id
    tags = [format("k8s-cluster-%s", var.cluster_name)]
}

resource "random_string" "random" {
    count = var.worker_count
    length = 8
    special = false
    upper = false
    lower = true
    number = false
}

resource "packet_device" "k3s_worker_nodes" {
    depends_on = [
        packet_ssh_key.ssh_pub_key
    ]
    count = var.worker_count
    hostname = format("k8s-%s-%s-%s", var.cluster_name, var.node_pool_name, element(random_string.random.*.result, count.index))
    plan = var.plan
    facilities = [var.facility]
    operating_system = var.operating_system
    billing_cycle = var.billing_cycle
    project_id = packet_project.new_project.id
    tags = [
        format("k8s-cluster-%s", var.cluster_name), 
        format("k8s-nodepool-%s", var.node_pool_name)
    ]
}

data "template_file" "k3s_install_script" {
    template = file("${path.module}/templates/scripts/install_k3s.sh")
    vars = {
        k3s_version = var.k3s_version
        master_node_ip = packet_device.k3s_master_node.access_public_ipv4
        worker_node_ips = jsonencode(packet_device.k3s_worker_nodes.*.access_public_ipv4)
        ssh_private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
    }
}

resource "null_resource" "install_k3s"{  
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/scripts/"]
    }

    provisioner "file" {
        content = data.template_file.k3s_install_script.rendered
        destination = "/root/bootstrap/scripts/install_k3s.sh"
    }

    provisioner "remote-exec" {
        inline = ["bash /root/bootstrap/scripts/install_k3s.sh"]
    }
}

resource "null_resource" "download_kubeconfig"{
    depends_on = [
        null_resource.install_k3s
    ]
    provisioner "local-exec" {
        command = <<-EOC
            scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@${packet_device.k3s_master_node.access_public_ipv4}:/etc/rancher/k3s/k3s.yaml ${path.module}/k3s_kubeconfig
            sed -i 's/127.0.0.1/${packet_device.k3s_master_node.access_public_ipv4}/g' ${path.module}/k3s_kubeconfig
        EOC
    }
    provisioner "local-exec" {
        when = destroy
        command = <<-EOD
            rm -f ${path.module}/k3s_kubeconfig
        EOD
    }
}

data "template_file" "ccm_secret" {
    template = file("${path.module}/templates/packet_ccm/ccm_secret.yaml")
    vars = {
        auth_token = var.auth_token
        project_id = packet_project.new_project.id
    }
}

data "template_file" "ccm_deployment" {
    template = file("${path.module}/templates/packet_ccm/ccm_deployment.yaml")
}

resource "null_resource" "install_ccm"{
    depends_on = [
        null_resource.install_k3s
    ]
    
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/packet_ccm/"]
    }

    provisioner "file" {
        content = data.template_file.ccm_secret.rendered
        destination = "/root/bootstrap/packet_ccm/ccm_secret.yaml"
    }

    provisioner "file" {
        content = data.template_file.ccm_deployment.rendered
        destination = "/root/bootstrap/packet_ccm/ccm_deployment.yaml"
    }

    provisioner "remote-exec" {
        inline = ["kubectl apply -f /root/bootstrap/packet_ccm/"]
    }
}

data "template_file" "cluster_autoscaler_secret" {
    template = file("${path.module}/templates/packet_cluster_autoscaler/cluster_autoscaler_secret.yaml")
    vars = {
        auth_token = base64encode(var.auth_token)
        project_id = packet_project.new_project.id
        master_ip = packet_device.k3s_master_node.access_public_ipv4
        api_port = 6443
        facility = var.facility
        operating_system = var.operating_system
        plan = var.plan
        billing_cycle = var.billing_cycle
        
    }
}

data "template_file" "cluster_autoscaler_deployment" {
    template = file("${path.module}/templates/packet_cluster_autoscaler/cluster_autoscaler_deployment.yaml")
    vars = {
        autoscaler_image_version = var.autoscaler_image_version
        cluster_name = var.cluster_name
        min_nodes = var.min_nodes
        max_nodes = var.max_nodes
        pool_name = var.node_pool_name
    }
}

data "template_file" "cluster_autoscaler_svcaccount" {
    template = file("${path.module}/templates/packet_cluster_autoscaler/cluster_autoscaler_svcaccount.yaml")
}

data "template_file" "setup_cluster_autoscaler" {
    template = file("${path.module}/templates/packet_cluster_autoscaler/setup_cluster_autoscaler.sh")
    vars = {
        master_ip = packet_device.k3s_master_node.access_public_ipv4
        api_port = 6443
        k3s_version = var.k3s_version
    }
}

resource "null_resource" "setup_cluster_autoscaler"{
    depends_on = [
        null_resource.install_k3s
    ]
    
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }
    
    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/packet_cluster_autoscaler/"]
    }

    provisioner "file" {
        content = data.template_file.cluster_autoscaler_deployment.rendered
        destination = "/root/bootstrap/packet_cluster_autoscaler/cluster_autoscaler_deployment.yaml"
    }

    provisioner "file" {
        content = data.template_file.cluster_autoscaler_secret.rendered
        destination = "/root/bootstrap/packet_cluster_autoscaler/cluster_autoscaler_secret.yaml"
    }

    provisioner "file" {
        content = data.template_file.cluster_autoscaler_svcaccount.rendered
        destination = "/root/bootstrap/packet_cluster_autoscaler/cluster_autoscaler_svcaccount.yaml"
    }

    provisioner "file" {
        content = data.template_file.setup_cluster_autoscaler.rendered
        destination = "/root/bootstrap/setup_cluster_autoscaler.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "bash /root/bootstrap/setup_cluster_autoscaler.sh",
            "kubectl apply -f /root/bootstrap/packet_cluster_autoscaler/"
        ]
    }
}

/*
resource "null_resource" "install_csi"{
    depends_on = [
        null_resource.install_k3s
    ]
    
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }
    
    provisioner "file" {
        source      = "templates/packet_csi"
        destination = "/root/bootstrap"
    }
    
    provisioner "remote-exec" {
        inline = ["kubectl apply -f /root/bootstrap/packet_csi"]
    }
}
*/

resource "null_resource" "install_csi"{
    depends_on = [
        null_resource.install_k3s
    ]
    
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = [
            "kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/master/deploy/longhorn.yaml",
            "kubectl patch storageclass longhorn -p '{\"metadata\": {\"annotations\":{\"storageclass.kubernetes.io/is-default-class\":\"true\"}}}'"
        ]
    }
}

data "template_file" "helm_install_script" {
    template = file("${path.module}/templates/scripts/install_helm.sh")
    vars = {
        helm_version = var.helm_version
    }
}

resource "null_resource" "install_helm"{
    depends_on = [
        null_resource.install_k3s
    ]
    
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/scripts/"]
    }

    provisioner "file" {
        content = data.template_file.helm_install_script.rendered
        destination = "/root/bootstrap/scripts/install_helm.sh"
    }

    provisioner "remote-exec" {
        inline = ["bash /root/bootstrap/scripts/install_helm.sh"]
    }
}

data "template_file" "nginx_ingress_values" {
    template = file("${path.module}/templates/nginx/nginx_ingress_values.yaml")
}

resource "null_resource" "install_nginx"{
    depends_on = [
        null_resource.install_helm
    ]
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/nginx/"]
    }

    provisioner "file" {
        content = data.template_file.nginx_ingress_values.rendered
        destination = "/root/bootstrap/nginx/nginx_ingress_values.yaml"
    }

    provisioner "remote-exec" {
        inline = [
            "kubectl create namespace ingress-nginx",
            "helm install ingress-nginx stable/nginx-ingress --namespace ingress-nginx -f /root/bootstrap/nginx/nginx_ingress_values.yaml"
        ]
    }
}

data "template_file" "le_prod_issuer" {
    template = file("${path.module}/templates/lets_encrypt/prod_issuer.yaml")
    vars = {
        email_address = var.email_address
    }
}

data "template_file" "le_stage_issuer" {
    template = file("${path.module}/templates/lets_encrypt/stage_issuer.yaml")
    vars = {
        email_address = var.email_address
    }
}

resource "null_resource" "install_cert_manager" { 
    depends_on = [
        null_resource.install_k3s
    ]
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/lets_encrypt/"]
    }

    provisioner "file" {
        content = data.template_file.le_prod_issuer.rendered
        destination = "/root/bootstrap/lets_encrypt/prod_issuer.yaml"
    }

    provisioner "file" {
        content = data.template_file.le_stage_issuer.rendered
        destination = "/root/bootstrap/lets_encrypt/stage_issuer.yaml"
    }

    provisioner "remote-exec" {
        inline = [
            "kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/${var.cert_manager_version}/cert-manager.yaml",
            "kubectl -n cert-manager wait --for condition=Available --timeout=300s deploy/cert-manager-webhook",
            "kubectl apply -f /root/bootstrap/lets_encrypt"
        ]

    }
}

resource "null_resource" "install_fission" {
    depends_on = [
        null_resource.install_csi
    ]
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = [
            "FISSION_NAMESPACE='fission'",
            "kubectl create namespace $FISSION_NAMESPACE",
            "helm install --namespace $FISSION_NAMESPACE --name-template fission --set serviceType=ClusterIP,routerServiceType=ClusterIP https://github.com/fission/fission/releases/download/${var.fission_version}/fission-all-${var.fission_version}.tgz"
       ]
    }
}

resource "null_resource" "install_ah-ah-ah" {
    depends_on = [
        null_resource.install_k3s
    ]
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "file" {
        source      = "${path.module}/templates/ah-ah-ah"
        destination = "/root/bootstrap"
    }
    
    provisioner "remote-exec" {
        inline = [
            "NAMESPACE='ah-ah-ah'",
            "kubectl create namespace $NAMESPACE",
            "kubectl -n $NAMESPACE apply -f /root/bootstrap/ah-ah-ah"
       ]
    }
}

data "template_file" "fission_ingress" {
    template = file("${path.module}/templates/ingress_rules/fission_ingress.yaml")
    vars = {
        fqdn = "${var.cluster_name}.${var.dns_domain}"
    }
}

data "template_file" "ah-ah-ah_ingress" {
    template = file("${path.module}/templates/ingress_rules/ah-ah-ah_ingress.yaml")
    vars = {
        fqdn = "${var.cluster_name}.${var.dns_domain}"
    }
}

resource "null_resource" "deploy_ingress_rules" {
    depends_on = [
        null_resource.install_nginx,
        null_resource.install_cert_manager,
        null_resource.install_fission,
        null_resource.install_ah-ah-ah
    ]
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/ingress/"]
    }

    provisioner "file" {
        content = data.template_file.fission_ingress.rendered
        destination = "/root/bootstrap/ingress/fission_ingress.yaml"
    }

    provisioner "file" {
        content = data.template_file.ah-ah-ah_ingress.rendered
        destination = "/root/bootstrap/ingress/ah-ah-ah_ingress.yaml"
    }

    provisioner "remote-exec" {
        inline = [
            "kubectl -n fission apply -f /root/bootstrap/ingress/fission_ingress.yaml",
            "kubectl -n ah-ah-ah apply -f /root/bootstrap/ingress/ah-ah-ah_ingress.yaml"
        ]
    }
}

resource "random_string" "db_pass" {
    length = 18
    min_upper = 1 
    min_lower = 1 
    min_numeric = 1 
    special = false
}

resource "random_string" "yugabyte_pass" {
    length = 18
    min_upper = 1 
    min_lower = 1 
    min_numeric = 1 
    special = false
}

data "template_file" "yugabytedb_values" {
    template = file("${path.module}/templates/yugabytedb/yugabytedb_values.yaml")
}

data "template_file" "configmap_sql_schema" {
    template = file("${path.module}/templates/yugabytedb/configmap_sql_schema.yaml")
    vars = {
        db_name = var.cluster_name
        db_pass = random_string.db_pass.result
        yugabyte_pass = random_string.yugabyte_pass.result
    }
}

data "template_file" "job_create_sql_schema" {
    template = file("${path.module}/templates/yugabytedb/job_create_sql_schema.yaml")
}

data "template_file" "wait_for_yugabytedb" {
    template = file("${path.module}/templates/scripts/wait_for_yugabytedb.sh")
}

resource "null_resource" "install_yugabytedb" {
    depends_on = [
        null_resource.install_helm,
        null_resource.install_csi
    ]
    connection {
        type = "ssh"
        user = "root"
        private_key = chomp(tls_private_key.ssh_key_pair.private_key_pem)
        host = packet_device.k3s_master_node.access_public_ipv4
    }

    provisioner "remote-exec" {
        inline = ["mkdir -p /root/bootstrap/yugabytedb/"]
    }

    provisioner "file" {
        content = data.template_file.yugabytedb_values.rendered
        destination = "/root/bootstrap/yugabytedb/yugabytedb_values.yaml"
    }

    provisioner "file" {
        content = data.template_file.configmap_sql_schema.rendered
        destination = "/root/bootstrap/yugabytedb/configmap_sql_schema.yaml"
    }

    provisioner "file" {
        content = data.template_file.job_create_sql_schema.rendered
        destination = "/root/bootstrap/yugabytedb/job_create_sql_schema.yaml"
    }

    provisioner "file"{
        content = data.template_file.wait_for_yugabytedb.rendered
        destination = "/root/bootstrap/scripts/wait_for_yugabytedb.sh"
    }

    provisioner "remote-exec" {
        inline = [
            "helm repo add yugabytedb https://charts.yugabyte.com",
            "helm repo update",
            "YUGABYTE_NAMESPACE='yugabytedb'",
            "kubectl create ns $YUGABYTE_NAMESPACE",
            "helm install yugabytedb yugabytedb/yugabyte --namespace $YUGABYTE_NAMESPACE -f /root/bootstrap/yugabytedb/yugabytedb_values.yaml",
            "kubectl -n $YUGABYTE_NAMESPACE apply -f /root/bootstrap/yugabytedb/configmap_sql_schema.yaml",
            "bash /root/bootstrap/scripts/wait_for_yugabytedb.sh $YUGABYTE_NAMESPACE",
            "kubectl -n $YUGABYTE_NAMESPACE apply -f /root/bootstrap/yugabytedb/job_create_sql_schema.yaml"
        ]
    }
}

data "template_file" "kubeconfig" {
    depends_on = [
        null_resource.download_kubeconfig
    ]
    template = file("${path.module}/k3s_kubeconfig")
}
