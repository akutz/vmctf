////////////////////////////////////////////////////////////////////////////////
//                                Filesystem                                  //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_kube_controller_manager_root" {
  filesystem = "root"
  path       = "/var/lib/kube-controller-manager"

  // mode = 0755
  mode = 493
}

////////////////////////////////////////////////////////////////////////////////
//                                  TLS                                       //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "master_kube_controller_manager" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_kube_controller_manager" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_kube_controller_manager.private_key_pem}"

  subject {
    common_name         = "system:kube-controller-manager"
    organization        = "system:kube-controller-manager"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_kube_controller_manager" {
  cert_request_pem      = "${tls_cert_request.master_kube_controller_manager.cert_request_pem}"
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

////////////////////////////////////////////////////////////////////////////////
//                                Kubeconfig                                  //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_controller_manager_kubeconfig" {
  template = "${file("${path.module}/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://127.0.0.1:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_fqdn}"
    user_name    = "system:kube-controller-manager"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.master_kube_controller_manager.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.master_kube_controller_manager.private_key_pem)}"
  }
}

data "ignition_file" "master_kube_controller_manager_kubeconfig" {
  filesystem = "root"
  path       = "${data.ignition_directory.master_kube_controller_manager_root.path}/kubeconfig"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_controller_manager_kubeconfig.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_controller_manager_env" {
  template = "${file("${path.module}/master/etc/kube_controller_manager.env")}"

  vars {
    address                     = "0.0.0.0"
    cloud_config                = "${data.ignition_file.vsphere_cloud_provider_conf.path}"
    cluster_cidr                = "${var.cluster_cidr}"
    cluster_name                = "${local.cluster_fqdn}"
    cluster_signing_cert_file   = "${data.ignition_file.tls_ca_crt.path}"
    cluster_signing_key_file    = "${data.ignition_file.tls_ca_key.path}"
    kubeconfig                  = "${data.ignition_file.master_kube_controller_manager_kubeconfig.path}"
    root_ca_file                = "${data.ignition_file.tls_ca_crt.path}"
    service_account_private_key = "${data.ignition_file.k8s_service_accounts_tls_key.path}"
    service_cluster_ip_range    = "${var.service_cluster_ip_range}"
  }
}

data "ignition_file" "master_kube_controller_manager_env" {
  filesystem = "root"
  path       = "/etc/default/kube-controller-manager"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_controller_manager_env.rendered}"
  }
}

data "template_file" "master_kube_controller_manager_service" {
  template = "${file("${path.module}/master/systemd/kube_controller_manager.service")}"

  vars {
    working_directory = "${data.ignition_directory.master_kube_controller_manager_root.path}"
    env_file          = "${data.ignition_file.master_kube_controller_manager_env.path}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kube-controller-manager"
  }
}

data "ignition_systemd_unit" "master_kube_controller_manager_service" {
  name    = "kube-controller-manager.service"
  content = "${data.template_file.master_kube_controller_manager_service.rendered}"
}
