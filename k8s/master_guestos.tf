////////////////////////////////////////////////////////////////////////////////
//                               Networking                                   //
////////////////////////////////////////////////////////////////////////////////

// https://www.freedesktop.org/software/systemd/man/systemd.network.html

data "template_file" "master_networkd_unit" {
  count = "${var.master_count}"

  template = "${file("${path.module}/master/systemd/networkd.unit")}"

  vars {
    network_device       = "${var.network_device}"
    network_dhcp         = "${var.network_dhcp}"
    network_dns_1        = "${var.network_dns_1}"
    network_dns_2        = "${var.network_dns_2}"
    network_domains      = "${var.network_search_domains}"
    network_ipv4_address = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}",
    network_ipv4_gateway = "${var.network_ipv4_gateway}"
  }
}

data "template_file" "master_network_ipv4_address" {
  count    = "${var.master_count}"
  template = "${cidrhost(var.master_network_ipv4_address, count.index)}"
}

data "template_file" "master_network_hostname" {
  count    = "${var.master_count}"
  template = "${format(var.master_network_hostname, count.index+1)}.${var.network_domain}"
}

data "template_file" "master_nodename" {
  count    = "${var.master_count}"
  template = "${format(var.master_network_hostname, count.index+1)}"
}

data "template_file" "master_dns_entry" {
  count    = "${var.master_count}"
  template = "${format("%s=%s", data.template_file.master_network_hostname.*.rendered[count.index], data.template_file.master_network_ipv4_address.*.rendered[count.index])}"
}

data "ignition_networkd_unit" "master_networkd_unit" {
  count = "${var.master_count}"

  name    = "00-${var.network_device}.network"
  content = "${data.template_file.master_networkd_unit.*.rendered[count.index]}"
}


////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "master_hostname" {
  count = "${var.master_count}"

  filesystem = "root"
  path       = "/etc/hostname"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_network_hostname.*.rendered[count.index]}"
  }
}

