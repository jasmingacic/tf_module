output "public_ips" {
    value = "${packet_device.k3s_worker_nodes.*.access_public_ipv4}"
}

#output "kubeconfig" {
#    value = data.template_file.kubeconfig.rendered
#}

output "yugabyte_pass" {
  value = random_string.yugabyte_pass.result
}

output "db_pass" {
  value = random_string.db_pass.result
}
