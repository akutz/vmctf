////////////////////////////////////////////////////////////////////////////////
//                                Filesystem                                  //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_kube_scheduler_root" {
  filesystem = "root"
  path       = "/var/lib/kube-scheduler"

  // mode = 0755
  mode = 493
}

////////////////////////////////////////////////////////////////////////////////
//                                  TLS                                       //
////////////////////////////////////////////////////////////////////////////////
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

////////////////////////////////////////////////////////////////////////////////
//                                Kubeconfig                                  //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_scheduler_kubeconfig" {
  template = "${file("${path.module}/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://127.0.0.1:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_fqdn}"
    user_name    = "system:kube-scheduler"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.master_kube_scheduler.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.master_kube_scheduler.private_key_pem)}"
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

////////////////////////////////////////////////////////////////////////////////
//                          Kube-Scheduler Config                             //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_scheduler_config" {
  template = "${file("${path.module}/master/etc/kube_scheduler.yaml")}"

  vars {
    kubeconfig = "${data.ignition_file.master_kube_scheduler_kubeconfig.path}"
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

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_scheduler_env" {
  template = "${file("${path.module}/master/etc/kube_scheduler.env")}"

  vars {
    config = "${data.ignition_file.master_kube_scheduler_config.path}"
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

data "template_file" "master_kube_scheduler_service" {
  template = "${file("${path.module}/master/systemd/kube_scheduler.service")}"

  vars {
    working_directory = "${data.ignition_directory.master_kube_scheduler_root.path}"
    env_file          = "${data.ignition_file.master_kube_scheduler_env.path}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kube-scheduler"
  }
}

data "ignition_systemd_unit" "master_kube_scheduler_service" {
  name    = "kube-scheduler.service"
  content = "${data.template_file.master_kube_scheduler_service.rendered}"
}
