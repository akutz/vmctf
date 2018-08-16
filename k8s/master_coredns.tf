////////////////////////////////////////////////////////////////////////////////
//                             Users & Groups                                 //
////////////////////////////////////////////////////////////////////////////////
data "ignition_group" "master_coredns" {
  name = "coredns"
  gid  = "301"
}

data "ignition_user" "master_coredns" {
  name           = "coredns"
  uid            = "301"
  home_dir       = "/var/lib/coredns"
  no_create_home = true
  no_user_group  = true

  system        = true
  primary_group = "${data.ignition_group.master_coredns.gid}"
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_coredns_root" {
  filesystem = "root"
  path       = "${data.ignition_user.master_coredns.home_dir}"

  // mode = 0755
  mode = 493
  uid  = "${data.ignition_user.master_coredns.uid}"
}

data "ignition_file" "master_coredns_corefile" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "/etc/coredns/etcd.conf"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_coredns_corefile.*.rendered[count.index]}"
  }
}

data "ignition_file" "master_coredns_init_env" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "/etc/default/coredns-init"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_coredns_init_env.*.rendered[count.index]}"
  }
}

data "ignition_file" "master_coredns_init_sh" {
  filesystem = "root"
  path       = "${data.ignition_directory.bin_dir.path}/coredns-init.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${file("${path.module}/master/scripts/coredns_init.sh")}"
  }
}

data "ignition_file" "master_coredns_tls_crt" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/coredns.crt"

  // mode = 0444
  mode = 292
  uid  = "${data.ignition_user.master_coredns.uid}"

  content {
    content = "${tls_locally_signed_cert.master_coredns.*.cert_pem[count.index]}"
  }
}

data "ignition_file" "master_coredns_tls_key" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/coredns.key"

  // mode = 0400
  mode = 256
  uid  = "${data.ignition_user.master_coredns.uid}"

  content {
    content = "${tls_private_key.master_coredns.*.private_key_pem[count.index]}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_coredns_init_service" {
  count = "${var.master_count}"

  template = "${file("${path.module}/master/systemd/coredns_init.service")}"

  vars {
    unit_name         = "coredns-init.service"
    env_file          = "${data.ignition_file.master_coredns_init_env.*.path[count.index]}"
    cmd_file          = "${data.ignition_file.master_coredns_init_sh.path}"
    working_directory = "${data.ignition_directory.bin_dir.path}"
  }
}

data "template_file" "master_coredns_service" {
  count = "${var.master_count}"

  template = "${file("${path.module}/master/systemd/coredns.service")}"

  vars {
    user              = "${data.ignition_user.master_coredns.name}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/coredns"
    conf_file         = "${data.ignition_file.master_coredns_corefile.*.path[count.index]}"
    working_directory = "${data.ignition_directory.master_coredns_root.path}"
  }
}

data "template_file" "master_coredns_init_env" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/coredns_init.env")}"

  vars {
    bin_dir         = "${data.ignition_directory.bin_dir.path}"
    dns_resolv_conf = "/etc/coredns/resolv.conf"
    dns_servers     = "127.0.0.1"
    dns_search      = "${var.network_domain}"
    dns_entries     = "${local.cluster_name}=${join(",", data.template_file.master_network_ipv4_address.*.rendered)} ${join(" ", data.template_file.master_dns_entry.*.rendered)} ${join(" ", data.template_file.worker_dns_entry.*.rendered)}"
    etcd_endpoints  = "https://127.0.0.1:2379"
    tls_crt         = "${data.ignition_file.master_coredns_tls_crt.*.path[count.index]}"
    tls_key         = "${data.ignition_file.master_coredns_tls_key.*.path[count.index]}"
    tls_ca          = "${data.ignition_file.tls_ca_crt.path}"
  }
}

data "template_file" "master_coredns_corefile" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/coredns.corefile")}"

  vars {
    network_domain           = "${var.network_domain}"
    network_dns_1            = "${var.network_dns_1}"
    network_dns_2            = "${var.network_dns_2}"
    network_ipv4_address     = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    network_ipv4_subnet_cidr = "${var.network_ipv4_gateway}/24"
    etcd_endpoints           = "https://127.0.0.1:2379"
    tls_crt                  = "${data.ignition_file.master_coredns_tls_crt.*.path[count.index]}"
    tls_key                  = "${data.ignition_file.master_coredns_tls_key.*.path[count.index]}"
    tls_ca                   = "${data.ignition_file.tls_ca_crt.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_systemd_unit" "master_coredns_service" {
  count   = "${var.master_count}"
  name    = "coredns.service"
  content = "${data.template_file.master_coredns_service.*.rendered[count.index]}"
}

data "ignition_systemd_unit" "master_coredns_init_service" {
  count   = "${var.master_count}"
  name    = "coredns-init.service"
  content = "${data.template_file.master_coredns_init_service.*.rendered[count.index]}"
}

data "ignition_systemd_unit" "master_dns_online_target" {
  name    = "dns-online.target"
  content = "${file("${path.module}/master/systemd/dns_online.target")}"
}

////////////////////////////////////////////////////////////////////////////////
//                                  TLS                                       //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "master_coredns" {
  count     = "${var.master_count}"
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_coredns" {
  count           = "${var.master_count}"
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_coredns.*.private_key_pem[count.index]}"

  subject {
    common_name         = "coredns@${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_coredns" {
  count                 = "${var.master_count}"
  cert_request_pem      = "${tls_cert_request.master_coredns.*.cert_request_pem[count.index]}"
  ca_key_algorithm      = "${local.tls_alg}"
  ca_private_key_pem    = "${local.tls_ca_key}"
  ca_cert_pem           = "${local.tls_ca_crt}"
  validity_period_hours = "${local.tls_expiry}"

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}
