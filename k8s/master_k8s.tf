////////////////////////////////////////////////////////////////////////////////
//                                 Locals                                     //
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
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_apiserver_service" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/systemd/kube_apiserver.service")}"

  vars {
    working_directory = "${data.ignition_directory.master_kube_apiserver_root.path}"
    env_file          = "${data.ignition_file.master_kube_apiserver_env.*.path[count.index]}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kube-apiserver"
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

data "template_file" "master_kube_scheduler_service" {
  template = "${file("${path.module}/master/systemd/kube_scheduler.service")}"

  vars {
    working_directory = "${data.ignition_directory.master_kube_scheduler_root.path}"
    env_file          = "${data.ignition_file.master_kube_scheduler_env.path}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kube-scheduler"
  }
}

data "template_file" "master_kube_init_service" {
  template = "${file("${path.module}/master/systemd/kube_init.service")}"

  vars {
    unit_name         = "kube-init.service"
    env_file          = "${data.ignition_file.master_kube_init_env.path}"
    cmd_file          = "${data.ignition_file.master_kube_init_sh.path}"
    working_directory = "${data.ignition_directory.bin_dir.path}"
  }
}

data "ignition_systemd_unit" "master_kube_apiserver_service" {
  count   = "${var.master_count}"
  name    = "kube-apiserver.service"
  content = "${data.template_file.master_kube_apiserver_service.*.rendered[count.index]}"
}

data "ignition_systemd_unit" "master_kube_controller_manager_service" {
  name    = "kube-controller-manager.service"
  content = "${data.template_file.master_kube_controller_manager_service.rendered}"
}

data "ignition_systemd_unit" "master_kube_scheduler_service" {
  name    = "kube-scheduler.service"
  content = "${data.template_file.master_kube_scheduler_service.rendered}"
}

data "ignition_systemd_unit" "master_kube_online_target" {
  name    = "kube-online.target"
  content = "${file("${path.module}/master/systemd/kube_online.target")}"
}

data "ignition_systemd_unit" "master_kube_init_service" {
  name    = "kube-init.service"
  content = "${data.template_file.master_kube_init_service.rendered}"
}

////////////////////////////////////////////////////////////////////////////////
//                        Defaults - Templates                                //
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
    enable_admission_plugins                = "${join(",", local.master_k8s_admission_plugins)}"
    etcd_cafile                             = "${data.ignition_file.tls_ca_crt.path}"
    etcd_certfile                           = "${data.ignition_file.master_etcd_tls_client_crt.*.path[count.index]}"
    etcd_keyfile                            = "${data.ignition_file.master_etcd_tls_client_key.*.path[count.index]}"
    etcd_servers                            = "${join(",",data.template_file.master_etcd_client_endpoint.*.rendered)}"
    experimental_encryption_provider_config = "${data.ignition_file.master_kube_encryption_config.path}"
    kubelet_certificate_authority           = "${data.ignition_file.tls_ca_crt.path}"
    kubelet_client_certificate              = "${data.ignition_file.master_tls_kube_apiserver_crt.path}"
    kubelet_client_key                      = "${data.ignition_file.master_tls_kube_apiserver_key.path}"
    secure_port                             = "${var.master_api_secure_port}"
    service_account_key_file                = "${data.ignition_file.master_tls_k8s_service_accounts_key.path}"
    service_cluster_ip_range                = "10.32.0.0/24"
    tls_cert_file                           = "${data.ignition_file.master_tls_kube_apiserver_crt.path}"
    tls_private_key_file                    = "${data.ignition_file.master_tls_kube_apiserver_key.path}"
  }
}

data "template_file" "master_kube_controller_manager_env" {
  template = "${file("${path.module}/master/etc/kube_controller_manager.env")}"

  vars {
    address                     = "0.0.0.0"
    cluster_cidr                = "10.200.0.0/16"
    cluster_name                = "${local.cluster_name}"
    cluster_signing_cert_file   = "${data.ignition_file.tls_ca_crt.path}"
    cluster_signing_key_file    = "${data.ignition_file.tls_ca_key.path}"
    kubeconfig                  = "${data.ignition_file.master_kube_controller_manager_kubeconfig.path}"
    root_ca_file                = "${data.ignition_file.tls_ca_crt.path}"
    service_account_private_key = "${data.ignition_file.master_tls_k8s_service_accounts_key.path}"
    service_cluster_ip_range    = "10.32.0.0/24"
  }
}

data "template_file" "master_kube_scheduler_env" {
  template = "${file("${path.module}/master/etc/kube_scheduler.env")}"

  vars {
    config = "${data.ignition_file.master_kube_scheduler_config.path}"
  }
}

data "template_file" "master_kube_scheduler_config" {
  template = "${file("${path.module}/master/etc/kube_scheduler.yaml")}"

  vars {
    kubeconfig = "${data.ignition_file.master_kube_scheduler_kubeconfig.path}"
  }
}

data "template_file" "master_kube_controller_manager_kubeconfig" {
  template = "${file("${path.module}/master/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://127.0.0.1:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_name}"
    user_name    = "system:kube-controller-manager"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.master_kube_controller_manager.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.master_kube_controller_manager.private_key_pem)}"
  }
}

data "template_file" "master_kube_scheduler_kubeconfig" {
  template = "${file("${path.module}/master/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://127.0.0.1:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_name}"
    user_name    = "system:kube-scheduler"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.master_kube_scheduler.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.master_kube_scheduler.private_key_pem)}"
  }
}

data "template_file" "master_k8s_admin_kubeconfig" {
  template = "${file("${path.module}/master/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://127.0.0.1:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_name}"
    user_name    = "admin"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.master_k8s_admin.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.master_k8s_admin.private_key_pem)}"
  }
}

data "template_file" "master_kube_encryption_config" {
  template = "${file("${path.module}/master/etc/encryption_config.yaml")}"

  vars {
    encryption_key = "${var.k8s_encryption_key}"
  }
}

data "template_file" "master_kube_init_env" {
  template = "${file("${path.module}/master/etc/kube_init.env")}"

  vars {
    bin_dir        = "${data.ignition_directory.bin_dir.path}"
    etcd_endpoints = "https://127.0.0.1:2379"
    tls_crt        = "${data.ignition_file.master_tls_kube_apiserver_crt.path}"
    tls_key        = "${data.ignition_file.master_tls_kube_apiserver_key.path}"
    tls_ca         = "${data.ignition_file.tls_ca_crt.path}"
    kubeconfig     = "${data.ignition_file.master_k8s_admin_kubeconfig.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                Filesystem                                  //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_kube_controller_manager_root" {
  filesystem = "root"
  path       = "/var/lib/kube-controller-manager"

  // mode = 0755
  mode = 493
}

data "ignition_directory" "master_kube_scheduler_root" {
  filesystem = "root"
  path       = "/var/lib/kube-scheduler"

  // mode = 0755
  mode = 493
}

data "ignition_directory" "master_kube_apiserver_root" {
  filesystem = "root"
  path       = "/var/lib/kubernetes"

  // mode = 0755
  mode = 493
}

data "ignition_file" "master_k8s_admin_kubeconfig" {
  filesystem = "root"
  path       = "${data.ignition_directory.master_kube_apiserver_root.path}/admin.kubeconfig"

  // mode = 0640
  mode = 416

  content {
    content = "${data.template_file.master_k8s_admin_kubeconfig.rendered}"
  }
}

data "ignition_file" "master_kube_init_sh" {
  filesystem = "root"
  path       = "${data.ignition_directory.bin_dir.path}/kube_init.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${file("${path.module}/master/scripts/kube_init.sh")}"
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

data "ignition_file" "master_kube_controller_manager_env" {
  filesystem = "root"
  path       = "/etc/default/kube-controller-manager"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_controller_manager_env.rendered}"
  }
}

data "ignition_file" "master_kube_scheduler_env" {
  filesystem = "root"
  path       = "/etc/default/kube-scheduler"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_scheduler_env.rendered}"
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

data "ignition_file" "master_kube_scheduler_config" {
  filesystem = "root"
  path       = "${data.ignition_directory.master_kube_scheduler_root.path}/kube_scheduler.yaml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_scheduler_config.rendered}"
  }
}

data "ignition_file" "master_kube_scheduler_kubeconfig" {
  filesystem = "root"
  path       = "${data.ignition_directory.master_kube_scheduler_root.path}/kubeconfig"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_scheduler_kubeconfig.rendered}"
  }
}

data "ignition_file" "master_kube_encryption_config" {
  filesystem = "root"
  path       = "${data.ignition_directory.master_kube_apiserver_root.path}/encryption_config.yaml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_encryption_config.rendered}"
  }
}

data "ignition_file" "master_tls_kube_apiserver_crt" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/kube_apiserver.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_locally_signed_cert.master_kube_apiserver.cert_pem}"
  }
}

data "ignition_file" "master_tls_kube_apiserver_key" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/kube_apiserver.key"

  // mode = 0400
  mode = 256

  content {
    content = "${tls_private_key.master_kube_apiserver.private_key_pem}"
  }
}

data "ignition_file" "master_tls_k8s_service_accounts_crt" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/k8s_service_accounts.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_locally_signed_cert.master_k8s_service_accounts.cert_pem}"
  }
}

data "ignition_file" "master_tls_k8s_service_accounts_key" {
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/k8s_service_accounts.key"

  // mode = 0400
  mode = 256

  content {
    content = "${tls_private_key.master_k8s_service_accounts.private_key_pem}"
  }
}

data "ignition_file" "master_kube_init_env" {
  filesystem = "root"
  path       = "/etc/default/kube-init"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_init_env.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                  TLS                                       //
////////////////////////////////////////////////////////////////////////////////

//
// K8s admin user
// 
resource "tls_private_key" "master_k8s_admin" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_k8s_admin" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_k8s_admin.private_key_pem}"

  subject {
    common_name         = "admin"
    organization        = "system:masters"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_k8s_admin" {
  cert_request_pem      = "${tls_cert_request.master_k8s_admin.cert_request_pem}"
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

//
// K8s kube-controller-manager
//
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

//
// K8s kube-scheduler
//
resource "tls_private_key" "master_kube_scheduler" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_kube_scheduler" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_kube_scheduler.private_key_pem}"

  subject {
    common_name         = "system:kube-scheduler"
    organization        = "system:kube-scheduler"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_kube_scheduler" {
  cert_request_pem      = "${tls_cert_request.master_kube_scheduler.cert_request_pem}"
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

//
// K8s kube-api-server
//
resource "tls_private_key" "master_kube_apiserver" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_kube_apiserver" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_kube_apiserver.private_key_pem}"

  subject {
    common_name         = "${local.cluster_name}"
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
    "${concat(list(local.cluster_name), data.template_file.master_network_ipv4_address.*.rendered)}",
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

//
// K8s service-accounts
//
resource "tls_private_key" "master_k8s_service_accounts" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "master_k8s_service_accounts" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.master_k8s_service_accounts.private_key_pem}"

  subject {
    common_name         = "service-accounts"
    organization        = "${local.tls_subj_organization}"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "master_k8s_service_accounts" {
  cert_request_pem      = "${tls_cert_request.master_k8s_service_accounts.cert_request_pem}"
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
