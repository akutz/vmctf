data "template_file" "ctl_coredns_corefile" {
  template = <<EOF
. {
    log
    errors
    etcd $${network_domain} $${network_ipv4_subnet_cidr} {
        stubzones
        path /skydns
        endpoint https://127.0.0.1:2379
        upstream $${network_dns_1}:53 $${network_dns_2}:53
        tls /etc/ssl/coredns.crt /etc/ssl/coredns.key /etc/ssl/ca.crt
    }
    prometheus
    cache 160 $${network_domain}
    loadbalance
    proxy . $${network_dns_1}:53 $${network_dns_2}:53
}
EOF

  vars {
    network_domain           = "${var.network_domain}"
    network_ipv4_subnet_cidr = "${var.network_ipv4_gateway}/24"
    network_dns_1            = "${var.network_dns_1}"
    network_dns_2            = "${var.network_dns_2}"
  }
}

data "template_file" "ctl_coredns_init_env" {
  template = <<EOF
ETCD_MEMBER_IP_ADDRESSES={ETCD_MEMBER_IP_ADDRESSES}

CLUSTER_FQDN=$${cluster_fqdn}
DNS_SEARCH=$${dns_search}
DNS_ENTRIES={HOSTFQDN}={IPV4_ADDRESS}
DNS_SERVERS=127.0.0.1

ETCDCTL_API=3
ETCDCTL_CERT=/etc/ssl/coredns.crt
ETCDCTL_KEY=/etc/ssl/coredns.key
ETCDCTL_CACERT=/etc/ssl/ca.crt
ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

TLS_0=coredns
TLS_COMMON_NAME_0=coredns@{HOSTFQDN}
TLS_KEY_UID_0=coredns
TLS_CRT_UID_0=coredns
EOF

  vars {
    cluster_fqdn = "${local.cluster_fqdn}"
    dns_search   = "${var.network_search_domains}"
  }
}

locals {
  ctl_coredns_service = <<EOF
[Unit]
Description=coredns.service
Documentation=https://github.com/akutz/skydns/releases/tag/15f42ac
After=coredns-init.service
Requires=coredns-init.service

[Install]
WantedBy=multi-user.target

# Copied from http://bit.ly/systemd-coredns-service
[Service]
PermissionsStartOnly=true
LimitNOFILE=1048576
LimitNPROC=512
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
User=coredns
WorkingDirectory=/var/lib/coredns
ExecReload=/bin/kill -SIGUSR1 $$MAINPID
Restart=on-failure
ExecStart=/opt/bin/coredns -conf /etc/coredns/etcd.conf
EOF

  ctl_coredns_init_service = <<EOF
[Unit]
Description=coredns-init.service
After=etcd-init-post.service
Requires=etcd-init-post.service
ConditionPathExists=!/var/lib/coredns/.coredns-init.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
PermissionsStartOnly=true
WorkingDirectory=/var/lib/coredns
EnvironmentFile=/etc/default/gencerts
EnvironmentFile=/etc/default/coredns-init
ExecStart=/opt/bin/coredns-init.sh
ExecStartPost=/bin/touch /var/lib/coredns/.coredns-init.service.norun
EOF
}
