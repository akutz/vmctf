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

data "template_file" "kube_dns_podspec" {
  template = <<EOF
# Copyright 2016 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
    kubernetes.io/name: "KubeDNS"
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
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kube-dns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
spec:
  # replicas: not specified here:
  # 1. In order to make Addon Manager do not reconcile this replicas parameter.
  # 2. Default is 1.
  # 3. Will be tuned in real time if DNS horizontal auto-scaling is turned on.
  strategy:
    rollingUpdate:
      maxSurge: 10%
      maxUnavailable: 0
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
      annotations:
        scheduler.alpha.kubernetes.io/critical-pod: ''
    spec:
      tolerations:
      - key: "CriticalAddonsOnly"
        operator: "Exists"
      volumes:
      - name: kube-dns-config
        configMap:
          name: kube-dns
          optional: true
      containers:
      - name: kubedns
        image: gcr.io/google_containers/k8s-dns-kube-dns-amd64:1.14.7
        resources:
          # TODO: Set memory limits when we've profiled the container for large
          # clusters, then set request = limit to keep this container in
          # guaranteed class. Currently, this container falls into the
          # "burstable" category so the kubelet doesn't backoff from restarting it.
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        livenessProbe:
          httpGet:
            path: /healthcheck/kubedns
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /readiness
            port: 8081
            scheme: HTTP
          # we poll on pod startup for the Kubernetes master service and
          # only setup the /readiness HTTP server once that's available.
          initialDelaySeconds: 3
          timeoutSeconds: 5
        args:
        - --domain=$${cluster_svc_domain}.
        - --dns-port=10053
        - --config-dir=/kube-dns-config
        - --v=2
        env:
        - name: PROMETHEUS_PORT
          value: "10055"
        ports:
        - containerPort: 10053
          name: dns-local
          protocol: UDP
        - containerPort: 10053
          name: dns-tcp-local
          protocol: TCP
        - containerPort: 10055
          name: metrics
          protocol: TCP
        volumeMounts:
        - name: kube-dns-config
          mountPath: /kube-dns-config
      - name: dnsmasq
        image: gcr.io/google_containers/k8s-dns-dnsmasq-nanny-amd64:1.14.7
        livenessProbe:
          httpGet:
            path: /healthcheck/dnsmasq
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        args:
        - -v=2
        - -logtostderr
        - -configDir=/etc/k8s/dns/dnsmasq-nanny
        - -restartDnsmasq=true
        - --
        - -k
        - --cache-size=1000
        - --no-negcache
        - --log-facility=-
        - --server=/$${cluster_svc_domain}/127.0.0.1#10053
        - --server=/in-addr.arpa/127.0.0.1#10053
        - --server=/ip6.arpa/127.0.0.1#10053
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        # see: https://github.com/kubernetes/kubernetes/issues/29055 for details
        resources:
          requests:
            cpu: 150m
            memory: 20Mi
        volumeMounts:
        - name: kube-dns-config
          mountPath: /etc/k8s/dns/dnsmasq-nanny
      - name: sidecar
        image: gcr.io/google_containers/k8s-dns-sidecar-amd64:1.14.7
        livenessProbe:
          httpGet:
            path: /metrics
            port: 10054
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
        args:
        - --v=2
        - --logtostderr
        - --probe=kubedns,127.0.0.1:10053,$${cluster_svc_name}.default.svc.$${cluster_svc_domain},5,SRV
        - --probe=dnsmasq,127.0.0.1:53,$${cluster_svc_name}.default.svc.$${cluster_svc_domain},5,SRV
        ports:
        - containerPort: 10054
          name: metrics
          protocol: TCP
        resources:
          requests:
            memory: 20Mi
            cpu: 10m
      dnsPolicy: Default  # Don't use cluster DNS.
      serviceAccountName: kube-dns
EOF

  vars {
    cluster_svc_dns_ip = "${local.cluster_svc_dns_ip}"
    cluster_svc_name   = "${local.cluster_svc_name}"
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

