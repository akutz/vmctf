provider "tls" {}

locals {
  tls_dir = "/etc/ssl"

  tls_alg    = "RSA"

  // hours_in_day * days_in_week * weeks_in_year * num_years = 10 years
  tls_expiry = "${24 * 7 * 52 * 10}"

  tls_subj_organization        = "VMware"
  tls_subj_organizational_unit = "CNX"
  tls_subj_country             = "US"
  tls_subj_province            = "California"
  tls_subj_locality            = "Palo Alto"
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "tls_dir" {
  filesystem = "root"
  path       = "${local.tls_dir}"

  // mode = 0755
  mode = 493
}

data "ignition_file" "tls_ca_crt" {
  filesystem = "root"
  path       = "${local.tls_dir}/ca.crt"

  // mode = 0444
  mode = 292

  content {
    content = "${local.tls_ca_crt}"
  }
}

data "ignition_file" "tls_ca_key" {
  filesystem = "root"
  path       = "${local.tls_dir}/ca.key"

  // mode = 0400
  mode = 256

  content {
    content = "${local.tls_ca_key}"
  }
}