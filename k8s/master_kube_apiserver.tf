////////////////////////////////////////////////////////////////////////////////
//                                Globals                                     //
////////////////////////////////////////////////////////////////////////////////
locals {
  master_k8s_admission_plugins = [
    "Initializers",
    "NamespaceLifecycle",
    "NodeRestriction",
    "LimitRanger",
    "ServiceAccount",
    "DefaultStorageClass",
    "ResourceQuota",
  ]

  master_k8s_secure_port = "443"
}

////////////////////////////////////////////////////////////////////////////////
//                            K8s Admin Kubeconfig                            //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kubeconfig" {
  template = "${file("${path.module}/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://127.0.0.1:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_fqdn}"
    user_name    = "admin"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.k8s_admin.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.k8s_admin.private_key_pem)}"
  }
}

data "ignition_file" "master_kubeconfig" {
  filesystem = "root"
  path       = "${data.ignition_directory.kubernetes_root.path}/kubeconfig"

  // mode = 0640
  mode = 416

  content {
    content = "${data.template_file.master_kubeconfig.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                              Encryption Config                             //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_encryption_config" {
  template = "${file("${path.module}/master/etc/encryption_config.yaml")}"

  vars {
    encryption_key = "${var.k8s_encryption_key}"
  }
}

data "ignition_file" "master_kube_encryption_config" {
  filesystem = "root"
  path       = "${data.ignition_directory.kubernetes_root.path}/encryption_config.yaml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_encryption_config.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                          Kube API Server TLS                               //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "master_kube_apiserver" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_kube_apiserver" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_kube_apiserver.private_key_pem}"

  subject {
    common_name         = "${local.cluster_fqdn}"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }

  ip_addresses = [
    "${concat(list("127.0.0.1"), data.template_file.master_network_ipv4_address.*.rendered)}",
  ]

  dns_names = [
    "${concat(list(local.cluster_fqdn), data.template_file.master_network_hostname.*.rendered, var.cluster_sans_dns_names)}",
  ]
}

resource "tls_locally_signed_cert" "master_kube_apiserver" {
  cert_request_pem      = "${tls_cert_request.master_kube_apiserver.cert_request_pem}"
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

data "ignition_file" "master_kube_apiserver_tls_crt" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/kube_apiserver.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_locally_signed_cert.master_kube_apiserver.cert_pem}"
  }
}

data "ignition_file" "master_kube_apiserver_tls_key" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/kube_apiserver.key"

  // mode = 0400
  mode = 256

  content {
    content = "${tls_private_key.master_kube_apiserver.private_key_pem}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                           Kube API Server SystemD                          //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_apiserver_env" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/kube_apiserver.env")}"

  vars {
    advertise_address                       = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    allow_privileged                        = "true"
    apiserver_count                         = "${var.master_count}"
    bind_address                            = "0.0.0.0"
    client_ca_file                          = "${data.ignition_file.tls_ca_crt.path}"
    cloud_config                            = "${data.ignition_file.vsphere_cloud_provider_conf.path}"
    enable_admission_plugins                = "${join(",", local.master_k8s_admission_plugins)}"
    etcd_cafile                             = "${data.ignition_file.tls_ca_crt.path}"
    etcd_certfile                           = "${data.ignition_file.master_etcd_tls_client_crt.*.path[count.index]}"
    etcd_keyfile                            = "${data.ignition_file.master_etcd_tls_client_key.*.path[count.index]}"
    etcd_servers                            = "${join(",",data.template_file.master_etcd_client_endpoint.*.rendered)}"
    experimental_encryption_provider_config = "${data.ignition_file.master_kube_encryption_config.path}"
    kubelet_certificate_authority           = "${data.ignition_file.tls_ca_crt.path}"
    kubelet_client_certificate              = "${data.ignition_file.master_kube_apiserver_tls_crt.path}"
    kubelet_client_key                      = "${data.ignition_file.master_kube_apiserver_tls_key.path}"
    secure_port                             = "${var.master_api_secure_port}"
    service_account_key_file                = "${data.ignition_file.k8s_service_accounts_tls_key.path}"
    service_cluster_ip_range                = "${var.service_cluster_ip_range}"
    tls_cert_file                           = "${data.ignition_file.master_kube_apiserver_tls_crt.path}"
    tls_private_key_file                    = "${data.ignition_file.master_kube_apiserver_tls_key.path}"
  }
}

data "ignition_file" "master_kube_apiserver_env" {
  count = "${var.master_count}"

  filesystem = "root"
  path       = "/etc/default/kube-apiserver"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_apiserver_env.*.rendered[count.index]}"
  }
}

data "template_file" "master_kube_apiserver_service" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/systemd/kube_apiserver.service")}"

  vars {
    working_directory = "${data.ignition_directory.kubernetes_root.path}"
    env_file          = "${data.ignition_file.master_kube_apiserver_env.*.path[count.index]}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kube-apiserver"
  }
}

data "ignition_systemd_unit" "master_kube_apiserver_service" {
  count   = "${var.master_count}"
  name    = "kube-apiserver.service"
  content = "${data.template_file.master_kube_apiserver_service.*.rendered[count.index]}"
}
