////////////////////////////////////////////////////////////////////////////////
//                                Filesystem                                  //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "worker_kubelet_root" {
  filesystem = "root"
  path       = "/var/lib/kubelet"

  // mode = 0755
  mode = 493
}

////////////////////////////////////////////////////////////////////////////////
//                              Kubelet TLS                                   //
////////////////////////////////////////////////////////////////////////////////
resource "tls_private_key" "worker_kubelet" {
  count     = "${var.worker_count}"
  algorithm = "${local.tls_alg}"
  rsa_bits  = "2048"
}

resource "tls_cert_request" "worker_kubelet" {
  count           = "${var.worker_count}"
  key_algorithm   = "${local.tls_alg}"
  private_key_pem = "${tls_private_key.worker_kubelet.*.private_key_pem[count.index]}"

  subject {
    common_name         = "system:node:${data.template_file.worker_nodename.*.rendered[count.index]}"
    organization        = "system:nodes"
    organizational_unit = "${local.tls_subj_organizational_unit}"
    country             = "${local.tls_subj_country}"
    province            = "${local.tls_subj_province}"
    locality            = "${local.tls_subj_locality}"
  }

  ip_addresses = [
    "${data.template_file.worker_network_ipv4_address.*.rendered[count.index]}",
  ]

  dns_names = [
    "${data.template_file.worker_nodename.*.rendered[count.index]}",
    "${data.template_file.worker_network_hostname.*.rendered[count.index]}",
  ]
}

resource "tls_locally_signed_cert" "worker_kubelet" {
  count                 = "${var.worker_count}"
  cert_request_pem      = "${tls_cert_request.worker_kubelet.*.cert_request_pem[count.index]}"
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

data "ignition_file" "worker_kubelet_tls_crt" {
  count      = "${var.worker_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/kubelet.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${tls_locally_signed_cert.worker_kubelet.*.cert_pem[count.index]}"
  }
}

data "ignition_file" "worker_kubelet_tls_key" {
  count      = "${var.worker_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.tls_dir.path}/kubelet.key"

  // mode = 0400
  mode = 256

  content {
    content = "${tls_private_key.worker_kubelet.*.private_key_pem[count.index]}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                            Kubelet Config                                  //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "worker_kubelet_config" {
  count    = "${var.worker_count}"
  template = "${file("${path.module}/worker/etc/kubelet.conf.yaml")}"

  vars {
    tls_ca          = "${data.ignition_file.tls_ca_crt.path}"
    cluster_domain  = "${var.network_domain}"
    cluster_dns     = "${local.dns_cluster_ip}"
    pod_cidr        = "${data.template_file.worker_pod_cidr.*.rendered[count.index]}"
    kubelet_tls_crt = "${data.ignition_file.worker_kubelet_tls_crt.*.path[count.index]}"
    kubelet_tls_key = "${data.ignition_file.worker_kubelet_tls_key.*.path[count.index]}"
  }
}

data "ignition_file" "worker_kubelet_config" {
  count      = "${var.worker_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.worker_kubelet_root.path}/kubelet-config.yaml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_kubelet_config.*.rendered[count.index]}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                              Kubelet Kubeconfig                            //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "worker_kubelet_kubeconfig" {
  count    = "${var.worker_count}"
  template = "${file("${path.module}/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://${local.cluster_fqdn}:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_fqdn}"
    user_name    = "system:node:${data.template_file.worker_nodename.*.rendered[count.index]}"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.worker_kubelet.*.cert_pem[count.index])}"
    tls_user_key = "${base64encode(tls_private_key.worker_kubelet.*.private_key_pem[count.index])}"
  }
}

data "ignition_file" "worker_kubelet_kubeconfig" {
  count      = "${var.worker_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.worker_kubelet_root.path}/kubeconfig"

  // mode = 0640
  mode = 416

  content {
    content = "${data.template_file.worker_kubelet_kubeconfig.*.rendered[count.index]}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                              Kubelet SystemD                               //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "worker_kubelet_env" {
  count    = "${var.worker_count}"
  template = "${file("${path.module}/worker/etc/kubelet.env")}"

  vars {
    client_ca_file             = "${data.ignition_file.tls_ca_crt.path}"
    cloud_config               = "${data.ignition_file.vsphere_cloud_provider_conf.path}"
    cluster_domain             = "${var.network_domain}"
    cluster_dns                = "${local.dns_cluster_ip}"
    cni_bin_dir                = "${data.ignition_directory.worker_cni_bin_dir.path}"
    config                     = "${data.ignition_file.worker_kubelet_config.*.path[count.index]}"
    container_runtime_endpoint = "unix://${data.ignition_directory.worker_containerd_state_dir.path}/containerd.sock"
    kubeconfig                 = "${data.ignition_file.worker_kubelet_kubeconfig.*.path[count.index]}"
    network_plugin             = "cni"
    tls_cert_file              = "${data.ignition_file.worker_kubelet_tls_crt.*.path[count.index]}"
    tls_private_key_file       = "${data.ignition_file.worker_kubelet_tls_key.*.path[count.index]}"
  }
}

data "ignition_file" "worker_kubelet_env" {
  count      = "${var.worker_count}"
  filesystem = "root"
  path       = "/etc/default/kubelet"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_kubelet_env.*.rendered[count.index]}"
  }
}

data "template_file" "worker_kubelet_service" {
  count    = "${var.worker_count}"
  template = "${file("${path.module}/worker/systemd/kubelet.service")}"

  vars {
    working_directory = "${data.ignition_directory.worker_kubelet_root.path}"
    env_file          = "${data.ignition_file.worker_kubelet_env.*.path[count.index]}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/kubelet"
  }
}

data "ignition_systemd_unit" "worker_kubelet_service" {
  count   = "${var.worker_count}"
  name    = "kubelet_.service"
  content = "${data.template_file.worker_kubelet_service.*.rendered[count.index]}"
}
