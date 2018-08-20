////////////////////////////////////////////////////////////////////////////////
//                               Networking                                   //
////////////////////////////////////////////////////////////////////////////////

// https://www.freedesktop.org/software/systemd/man/systemd.network.html

data "template_file" "networkd_unit" {
  count = "${var.count}"

  template = "${file("${path.module}/systemd/networkd.unit")}"

  vars {
    network_device       = "${var.network_device}"
    network_dhcp         = "${var.network_dhcp}"
    network_dns_1        = "${var.network_dns_1}"
    network_dns_2        = "${var.network_dns_2}"
    network_domains      = "${var.network_search_domains}"
    network_ipv4_address = "${data.template_file.network_ipv4_address.*.rendered[count.index]}",
    network_ipv4_gateway = "${var.network_ipv4_gateway}"
  }
}

data "template_file" "network_ipv4_address" {
  count    = "${var.count}"
  template = "${cidrhost(var.network_ipv4_address, count.index)}"
}

data "template_file" "network_hostname" {
  count    = "${var.count}"
  template = "${format(var.network_hostname, count.index+1, var.network_domain)}"
}

data "template_file" "dns_entry" {
  count    = "${var.count}"
  template = "${format("%s=%s", data.template_file.network_hostname.*.rendered[count.index], data.template_file.network_ipv4_address.*.rendered[count.index])}"
}

data "ignition_networkd_unit" "networkd_unit" {
  count = "${var.count}"

  name    = "00-${var.network_device}.network"
  content = "${data.template_file.networkd_unit.*.rendered[count.index]}"
}


////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "hostname" {
  count = "${var.count}"

  filesystem = "root"
  path       = "/etc/hostname"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.network_hostname.*.rendered[count.index]}"
  }
}

