module "jump" {
  source = "./mod/jump"

  os_users    = "${var.os_users}"
  os_seed_uid = "${local.os_seed_uid}"
  os_seed_gid = "${local.os_seed_gid}"

  vm_name                 = "jump"
  vm_num_cpu              = "4"
  vm_num_cores_per_socket = "2"
  vm_memory               = "8192"

  network_domain       = "${var.network_domain}"
  network_hostname     = "jump.${var.network_domain}"
  network_device       = "${var.network_device}"
  network_dhcp         = "${var.network_dhcp}"
  network_dns_1        = "${var.network_dns_1}"
  network_dns_2        = "${var.network_dns_2}"
  network_domains      = "${var.network_domains}"
  network_ipv4_address = "192.168.2.2/24"
  network_ipv4_gateway = "${var.network_ipv4_gateway}"

  vsphere_datacenter    = "${data.vsphere_datacenter.datacenter.id}"
  vsphere_resource_pool = "${data.vsphere_resource_pool.resource_pool.id}"
  vsphere_datastore     = "${data.vsphere_datastore.datastore.id}"
  vsphere_folder        = "${var.vsphere_folder}"
  vsphere_network       = "${data.vsphere_network.network.id}"
  vsphere_template      = "${var.vsphere_template}"
}

