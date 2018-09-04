// Get the etcd discovery token.
provider "http" {}

data "http" "etcd_discovery" {
  url = "https://discovery.etcd.io/new?size=${var.ctl_count}"
}

data "template_file" "ctl_etcd_init_pre_env" {
  template = <<EOF
DEBUG={DEBUG}

TLS_0=etcdctl
TLS_COMMON_NAME_0=etcdctl@{HOSTFQDN}
TLS_SAN_0=false
TLS_KEY_PERM_0=0444

TLS_1=etcd-client
TLS_COMMON_NAME_1={HOSTFQDN}
TLS_SAN_DNS_1=localhost {HOSTNAME} {HOSTFQDN} $${cluster_fqdn}
TLS_KEY_UID_1=etcd
TLS_CRT_UID_1=etcd

TLS_2=etcd-peer
TLS_COMMON_NAME_2={HOSTFQDN}
TLS_KEY_UID_2=etcd
TLS_CRT_UID_2=etcd
EOF

  vars {
    cluster_fqdn = "${local.cluster_fqdn}"
  }
}

data "template_file" "ctl_etcd_init_post_env" {
  template = <<EOF
DEBUG={DEBUG}
ETCD_MEMBER_COUNT=$${ctl_count}
EOF

  vars {
    ctl_count = "${var.ctl_count}"
  }
}

data "template_file" "ctl_etcd_env" {
  count = "${var.ctl_count}"

  template = <<EOF
ETCD_DEBUG=$${debug}
ETCD_NAME={HOST_NAME}
ETCD_DATA_DIR=/var/lib/etcd/data
ETCD_DISCOVERY=$${etcd_discovery}
ETCD_LISTEN_PEER_URLS=https://{IPV4_ADDRESS}:2380
ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://{IPV4_ADDRESS}:2380
ETCD_ADVERTISE_CLIENT_URLS=https://{IPV4_ADDRESS}:2379

ETCD_CERT_FILE=/etc/ssl/etcd-client.crt
ETCD_KEY_FILE=/etc/ssl/etcd-client.key
ETCD_CLIENT_CERT_AUTH=true
ETCD_TRUSTED_CA_FILE=/etc/ssl/ca.crt
ETCD_PEER_CERT_FILE=/etc/ssl/etcd-peer.crt
ETCD_PEER_KEY_FILE=/etc/ssl/etcd-peer.key
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/ca.crt
EOF

  vars {
    debug          = "${var.debug}"
    etcd_discovery = "${data.http.etcd_discovery.body}"
  }
}

locals {
  ctl_etcd_service = <<EOF
[Unit]
Description=etcd.service
Documentation=https://github.com/coreos/etcd

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
Restart=always
RestartSec=10s
LimitNOFILE=40000
TimeoutStartSec=0
NoNewPrivileges=true
PermissionsStartOnly=true
User=etcd
WorkingDirectory=/var/lib/etcd
EnvironmentFile=/etc/default/etcd
ExecStart=/opt/bin/etcd
EOF

  ctl_etcdctl_env = <<EOF
ETCDCTL_API=3
ETCDCTL_CERT=/etc/ssl/etcdctl.crt
ETCDCTL_KEY=/etc/ssl/etcdctl.key
ETCDCTL_CACERT=/etc/ssl/ca.crt
ETCDCTL_ENDPOINTS=https://127.0.0.1:2379
EOF

  ctl_etcdctl_sh = <<EOF
#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

# shellcheck disable=SC1091
. /etc/default/etcdctl

export ETCDCTL_API \
       ETCDCTL_CERT \
       ETCDCTL_KEY \
       ETCDCTL_CACERT \
       ETCDCTL_ENDPOINTS
EOF

  ctl_etcd_init_pre_service = <<EOF
[Unit]
Description=etcd-init-pre.service
ConditionPathExists=!/var/lib/etcd/.etcd-init.service.norun

#[Install]
#WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
EnvironmentFile=/etc/default/gencerts
EnvironmentFile=/etc/default/etcd-init-pre
ExecStart=/opt/bin/gencerts.sh
ExecStartPost=/bin/touch /var/lib/etcd/.etcd-init.service.norun
EOF

  ctl_etcd_init_post_service = <<EOF
[Unit]
Description=etcd-init-post.service
After=etcd.service
Requires=etcd.service
ConditionPathExists=!/var/lib/etcd/.etcd-init-post.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
EnvironmentFile=/etc/default/defaults
EnvironmentFile=/etc/default/etcdctl
ExecStart=/opt/bin/etcd-init-post.sh
ExecStartPost=/bin/touch /var/lib/etcd/.etcd-init-post.service.norun
EOF
}
