////////////////////////////////////////////////////////////////////////////////
//                                vSphere                                     //
////////////////////////////////////////////////////////////////////////////////

data "vsphere_virtual_machine" "template" {
  name          = "${var.vsphere_template}"
  datacenter_id = "${var.vsphere_datacenter}"
}

////////////////////////////////////////////////////////////////////////////////
//                               Templates                                     //
////////////////////////////////////////////////////////////////////////////////

data "template_file" "networkd_unit" {
  template = "${file("${path.module}/../../tpl/net/networkd.unit")}"

  vars {
    network_device       = "${var.network_device}"
    network_dhcp         = "${var.network_dhcp}"
    network_dns_1        = "${var.network_dns_1}"
    network_dns_2        = "${var.network_dns_2}"
    network_domains      = "${var.network_domains}"
    network_ipv4_address = "${var.network_ipv4_address}"
    network_ipv4_gateway = "${var.network_ipv4_gateway}"
  }
}

data "template_file" "sshd_config" {
  template = "${file("${path.module}/../../tpl/os/sshd_config")}"

  vars {
    allow_users = "${join(" ", local.os_users_keys)}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                Ignition                                    //
////////////////////////////////////////////////////////////////////////////////

data "ignition_group" "groups" {
  count = "${local.os_users_count}"
  name  = "${element(local.os_users_keys, count.index)}"
  gid   = "${var.os_seed_gid + count.index}"
}

data "ignition_user" "users" {
  count         = "${local.os_users_count}"
  name          = "${element(local.os_users_keys, count.index)}"
  uid           = "${var.os_seed_uid + count.index}"
  no_user_group = "true"
  primary_group = "${element(local.os_users_keys, count.index)}"

  groups = [
    "wheel",
    "docker",
    "sudo",
  ]

  ssh_authorized_keys = [
    "${var.os_users[element(local.os_users_keys, count.index)]}",
  ]
}

data "ignition_file" "hostname" {
  filesystem = "root"
  path       = "/etc/hostname"
  mode       = 384

  content {
    content = "${var.network_hostname}"
  }
}

data "ignition_file" "sshd_config" {
  filesystem = "root"
  path       = "/etc/ssh/sshd_config"
  mode       = 384

  content {
    content = "${data.template_file.sshd_config.rendered}"
  }
}

data "ignition_networkd_unit" "networkd_unit" {
  name    = "00-${var.network_device}.network"
  content = "${data.template_file.networkd_unit.rendered}"
}

data "ignition_config" "config" {
  files = [
    "${data.ignition_file.hostname.id}",
    "${data.ignition_file.sshd_config.id}",
  ]

  networkd = [
    "${data.ignition_networkd_unit.networkd_unit.id}",
  ]

  groups = [
    "${data.ignition_group.groups.*.id}",
  ]

  users = [
    "${data.ignition_user.users.*.id}",
  ]
}
