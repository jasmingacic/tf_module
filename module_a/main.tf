provider "packet" {
  auth_token = var.api_key
}

resource "packet_device" "my_tf_server" {
  hostname         = var.name
  plan             = "t1.small.x86"
  facilities       = ["ewr1"]
  operating_system = "centos_7"
  billing_cycle    = "hourly"
  project_id       = var.project_id
  provisioner "local-exec" {
    command = "echo blah"
  }
}


output "IP_Address" {
  value = packet_device.my_tf_server.access_public_ipv4
}