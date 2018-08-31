data "template_file" "ctl_genkcfgs_env" {
  template = <<EOF
KFG_CLUSTER=$${cluster_fqdn}
KFG_CA_CRT=/etc/ssl/ca.crt
KFG_SERVER=https://127.0.0.1:$${api_secure_port}
KFG_CONTEXT=default
KFG_UID=root
KFG_GID=root
KFG_PERM=0400
EOF

  vars {
    //
    cluster_fqdn    = "${local.cluster_fqdn}"
    api_secure_port = "${var.api_secure_port}"
  }
}

data "template_file" "wrk_genkcfgs_env" {
  template = <<EOF
KFG_CLUSTER=$${cluster_fqdn}
KFG_CA_CRT=/etc/ssl/ca.crt
KFG_SERVER=https://$${cluster_fqdn}:$${api_secure_port}
KFG_CONTEXT=default
KFG_UID=root
KFG_GID=root
KFG_PERM=0400
EOF

  vars {
    //
    cluster_fqdn    = "${local.cluster_fqdn}"
    api_secure_port = "${var.api_secure_port}"
  }
}
