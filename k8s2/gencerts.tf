data "template_file" "gencerts_env" {
  template = <<EOF
TLS_CA_CRT=/etc/ssl/ca.crt
TLS_CA_KEY=/etc/ssl/ca.key

TLS_DEFAULT_BITS=$${tls_bits}
TLS_DEFAULT_DAYS=$${tls_days}

TLS_COUNTRY_NAME=$${tls_country}
TLS_STATE_OR_PROVINCE_NAME=$${tls_province}
TLS_LOCALITY_NAME=$${tls_locality}
TLS_ORG_NAME=$${tls_org}
TLS_OU_NAME=$${tls_ou}
TLS_EMAIL=$${tls_email}

TLS_KEY_USAGE=keyEncipherment, digitalSignature
TLS_EXT_KEY_USAGE=serverAuth, clientAuth

TLS_SAN=true
TLS_SAN_DNS=localhost {HOSTNAME} {HOSTFQDN}
TLS_SAN_IP=127.0.0.1 {IPV4_ADDRESS}

TLS_KEY_UID=root
TLS_KEY_GID=root
TLS_KEY_PERM=0400
TLS_CRT_UID=root
TLS_CRT_GID=root
TLS_CRT_PERM=0644
EOF

  vars {
    //
    tls_bits     = "${var.tls_bits}"
    tls_days     = "${var.tls_days}"
    tls_org      = "${var.tls_org}"
    tls_ou       = "${var.tls_ou}"
    tls_country  = "${var.tls_country}"
    tls_province = "${var.tls_province}"
    tls_locality = "${var.tls_locality}"
    tls_email    = "${var.tls_email}"
  }
}
