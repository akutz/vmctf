data "template_file" "ctl_network_hostname" {
  count    = "${var.ctl_count}"
  template = "${format(var.ctl_network_hostname, count.index+1)}"
}

data "template_file" "ctl_network_hostfqdn" {
  count    = "${var.ctl_count}"
  template = "${format(var.ctl_network_hostname, count.index+1)}.${var.network_domain}"
}

data "template_file" "wrk_network_hostname" {
  count    = "${var.wrk_count}"
  template = "${format(var.wrk_network_hostname, count.index+1)}"
}

data "template_file" "wrk_network_hostfqdn" {
  count    = "${var.wrk_count}"
  template = "${format(var.wrk_network_hostname, count.index+1)}.${var.network_domain}"
}

locals {
  path_sh = <<EOF
#!/bin/sh
. /etc/default/path
export PATH
EOF

  prompt_sh = <<EOF
#!/bin/sh
export PS1="[\$$?]\[\e[32;1m\]\u\[\e[0m\]@\[\e[32;1m\]\h\[\e[0m\]:\W$$ \[\e[0m\]"
EOF

  // Configure NetworkManager, if present, to avoid rewriting the
  // /etc/resolv.conf file.
  network_manager_dns_disabled = <<EOF
[main]
dns=none
rc-manager=unmanaged
EOF
}

data "template_file" "cloud_users" {
  count = "${length(keys(var.os_users))}"

  template = <<EOF
  - name: $${name}
    primary_group: $${name}
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: sudo, wheel, k8s-admin
    ssh_import_id: None
    lock_passwd: true
    ssh_authorized_keys:
      - $${key}
EOF

  vars {
    name = "${element(keys(var.os_users), count.index)}"
    key  = "${element(values(var.os_users), count.index)}"
  }
}

data "template_file" "defaults_env" {
  template = <<EOF
DEBUG=$${debug}
BIN_DIR=/opt/bin
HOSTFQDN="{HOSTFQDN}"
HOSTNAME="{HOSTNAME}"
HOST_FQDN="{HOSTFQDN}"
HOST_NAME="{HOSTNAME}"
IPV4_ADDRESS={IPV4_ADDRESS}
CLUSTER_FQDN="$${cluster_fqdn}"
EXPECTED_CONTROLLER_COUNT=$${expected_controller_count}
EXPECTED_WORKER_COUNT=$${expected_worker_count}
EOF

  vars {
    debug                     = "${var.debug}"
    cluster_fqdn              = "${local.cluster_fqdn}"
    expected_controller_count = "${var.ctl_count}"
    expected_worker_count     = "${var.wrk_count}"
  }
}
