////////////////////////////////////////////////////////////////////////////////
//                                Globals                                     //
////////////////////////////////////////////////////////////////////////////////
locals {
  cluster_fqdn       = "${var.cluster_name}.${var.network_domain}"
  cluster_svc_ip     = "${cidrhost(var.service_cluster_ip_range, "1")}"
  cluster_svc_dns_ip = "${cidrhost(var.service_cluster_ip_range, "10")}"

  cluster_svc_domain = "cluster.local"

  cluster_svc_name = "kubernetes"

  cluster_svc_fqdn = "${local.cluster_svc_name}.default.svc.${local.cluster_svc_domain}"
}

// ctl_pod_cidr is reserved for future use in case workloads are scheduled
// on controller nodes
data "template_file" "ctl_pod_cidr" {
  count    = "${var.ctl_count}"
  template = "${format(var.pod_cidr, count.index)}"
}

// wrk_pod_cidr is always calculated as an offset from the ctl_pod_cidr.
data "template_file" "wrk_pod_cidr" {
  count    = "${var.wrk_count}"
  template = "${format(var.pod_cidr, var.ctl_count + count.index)}"
}

data "template_file" "defaults_service" {
  template = <<EOF
[Unit]
Description=defaults.service
After=network-online.target
Requires=network-online.target
ConditionPathExists=!/var/lib/.defaults.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
Environment=DEBUG=$${debug}
ExecStartPre=/bin/sh -c 'while true; do ping -c1 www.google.com && break; done'
ExecStart=/opt/bin/defaults.sh
ExecStartPost=/bin/touch /var/lib/.defaults.service.norun
EOF

  vars {
    debug = "${var.debug}"
  }
}

locals {
  bins_service = <<EOF
[Unit]
Description=bins.service
After=defaults.service
Requires=defaults.service
ConditionPathExists=!/var/lib/.bins.service.norun

[Install]
WantedBy=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=true
WorkingDirectory=/opt/bin
EnvironmentFile=/etc/default/bins
ExecStart=/opt/bin/bins.sh
ExecStartPost=/bin/touch /var/lib/.bins.service.norun
EOF
}

data "template_file" "ctl_bins_env" {
  template = <<EOF
JQ_VERSION=$${jq_version}
ETCD_VERSION=$${etcd_version}
K8S_VERSION=$${k8s_version}
COREDNS_VERSION=$${coredns_version}
NGINX_VERSION=$${nginx_version}
EOF

  vars {
    jq_version      = "${var.jq_version}"
    etcd_version    = "${var.etcd_version}"
    k8s_version     = "${var.k8s_version}"
    coredns_version = "${var.coredns_version}"
    nginx_version   = "${var.nginx_version}"
  }
}

data "template_file" "wrk_bins_env" {
  template = <<EOF
DEBUG={DEBUG}
JQ_VERSION=$${jq_version}
K8S_VERSION=$${k8s_version}
CRICTL_VERSION=$${crictl_version}
RUNC_VERSION=$${runc_version}
RUNSC_VERSION=$${runsc_version}
CNI_PLUGINS_VERSION=$${cni_plugins_version}
CONTAINERD_VERSION=$${containerd_version}
EOF

  vars {
    jq_version          = "${var.jq_version}"
    k8s_version         = "${var.k8s_version}"
    crictl_version      = "${var.crictl_version}"
    runc_version        = "${var.runc_version}"
    runsc_version       = "${var.runsc_version}"
    cni_plugins_version = "${var.cni_plugins_version}"
    containerd_version  = "${var.containerd_version}"
  }
}

locals {
  kubeconfig_sh = <<EOF
#!/bin/sh
# Set the KUBECONFIG environment variable to point to the admin
# kubeconfig file if the current user is root or belongs to the 
# k8s-admin group.
id | grep -q 'uid=0\|k8s-admin' && \
  export KUBECONFIG=/var/lib/kubernetes/kubeconfig
EOF
}

data "template_file" "coredns_podspec" {
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
        kubernetes $${cluster_svc_domain} in-addr.arpa ip6.arpa {
          pods insecure
          upstream
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
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

  vars {
    cluster_svc_dns_ip = "${local.cluster_svc_dns_ip}"
    cluster_svc_domain = "${local.cluster_svc_domain}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                  Routes                                    //
////////////////////////////////////////////////////////////////////////////////


/*data "template_file" "wrk_network_routes" {
  count = "${var.wrk_count}"
  template = "ip route add $${pod_cidr} via"
  vars {
    pod_cidr = "${format(var.pod_cidr, count.index)}"
  }
}

data "template_file" "ctl_network_routes" {
  count = "${var.wrk_count}"
  template = "ip route add $${pod_cidr} via"
  vars {
    pod_cidr = "${format(var.pod_cidr, count.index)}"
  }
}*/

