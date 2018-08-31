data "template_file" "cloud_provider_config" {
  template = <<EOF
[Global]
  user               = "$${username}"
  password           = "$${password}"
  port               = "$${port}"
  insecure-flag      = "$${insecure}"
  datacenters        = "$${datacenter}"

[VirtualCenter "$${server}"]

[Workspace]
  server             = "$${server}"
  datacenter         = "$${datacenter}"
  folder             = "$${folder}"
  default-datastore  = "$${datastore}"
  resourcepool-path  = "$${resource_pool}"

[Disk]
  scsicontrollertype = pvscsi

[Network]
  public-network     = "$${network}"
EOF

  vars {
    server        = "${var.vsphere_server}"
    username      = "${var.vsphere_user}"
    password      = "${var.vsphere_password}"
    port          = "${var.vsphere_server_port}"
    insecure      = "${var.vsphere_allow_unverified_ssl ? 1 : 0}"
    datacenter    = "${var.vsphere_datacenter}"
    folder        = "${var.vsphere_folder}"
    datastore     = "${var.vsphere_datastore}"
    resource_pool = "${var.vsphere_resource_pool}"
    network       = "${var.vsphere_network}"
  }
}
