locals {
  core_uid             = "500"
  core_gid             = "500"
  seed_uid             = "1000"
  seed_gid             = "1000"
  users_keys           = ["${keys(var.users)}"]
  users_count          = "${length(local.users_keys)}"
  ldap_domain          = "DC=${replace(var.ldap_domain, ".", ",DC=")}"
  ldap_domain_list     = "${split(",", local.ldap_domain)}"
  ldap_domain_list_len = "${length(local.ldap_domain_list)}"
  ldap_domain_root     = "${format("%s,%s",local.ldap_domain_list[local.ldap_domain_list_len - 2],local.ldap_domain_list[local.ldap_domain_list_len - 1])}"
  ldap_ou_users        = "OU=users,${local.ldap_domain}"
  ldap_etc             = "/etc/openldap"
  ldap_conf            = "${local.ldap_etc}/ldap.conf"
  ldap_tls             = "${local.ldap_etc}/tls"
  ldap_tls_ca          = "${local.ldap_tls}/ca.pem"
}

data "ignition_user" "core" {
  name = "core"

  ssh_authorized_keys = [
    "${values(var.users)}",
  ]
}

data "ignition_group" "groups" {
  count = "${local.users_count}"
  name  = "${element(local.users_keys, count.index)}"
  gid   = "${local.seed_gid + count.index}"
}

data "ignition_user" "users" {
  count         = "${local.users_count}"
  name          = "${element(local.users_keys, count.index)}"
  uid           = "${local.seed_uid + count.index}"
  no_user_group = "true"
  primary_group = "${element(local.users_keys, count.index)}"

  groups = [
    "wheel",
    "docker",
    "sudo",
  ]

  ssh_authorized_keys = [
    "${var.users[element(local.users_keys, count.index)]}",
  ]
}

data "ignition_file" "hostname" {
  filesystem = "root"
  path       = "/etc/hostname"
  mode       = 384

  content {
    content = "${var.hostname}"
  }
}

data "ignition_file" "sshd_config" {
  filesystem = "root"
  path       = "/etc/ssh/sshd_config"
  mode       = 384

  content {
    content = <<EOF
# Use most defaults for sshd configuration.
UsePrivilegeSeparation sandbox
Subsystem sftp internal-sftp
UseDNS no

PermitRootLogin no
AllowUsers ${data.ignition_user.core.name} ${join(" ", local.users_keys)}
AuthenticationMethods publickey
EOF
  }
}

data "ignition_file" "slapd_dockerfile" {
  filesystem = "root"
  path       = "/var/lib/slapd/Dockerfile"
  mode       = 420

  content {
    content = "${file("Dockerfile")}"
  }
}

data "ignition_file" "slapd_sh" {
  filesystem = "root"
  path       = "/var/lib/slapd/slapd.sh"
  mode       = 420

  content {
    content = "${file("slapd.sh")}"
  }
}

data "ignition_file" "slapd_env" {
  filesystem = "root"
  path       = "/var/lib/slapd/slapd.env"
  mode       = 420

  content {
    content = <<EOF
LDAP_ORG=${var.ldap_org}
LDAP_DOMAIN=${var.ldap_domain}
LDAP_ROOT_USER=${var.ldap_root_user}
LDAP_ROOT_PASS=${var.ldap_root_pass}
LDAP_LOG_LEVEL=${var.ldap_log_level}
LDAP_LDIF=${var.ldap_ldif}
LDAP_TLS_CA=${var.ldap_tls_ca}
LDAP_TLS_KEY=${var.ldap_tls_key}
LDAP_TLS_CRT=${var.ldap_tls_crt}
EOF
  }
}

data "ignition_file" "ldap_conf" {
  filesystem = "root"
  path       = "${local.ldap_conf}"
  mode       = 420

  content {
    content = <<EOF
URI         ldaps://127.0.0.01
BASE        ${local.ldap_domain_root}

TLS_REQCERT try
TLS_CACERT  ${local.ldap_tls_ca}
EOF
  }
}

data "ignition_file" "ldaprc_core" {
  filesystem = "root"
  path       = "/home/core/.ldaprc"
  mode       = 420
  uid        = "${local.core_uid}"
  gid        = "${local.core_gid}"

  content {
    content = <<EOF
BINDDN CN=${var.ldap_root_user},${local.ldap_domain_root}
EOF
  }
}

data "ignition_file" "ldaprc_root" {
  filesystem = "root"
  path       = "/root/.ldaprc"
  mode       = 420

  content {
    content = <<EOF
BINDDN CN=${var.ldap_root_user},${local.ldap_domain_root}
EOF
  }
}

data "ignition_file" "ldaprc_users" {
  count      = "${local.users_count}"
  filesystem = "root"
  path       = "/home/${element(local.users_keys, count.index)}/.ldaprc"
  mode       = 420
  uid        = "${data.ignition_user.users.*.uid[count.index]}"
  gid        = "${data.ignition_group.groups.*.gid[count.index]}"

  content {
    content = <<EOF
BINDDN CN=${element(local.users_keys, count.index)},${local.ldap_ou_users}
EOF
  }
}

data "ignition_systemd_unit" "slapd" {
  name = "slapd.service"

  content = <<EOF
[Unit]
After=docker.service network-online.target
Requires=docker.service network-online.target
Wants=docker.service network-online.target

[Service]
ExecStartPre=/bin/mkdir -p /var/lib/slapd/ldif "${local.ldap_tls}"
ExecStartPre=/usr/bin/sh -c 'if [ ! -e "${local.ldap_tls_ca}" ]; then \
  if PEM=$(cat ${data.ignition_file.slapd_env.path} | \
  grep LDAP_TLS_CA | \
  awk -F= "{print \$2}") && [ -n "$PEM" ]; then \
  echo "$PEM" | base64 -d | gzip -d > \
  "${local.ldap_tls_ca}"; fi; fi'
ExecStartPre=/usr/bin/sh -c 'if [ ! -e "${local.ldap_tls_ca}" ]; then \
  if PEM=$(cat ${data.ignition_file.slapd_env.path} | \
  grep LDAP_TLS_CRT | \
  awk -F= "{print \$2}") && [ -n "$PEM" ]; then \
  echo "$PEM" | base64 -d | gzip -d > \
  "${local.ldap_tls_ca}"; fi; fi'
ExecStartPre=/usr/bin/docker build -t slapd /var/lib/slapd
ExecStart=/usr/bin/docker run --rm --name=slapd \
  --env-file=${data.ignition_file.slapd_env.path} \
  -v /var/lib/slapd/ldif:/ldif \
  -p 389:389 -p 636:636 \
  --hostname=${var.hostname} \
  slapd

[Install]
WantedBy=multi-user.target
EOF
}

data "ignition_networkd_unit" "network" {
  name = "00-${var.network_device}.network"

  content = <<EOF
[Match]
Name=${var.network_device}

[Network]
DHCP=${var.network_dhcp}
DNS=${var.network_dns_1}
DNS=${var.network_dns_2}
Domains=${var.network_domains}
Address=${var.network_ipv4_address}
Gateway=${var.network_ipv4_gateway}
EOF
}

data "ignition_config" "config" {
  files = [
    "${data.ignition_file.hostname.id}",
    "${data.ignition_file.sshd_config.id}",
    "${data.ignition_file.ldap_conf.id}",
    "${data.ignition_file.ldaprc_core.id}",
    "${data.ignition_file.ldaprc_root.id}",
    "${data.ignition_file.ldaprc_users.*.id}",
    "${data.ignition_file.slapd_env.id}",
    "${data.ignition_file.slapd_sh.id}",
    "${data.ignition_file.slapd_dockerfile.id}",
  ]

  networkd = [
    "${data.ignition_networkd_unit.network.id}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.slapd.id}",
  ]

  groups = [
    "${data.ignition_group.groups.*.id}",
  ]

  users = [
    "${data.ignition_user.core.id}",
    "${data.ignition_user.users.*.id}",
  ]
}
