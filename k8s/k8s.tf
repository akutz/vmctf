////////////////////////////////////////////////////////////////////////////////
//                                Globals                                     //
////////////////////////////////////////////////////////////////////////////////
locals {
  cluster_fqdn   = "${var.cluster_name}.${var.network_domain}"
  tls_ca_key     = "${file("${path.module}/../ca.key")}"
  tls_ca_crt     = "${file("${path.module}/../ca.crt")}"
  cluster_ip     = "${cidrhost(var.service_cluster_ip_range, "1")}"
  dns_cluster_ip = "${cidrhost(var.service_cluster_ip_range, "10")}"
}

// master_pod_cidr is reserved for future use in case workloads are scheduled
// on controller nodes
data "template_file" "master_pod_cidr" {
  count    = "${var.master_count}"
  template = "${format(var.pod_cidr, count.index)}"
}

// worker_pod_cidr is always calculated as an offset from the master_pod_cidr.
data "template_file" "worker_pod_cidr" {
  count    = "${var.worker_count}"
  template = "${format(var.pod_cidr, var.master_count + count.index)}"
}

data "ignition_directory" "kubernetes_root" {
  filesystem = "root"
  path       = "/var/lib/kubernetes"

  // mode = 0755
  mode = 493
}

data "ignition_directory" "kubernetes_run" {
  filesystem = "root"
  path       = "/var/run/kubernetes"

  // mode = 0755
  mode = 493
}

////////////////////////////////////////////////////////////////////////////////
//                             K8s Admin Kubeconfig                           //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "k8s_admin" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "k8s_admin" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.k8s_admin.private_key_pem}"

  subject {
    common_name         = "admin"
    organization        = "system:masters"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "k8s_admin" {
  cert_request_pem      = "${tls_cert_request.k8s_admin.cert_request_pem}"
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

data "template_file" "k8s_admin_kubeconfig" {
  template = "${file("${path.module}/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://${local.cluster_fqdn}:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_fqdn}"
    user_name    = "admin"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.k8s_admin.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.k8s_admin.private_key_pem)}"
  }
}

// Write the admin kubeconfig to the local workspace.
resource "local_file" "k8s_admin_kubeconfig" {
  content  = "${data.template_file.k8s_admin_kubeconfig.rendered}"
  filename = "${path.module}/../kubeconfig"
}

////////////////////////////////////////////////////////////////////////////////
//                            K8s Service Accounts                            //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "k8s_service_accounts" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "k8s_service_accounts" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.k8s_service_accounts.private_key_pem}"

  subject {
    common_name         = "service-accounts"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "k8s_service_accounts" {
  cert_request_pem      = "${tls_cert_request.k8s_service_accounts.cert_request_pem}"
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

data "ignition_file" "k8s_service_accounts_tls_crt" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/k8s_service_accounts.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_locally_signed_cert.k8s_service_accounts.cert_pem}"
  }
}

data "ignition_file" "k8s_service_accounts_tls_key" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/k8s_service_accounts.key"

  // mode = 0400
  mode = 256

  content {
    content = "${tls_private_key.k8s_service_accounts.private_key_pem}"
  }
}
