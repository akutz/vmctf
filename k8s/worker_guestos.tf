////////////////////////////////////////////////////////////////////////////////
//                               Networking                                   //
////////////////////////////////////////////////////////////////////////////////

// https://www.freedesktop.org/software/systemd/man/systemd.network.html

data "template_file" "worker_networkd_unit" {
  count = "${var.worker_count}"

  template = "${file("${path.module}/worker/systemd/networkd.unit")}"

  vars {
    network_device       = "${var.network_device}"
    network_dhcp         = "${var.network_dhcp}"
    network_domains      = "${var.network_search_domains}"
    network_ipv4_address = "${data.template_file.worker_network_ipv4_address.*.rendered[count.index]}"
    network_ipv4_gateway = "${var.network_ipv4_gateway}"
    network_dns          = "${join("\n", formatlist("DNS=%s", data.template_file.master_network_ipv4_address.*.rendered))}"
    pod_cidr             = "${data.template_file.worker_pod_cidr.*.rendered[count.index]}"
  }
}

data "template_file" "worker_network_ipv4_address" {
  count    = "${var.worker_count}"
  template = "${cidrhost(var.worker_network_ipv4_address, count.index)}"
}

data "template_file" "worker_network_hostname" {
  count    = "${var.worker_count}"
  template = "${format(var.worker_network_hostname, count.index+1)}.${var.network_domain}"
}

data "template_file" "worker_nodename" {
  count    = "${var.worker_count}"
  template = "${format(var.worker_network_hostname, count.index+1)}"
}

data "template_file" "worker_dns_entry" {
  count    = "${var.worker_count}"
  template = "${format("%s=%s", data.template_file.worker_network_hostname.*.rendered[count.index], data.template_file.worker_network_ipv4_address.*.rendered[count.index])}"
}

data "ignition_networkd_unit" "worker_networkd_unit" {
  count = "${var.worker_count}"

  name    = "00-${var.network_device}.network"
  content = "${data.template_file.worker_networkd_unit.*.rendered[count.index]}"
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "worker_hostname" {
  count = "${var.worker_count}"

  filesystem = "root"
  path       = "/etc/hostname"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_network_hostname.*.rendered[count.index]}"
  }
}
