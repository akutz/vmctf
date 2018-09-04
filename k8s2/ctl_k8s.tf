////////////////////////////////////////////////////////////////////////////////
//                              kube-init-pre                                 //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "ctl_kube_init_pre_env" {
  template = <<EOF
# X509 cert/key pair definitions
TLS_0=kube-apiserver
TLS_COMMON_NAME_0=$${cluster_admin}
TLS_SAN_IP_0=127.0.0.1 $${cluster_svc_ip} {ETCD_MEMBER_IP_ADDRESSES}
TLS_SAN_DNS_0=localhost $${cluster_fqdn} $${cluster_svc_fqdn} $${cluster_svc_name}.default

TLS_1=k8s-admin
TLS_COMMON_NAME_1=admin
TLS_ORG_NAME_1=system:masters
TLS_SAN_1=false

TLS_2=kube-controller-manager
TLS_COMMON_NAME_2=system:kube-controller-manager
TLS_ORG_NAME_2=system:kube-controller-manager
TLS_SAN_2=false

TLS_3=kube-scheduler
TLS_COMMON_NAME_3=system:kube-scheduler
TLS_ORG_NAME_3=system:kube-scheduler
TLS_SAN_3=false

TLS_4=k8s-service-accounts
TLS_COMMON_NAME_4=service-accounts
TLS_SAN_4=false

# kubeconfig definitions
KFG_0=k8s-admin
KFG_FILE_PATH_0=/var/lib/kubernetes/kubeconfig
KFG_USER_0=admin
KFG_CRT_0=/etc/ssl/k8s-admin.crt
KFG_KEY_0=/etc/ssl/k8s-admin.key

# Grant access to the admin kubeconfig to users belonging to the
# "k8s-admin" group.
KFG_GID_0=k8s-admin
KFG_PERM_0=0440

KFG_1=kube-scheduler
KFG_FILE_PATH_1=/var/lib/kube-scheduler/kubeconfig
KFG_USER_1=system:kube-scheduler
KFG_CRT_1=/etc/ssl/kube-scheduler.crt
KFG_KEY_1=/etc/ssl/kube-scheduler.key

KFG_2=kube-controller-manager
KFG_FILE_PATH_2=/var/lib/kube-controller-manager/kubeconfig
KFG_USER_2=system:kube-controller-manager
KFG_CRT_2=/etc/ssl/kube-controller-manager.crt
KFG_KEY_2=/etc/ssl/kube-controller-manager.key
EOF

  vars {
    cluster_admin    = "${var.cluster_admin}"
    cluster_fqdn     = "${local.cluster_fqdn}"
    cluster_svc_fqdn = "${local.cluster_svc_fqdn}"
    cluster_svc_name = "${local.cluster_svc_name}"
    cluster_svc_ip   = "${local.cluster_svc_ip}"
  }
}

locals {
  ctl_kube_init_pre_service = <<EOF
[Unit]
Description=kube-init-pre.service
After=coredns.service
Requires=coredns.service
ConditionPathExists=!/var/lib/kubernetes/.kube-init-pre.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/var/lib/kubernetes
EnvironmentFile=/etc/default/etcdctl
EnvironmentFile=/etc/default/gencerts
EnvironmentFile=/etc/default/genkcfgs
EnvironmentFile=/etc/default/kube-init-pre
ExecStart=/opt/bin/kube-init-pre.sh
ExecStartPost=/bin/touch /var/lib/kubernetes/.kube-init-pre.service.norun
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                                 API Server                                 //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "ctl_kube_apiserver_env" {
  template = <<EOF
# Copied from http://bit.ly/2niZlvx

APISERVER_OPTS="--advertise-address={IPV4_ADDRESS} \
--allow-privileged=true \
--apiserver-count=$${apiserver_count} \
--audit-log-maxage=30 \
--audit-log-maxbackup=3 \
--audit-log-maxsize=100 \
--audit-log-path=/var/log/audit.log \
--authorization-mode=Node,RBAC \
--bind-address=0.0.0.0 \
--cloud-provider=vsphere \
--cloud-config=/var/lib/kubernetes/cloud-provider.config \
--client-ca-file=/etc/ssl/ca.crt \
--enable-admission-plugins='Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota' \
--enable-swagger-ui=true \
--etcd-cafile=/etc/ssl/ca.crt \
--etcd-certfile=/etc/ssl/etcd-client.crt \
--etcd-keyfile=/etc/ssl/etcd-client.key \
--etcd-servers='{ETCD_CLIENT_ENDPOINTS}' \
--event-ttl=1h \
--experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \
--kubelet-certificate-authority=/etc/ssl/ca.crt \
--kubelet-client-certificate=/etc/ssl/kube-apiserver.crt \
--kubelet-client-key=/etc/ssl/kube-apiserver.key \
--kubelet-https=true \
--runtime-config=api/all \
--secure-port=$${secure_port} \
--service-account-key-file=/etc/ssl/k8s-service-accounts.key \
--service-cluster-ip-range='$${service_cluster_ip_range}' \
--service-node-port-range=30000-32767 \
--tls-cert-file=/etc/ssl/kube-apiserver.crt \
--tls-private-key-file=/etc/ssl/kube-apiserver.key \
--v=2"
EOF

  vars {
    apiserver_count          = "${var.ctl_count}"
    secure_port              = "${var.api_secure_port}"
    service_cluster_ip_range = "${var.service_cluster_ip_range}"
  }
}

locals {
  ctl_kube_apiserver_service = <<EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=kube-init-pre.service
Requires=kube-init-pre.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-apiserver
EnvironmentFile=/etc/default/kube-apiserver
ExecStart=/opt/bin/kube-apiserver $$APISERVER_OPTS
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                             Controller Manager                             //
////////////////////////////////////////////////////////////////////////////////

data "template_file" "ctl_kube_controller_manager_env" {
  template = <<EOF
CONTROLLER_OPTS="--address=0.0.0.0 \
--cloud-provider=vsphere \
--cloud-config=/var/lib/kubernetes/cloud-provider.config \
--cluster-cidr='$${cluster_cidr}' \
--cluster-name='$${cluster_svc_name}' \
--cluster-signing-cert-file=/etc/ssl/ca.crt \
--cluster-signing-key-file=/etc/ssl/ca.key \
--kubeconfig=/var/lib/kube-controller-manager/kubeconfig \
--leader-elect=true \
--root-ca-file=/etc/ssl/ca.crt \
--service-account-private-key-file=/etc/ssl/k8s-service-accounts.key \
--service-cluster-ip-range='$${service_cluster_ip_range}' \
--use-service-account-credentials=true \
--v=2"

EOF

  vars {
    cluster_cidr             = "${var.cluster_cidr}"
    cluster_svc_name         = "${local.cluster_svc_name}"
    service_cluster_ip_range = "${var.service_cluster_ip_range}"
  }
}

locals {
  ctl_kube_controller_manager_service = <<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
After=kube-init-post.service
Requires=kube-init-post.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-controller-manager
EnvironmentFile=/etc/default/kube-controller-manager
ExecStart=/opt/bin/kube-controller-manager $$CONTROLLER_OPTS
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                                Scheduler                                   //
////////////////////////////////////////////////////////////////////////////////
locals {
  ctl_kube_scheduler_config = <<EOF
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /var/lib/kube-scheduler/kubeconfig
leaderElection:
  leaderElect: true
EOF

  ctl_kube_scheduler_env = <<EOF
SCHEDULER_OPTS="--config=/var/lib/kube-scheduler/kube-scheduler-config.yaml --v=2"
EOF

  ctl_kube_scheduler_service = <<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
After=kube-init-post.service
Requires=kube-init-post.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-scheduler
EnvironmentFile=/etc/default/kube-scheduler
ExecStart=/opt/bin/kube-scheduler $$SCHEDULER_OPTS
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                              kube-init-post                                //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "ctl_kube_init_post_env" {
  template = <<EOF
KUBECONFIG=/var/lib/kubernetes/kubeconfig
CLUSTER_ADMIN=$${cluster_admin}
EOF

  vars {
    cluster_admin = "${var.cluster_admin}"
  }
}

locals {
  ctl_kube_init_post_service = <<EOF
[Unit]
Description=kube-init-post.service
After=kube-apiserver.service
Requires=kube-apiserver.service
ConditionPathExists=!/var/lib/kubernetes/.kube-init-post.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/var/lib/kubernetes
EnvironmentFile=/etc/default/etcdctl
EnvironmentFile=/etc/default/kube-init-post
ExecStart=/opt/bin/kube-init-post.sh
ExecStartPost=/bin/touch /var/lib/kubernetes/.kube-init-post.service.norun
EOF
}

////////////////////////////////////////////////////////////////////////////////
//                              Encryption Config                             //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "ctl_k8s_encryption_config" {
  template = <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $${encryption_key}
      - identity: {}
EOF

  vars {
    encryption_key = "${var.k8s_encryption_key}"
  }
}
