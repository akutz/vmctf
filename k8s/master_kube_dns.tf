data "template_file" "master_kube_dns_config" {
  template = "${file("${path.module}/master/etc/kube_dns.yaml")}"

  vars {
    dns_cluster_ip = "${local.dns_cluster_ip}"
    cluster_name   = "${var.cluster_name}"
    network_domain = "${var.network_domain}"
  }
}

data "ignition_file" "master_kube_dns_config" {
  filesystem = "root"
  path       = "${data.ignition_directory.kubernetes_root.path}/kube-dns.yaml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_dns_config.rendered}"
  }
}
