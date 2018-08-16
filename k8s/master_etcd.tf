////////////////////////////////////////////////////////////////////////////////
//                                Locals                                      //
////////////////////////////////////////////////////////////////////////////////
locals {
  master_etcd_name  = "etcd-%02d"
  master_etcd_token = "${uuid()}"
  master_etcd_uid   = "232"
  master_etcd_user  = "etcd"
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_etcd_root" {
  filesystem = "root"
  path       = "/var/lib/etcd"

  // mode = 0755
  mode = 493
  uid  = "${local.master_etcd_uid}"
}

data "ignition_directory" "master_etcd_data" {
  filesystem = "root"
  path       = "${data.ignition_directory.master_etcd_root.path}/data"

  // mode = 0755
  mode = 493
  uid  = "${local.master_etcd_uid}"
}

////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_etcd_name" {
  count    = "${var.master_count}"
  template = "${format(local.master_etcd_name, count.index)}"
}
data "template_file" "master_etcd_peer_endpoint" {
  count    = "${var.master_count}"
  template = "${data.template_file.master_etcd_name.*.rendered[count.index]}=https://${data.template_file.master_network_ipv4_address.*.rendered[count.index]}:2380"
}

data "template_file" "master_etcd_client_endpoint" {
  count    = "${var.master_count}"
  template = "https://${data.template_file.master_network_ipv4_address.*.rendered[count.index]}:2379"
}

data "template_file" "master_etcd_service" {
  count = "${var.master_count}"

  template = "${file("${path.module}/master/systemd/etcd.service")}"

  vars {
    user              = "${local.master_etcd_user}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/etcd"
    env_file          = "${data.ignition_file.master_etcd_env.*.path[count.index]}"
    working_directory = "${data.ignition_directory.master_etcd_root.path}"
  }
}

data "template_file" "master_etcd_env" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/etcd.env")}"

  vars {
    etcd_data               = "${data.ignition_directory.master_etcd_data.path}"
    etcd_name               = "${data.template_file.master_etcd_name.*.rendered[count.index]}"
    etcd_peers              = "${join(",", data.template_file.master_etcd_peer_endpoint.*.rendered)}"
    etcd_token              = "${local.master_etcd_token}"
    network_ipv4_address    = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    etcd_listen_client_urls = "https://127.0.0.1:2379,${data.template_file.master_etcd_client_endpoint.*.rendered[count.index]}"
    tls_ca                  = "${data.ignition_file.tls_ca_crt.path}"
    tls_client_crt          = "${data.ignition_file.master_etcd_tls_client_crt.*.path[count.index]}"
    tls_client_key          = "${data.ignition_file.master_etcd_tls_client_key.*.path[count.index]}"
    tls_peer_crt            = "${data.ignition_file.master_etcd_tls_peer_crt.*.path[count.index]}"
    tls_peer_key            = "${data.ignition_file.master_etcd_tls_peer_key.*.path[count.index]}"
  }
}

data "template_file" "master_etcdctl_sh" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/etcdctl.sh")}"

  vars {
    etcd_endpoints = "https://127.0.0.1:2379"
    tls_crt        = "${data.ignition_file.master_etcdctl_tls_crt.*.path[count.index]}"
    tls_key        = "${data.ignition_file.master_etcdctl_tls_key.*.path[count.index]}"
    tls_ca         = "${data.ignition_file.tls_ca_crt.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                Ignition                                    //
////////////////////////////////////////////////////////////////////////////////

data "ignition_file" "master_etcd_env" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "/etc/default/etcd"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_etcd_env.*.rendered[count.index]}"
  }
}

data "ignition_file" "master_etcdctl_sh" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "/etc/profile.d/etcdctl.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${data.template_file.master_etcdctl_sh.*.rendered[count.index]}"
  }
}

data "ignition_file" "master_etcdctl_tls_crt" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/etcdctl.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_locally_signed_cert.master_etcdctl.*.cert_pem[count.index]}"
  }
}

data "ignition_file" "master_etcdctl_tls_key" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/etcdctl.key"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_private_key.master_etcdctl.*.private_key_pem[count.index]}"
  }
}

data "ignition_file" "master_etcd_tls_client_crt" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/etcd_client.crt"

  // mode = 0444
  mode = 292
  uid  = "${local.master_etcd_uid}"

  content {
    content = "${tls_locally_signed_cert.master_etcd_client.*.cert_pem[count.index]}"
  }
}

data "ignition_file" "master_etcd_tls_client_key" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/etcd_client.key"

  // mode = 0400
  mode = 256
  uid  = "${local.master_etcd_uid}"

  content {
    content = "${tls_private_key.master_etcd_client.*.private_key_pem[count.index]}"
  }
}

data "ignition_file" "master_etcd_tls_peer_crt" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/etcd_peer.crt"

  // mode = 0444
  mode = 292
  uid  = "${local.master_etcd_uid}"

  content {
    content = "${tls_locally_signed_cert.master_etcd_peer.*.cert_pem[count.index]}"
  }
}

data "ignition_file" "master_etcd_tls_peer_key" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/etcd_peer.key"

  // mode = 0400
  mode = 256
  uid  = "${local.master_etcd_uid}"

  content {
    content = "${tls_private_key.master_etcd_peer.*.private_key_pem[count.index]}"
  }
}

data "ignition_systemd_unit" "master_etcd_service" {
  count   = "${var.master_count}"
  name    = "etcd.service"
  content = "${data.template_file.master_etcd_service.*.rendered[count.index]}"
}

////////////////////////////////////////////////////////////////////////////////
//                                  TLS                                       //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "master_etcdctl" {
  count     = "${var.master_count}"
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_etcdctl" {
  count           = "${var.master_count}"
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_etcdctl.*.private_key_pem[count.index]}"

  subject {
    common_name         = "etcdctl@${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_etcdctl" {
  count                 = "${var.master_count}"
  cert_request_pem      = "${tls_cert_request.master_etcdctl.*.cert_request_pem[count.index]}"
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

resource "tls_private_key" "master_etcd_client" {
  count     = "${var.master_count}"
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_etcd_client" {
  count = "${var.master_count}"

  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_etcd_client.*.private_key_pem[count.index]}"

  ip_addresses = [
    "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}",
    "127.0.0.1",
  ]

  dns_names = [
    "${data.template_file.master_network_hostname.*.rendered[count.index]}",
    "localhost",
  ]

  subject {
    common_name         = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_etcd_client" {
  count                 = "${var.master_count}"
  cert_request_pem      = "${tls_cert_request.master_etcd_client.*.cert_request_pem[count.index]}"
  ca_key_algorithm      = "${local.tls_alg}"
  ca_private_key_pem    = "${local.tls_ca_key}"
  ca_cert_pem           = "${local.tls_ca_crt}"
  validity_period_hours = "${local.tls_expiry}"

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",

    // client_auth should not be required for the client server, but without
    // it there are warnings starting etcd. It's clear that etcd is using
    // this certificate to connect back to its own client server, and if
    // this certificate lacks the client_auth key usage the client server
    // rejects it as a valid client certificate.
    "client_auth",
  ]
}


resource "tls_private_key" "master_etcd_peer" {
  count     = "${var.master_count}"
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_etcd_peer" {
  count = "${var.master_count}"

  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_etcd_peer.*.private_key_pem[count.index]}"

  ip_addresses = [
    "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}",
    "127.0.0.1",
  ]

  dns_names = [
    "${data.template_file.master_network_hostname.*.rendered[count.index]}",
    "localhost",
  ]

  subject {
    common_name         = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_etcd_peer" {
  count                 = "${var.master_count}"
  cert_request_pem      = "${tls_cert_request.master_etcd_peer.*.cert_request_pem[count.index]}"
  ca_key_algorithm      = "${local.tls_alg}"
  ca_private_key_pem    = "${local.tls_ca_key}"
  ca_cert_pem           = "${local.tls_ca_crt}"
  validity_period_hours = "${local.tls_expiry}"

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
    "client_auth",
  ]
}
