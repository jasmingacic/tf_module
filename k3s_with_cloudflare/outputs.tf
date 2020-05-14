output "kubeconfig" {
  value = module.create_k3s.kubeconfig
}

output "yugabyte_pass" {
  value = module.create_k3s.yugabyte_pass
}

output "db_pass" {
  value = module.create_k3s.db_pass
}