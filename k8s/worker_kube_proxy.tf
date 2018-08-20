////////////////////////////////////////////////////////////////////////////////
//                                Filesystem                                  //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "worker_kube_proxy_root" {
  filesystem = "root"
  path       = "/var/lib/kube-proxy"

  // mode = 0755
  mode = 493
}

////////////////////////////////////////////////////////////////////////////////
//                                Kubeconfig                                  //
////////////////////////////////////////////////////////////////////////////////

resource "tls_private_key" "worker_kube_proxy" {
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "worker_kube_proxy" {
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.worker_kube_proxy.private_key_pem}"

  subject {
    common_name         = "system:kube-proxy"
    organization        = "system:node-proxier"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }
}

resource "tls_locally_signed_cert" "worker_kube_proxy" {
  cert_request_pem      = "${tls_cert_request.worker_kube_proxy.cert_request_pem}"
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

data "template_file" "worker_kube_proxy_kubeconfig" {
  template = "${file("${path.module}/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://${local.cluster_fqdn}:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_fqdn}"
    user_name    = "system:kube-proxy"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.worker_kube_proxy.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.worker_kube_proxy.private_key_pem)}"
  }
}

data "ignition_file" "worker_kube_proxy_kubeconfig" {
  filesystem = "root"
  path       = "${data.ignition_directory.worker_kube_proxy_root.path}/kubeconfig"

  // mode = 0640
  mode = 416

  content {
    content = "${data.template_file.worker_kube_proxy_kubeconfig.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                            Kube-Proxy Config                               //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "worker_kube_proxy_config" {
  template = "${file("${path.module}/worker/etc/kube_proxy.conf.yaml")}"

  vars {
    kubeconfig   = "${data.ignition_file.worker_kube_proxy_kubeconfig.path}"
    cluster_cidr = "${var.cluster_cidr}"
  }
}

data "ignition_file" "worker_kube_proxy_config" {
  filesystem = "root"
  path       = "${data.ignition_directory.worker_kube_proxy_root.path}/kube-proxy-config.yaml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_kube_proxy_config.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "worker_kube_proxy_env" {
  template = "${file("${path.module}/worker/etc/kube_proxy.env")}"

  vars {
    config = "${data.ignition_file.worker_kube_proxy_config.path}"
  }
}

data "ignition_file" "worker_kube_proxy_env" {
  filesystem = "root"
  path       = "/etc/default/kube-proxy"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_kube_proxy_env.rendered}"
  }
}

data "template_file" "worker_kube_proxy_service" {
  template = "${file("${path.module}/worker/systemd/kube_proxy.service")}"

  vars {
    working_directory = "${data.ignition_directory.worker_kube_proxy_root.path}"
    env_file          = "${data.ignition_file.worker_kube_proxy_env.path}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kube-proxy"
  }
}

data "ignition_systemd_unit" "worker_kube_proxy_service" {
  name    = "kube-proxy.service"
  content = "${data.template_file.worker_kube_proxy_service.rendered}"
}
