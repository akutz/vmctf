locals {
  cluster_name = "${format(var.cluster_name, var.network_domain)}"
}

data "template_file" "k8s_admin_kubeconfig" {
  template = "${file("${path.module}/master/etc/kubeconfig.yaml")}"

  vars {
    tls_ca       = "${base64encode(local.tls_ca_crt)}"
    public_fqdn  = "https://${local.cluster_name}:${var.master_api_secure_port}"
    cluster_name = "${local.cluster_name}"
    user_name    = "admin"
    tls_user_crt = "${base64encode(tls_locally_signed_cert.master_k8s_admin.cert_pem)}"
    tls_user_key = "${base64encode(tls_private_key.master_k8s_admin.private_key_pem)}"
  }
}

resource "local_file" "k8s_admin_kubeconfig" {
  content  = "${data.template_file.k8s_admin_kubeconfig.rendered}"
  filename = "${path.module}/../kubeconfig"
}
