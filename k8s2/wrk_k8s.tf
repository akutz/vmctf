////////////////////////////////////////////////////////////////////////////////
//                           Control Plane Online                             //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "wrk_control_plane_online_env" {
  template = <<EOF
IPV4_ADDRESS={IPV4_ADDRESS}
HOSTFQDN={HOSTFQDN}
ETCD_DISCOVERY=$${etcd_discovery}
ETCD_MEMBER_COUNT=$${ctl_count}
DNS_SEARCH=$${dns_search}
CLUSTER_FQDN=$${cluster_fqdn}
API_SECURE_PORT=$${api_secure_port}
EOF

  vars {
    ctl_count       = "${var.ctl_count}"
    dns_search      = "${var.network_search_domains}"
    etcd_discovery  = "${data.http.etcd_discovery.body}"
    cluster_fqdn    = "${local.cluster_fqdn}"
    api_secure_port = "${var.api_secure_port}"
  }
}

locals {
  wrk_control_plane_online_service = <<EOF
[Unit]
Description=control-plane-online.service
After=bins.service
Requires=bins.service
ConditionPathExists=!/var/lib/kubernetes/.control-plane-online.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/var/lib/kubernetes
EnvironmentFile=/etc/default/control-plane-online
ExecStart=/opt/bin/control-plane-online.sh
ExecStartPost=/bin/touch /var/lib/kubernetes/.control-plane-online.service.norun
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                             kube-init-pre                                  //
////////////////////////////////////////////////////////////////////////////////

locals {
  wkr_kube_init_pre_env = <<EOF
# x509 crt/key pair definitions
TLS_0=kubelet
TLS_COMMON_NAME_0=system:node:{HOSTFQDN}
TLS_ORG_NAME_0=system:nodes

TLS_1=kube-proxy
TLS_COMMON_NAME_1=system:kube-proxy
TLS_ORG_NAME_1=system:node-proxier
TLS_SAN_1=false

# kubeconfig definitions
KFG_0=kubelet
KFG_FILE_PATH_0=/var/lib/kubelet/kubeconfig
KFG_USER_0=system:node:{HOSTFQDN}
KFG_CRT_0=/etc/ssl/kubelet.crt
KFG_KEY_0=/etc/ssl/kubelet.key

KFG_1=kube-proxy
KFG_FILE_PATH_1=/var/lib/kube-proxy/kubeconfig
KFG_USER_1=system:kube-proxy
KFG_CRT_1=/etc/ssl/kube-proxy.crt
KFG_KEY_1=/etc/ssl/kube-proxy.key
EOF
}

locals {
  wrk_kube_init_pre_service = <<EOF
[Unit]
Description=kube-init-pre.service
After=control-plane-online.service
Requires=control-plane-online.service
ConditionPathExists=!/var/lib/kubernetes/.kube-init-pre.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/var/lib/kubernetes
EnvironmentFile=/etc/default/gencerts
EnvironmentFile=/etc/default/genkcfgs
EnvironmentFile=/etc/default/kube-init-pre
ExecStart=/opt/bin/gencerts.sh
ExecStart=/opt/bin/genkcfgs.sh
ExecStartPost=/bin/touch /var/lib/kubernetes/.kube-init-pre.service.norun
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                                 Kubelet                                    //
////////////////////////////////////////////////////////////////////////////////

data "template_file" "wrk_kubelet_config" {
  count = "${var.wrk_count}"

  template = <<EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/ssl/ca.crt
authorization:
  mode: Webhook
clusterDomain: $${cluster_svc_domain}
clusterDNS:
  - $${cluster_svc_dns_ip}
podCIDR: $${pod_cidr}
runtimeRequestTimeout: 15m
tlsCertFile: /etc/ssl/kubelet.crt
tlsPrivateKeyFile: /etc/ssl/kubelet.key
EOF

  vars {
    cluster_svc_domain = "${local.cluster_svc_domain}"
    cluster_svc_dns_ip = "${local.cluster_svc_dns_ip}"
    pod_cidr           = "${data.template_file.wrk_pod_cidr.*.rendered[count.index]}"
  }
}

data "template_file" "wrk_kubelet_env" {
  template = <<EOF
KUBELET_OPTS="--client-ca-file=/etc/ssl/ca.crt \
--cloud-provider=vsphere \
--cloud-config=/var/lib/kubernetes/cloud-provider.config \
--cluster-domain='$${cluster_svc_domain}' \
--cluster-dns='$${cluster_svc_dns_ip}' \
--cni-bin-dir=/opt/bin/cni \
--config=/var/lib/kubelet/kubelet-config.yaml \
--container-runtime=remote \
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
--image-pull-progress-deadline=2m \
--kubeconfig=/var/lib/kubelet/kubeconfig \
--network-plugin=cni \
--node-ip={IPV4_ADDRESS} \
--register-node=true \
--tls-cert-file=/etc/ssl/kubelet.crt \
--tls-private-key-file=/etc/ssl/kubelet.key \
--v=2"
EOF

  vars {
    cluster_svc_domain = "${local.cluster_svc_domain}"
    cluster_svc_dns_ip = "${local.cluster_svc_dns_ip}"
  }
}

locals {
  wrk_kubelet_service = <<EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=kube-init-pre.service containerd.service
Requires=kube-init-pre.service containerd.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=/etc/default/path
EnvironmentFile=/etc/default/kubelet
ExecStart=/opt/bin/kubelet $$KUBELET_OPTS
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                                Kube-Proxy                                  //
////////////////////////////////////////////////////////////////////////////////

data "template_file" "wrk_kube_proxy_config" {
  template = <<EOF
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "$${cluster_cidr}"
EOF

  vars {
    cluster_cidr = "${var.cluster_cidr}"
  }
}

locals {
  wrk_kube_proxy_env = <<EOF
KUBE_PROXY_OPTS="--config=/var/lib/kube-proxy/kube-proxy-config.yaml"
EOF

  wrk_kube_proxy_service = <<EOF
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
After=kubelet.service
Requires=kubelet.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-proxy
EnvironmentFile=/etc/default/kube-proxy
ExecStart=/opt/bin/kube-proxy $$KUBE_PROXY_OPTS
EOF
}
