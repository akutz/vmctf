data "ignition_user" "core" {
  name = "core"

  ssh_authorized_keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDE0c5FczvcGSh/tG4iw+Fhfi/O5/EvUM/96js65tly4++YTXK1d9jcznPS5ruDlbIZ30oveCBd3kT8LLVFwzh6hepYTf0YmCTpF4eDunyqmpCXDvVscQYRXyasEm5olGmVe05RrCJSeSShAeptv4ueIn40kZKOghinGWLDSZG4+FFfgrmcMCpx5YSCtX2gvnEYZJr0czt4rxOZuuP7PkJKgC/mt2PcPjooeX00vAj81jjU2f3XKrjjz2u2+KIt9eba+vOQ6HiC8c2IzRkUAJ5i1atLy8RIbejo23+0P4N2jjk17QySFOVHwPBDTYb0/0M/4ideeU74EN/CgVsvO6JrLsPBR4dojkV5qNbMNxIVv5cUwIy2ThlLgqpNCeFIDLCWNZEFKlEuNeSQ2mPtIO7ETxEL2Cz5y/7AIuildzYMc6wi2bofRC8HmQ7rMXRWdwLKWsR0L7SKjHblIwarxOGqLnUI+k2E71YoP7SZSlxaKi17pqkr0OMCF+kKqvcvHAQuwGqyumTEWOlH6TCx1dSPrW+pVCZSHSJtSTfDW2uzL6y8k10MT06+pVunSrWo5LHAXcS91htHV1M1UrH/tZKSpjYtjMb5+RonfhaFRNzvj7cCE1f3Kp8UVqAdcGBTtReoE8eRUT63qIxjw03a7VwAyB2w+9cu1R9/vAo8SBeRqw== sakutz@gmail.com",
  ]
}

data "ignition_file" "hostname" {
  filesystem = "root"
  path       = "/etc/hostname"

  content {
    content = "${var.hostname}"
  }
}

data "ignition_file" "slapd_dockerfile" {
  filesystem = "root"
  path       = "/var/lib/slapd/Dockerfile"

  content {
    content = "${file("Dockerfile")}"
  }
}

data "ignition_file" "slapd_sh" {
  filesystem = "root"
  path       = "/var/lib/slapd/slapd.sh"

  content {
    content = "${file("slapd.sh")}"
  }
}

data "ignition_file" "slapd_env" {
  filesystem = "root"
  path       = "/var/lib/slapd/slapd.env"

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

data "ignition_systemd_unit" "slapd" {
  name = "slapd.service"

  content = <<EOF
[Unit]
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

[Service]
ExecStartPre=/bin/mkdir -p /var/lib/slapd/ldif
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

  users = [
    "${data.ignition_user.core.id}",
  ]
}
