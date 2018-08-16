locals {
  tls_ca_key = "${file("${path.module}/../ca.key")}"
  tls_ca_crt = "${file("${path.module}/../ca.crt")}"
}
