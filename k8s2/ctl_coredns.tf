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

/*
data "template_file" "ctl_coredns_cluster_deployment_spec" {
  template = <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes $${cluster_svc_domain} $${reverse_cidrs} {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }FEDERATIONS
        prometheus :9153
        proxy . UPSTREAMNAMESERVER
        cache 30
        loop
        reload
        loadbalance
    }STUBDOMAINS
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: "CoreDNS"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      serviceAccountName: coredns
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      containers:
      - name: coredns
        image: coredns/coredns:1.2.2
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: $${cluster_svc_dns_ip}
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
EOF
}
*/