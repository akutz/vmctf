////////////////////////////////////////////////////////////////////////////////
//                                Globals                                     //
////////////////////////////////////////////////////////////////////////////////
locals {
  cluster_fqdn       = "${var.cluster_name}.${var.network_domain}"
  cluster_svc_ip     = "${cidrhost(var.service_cidr, "1")}"
  cluster_svc_dns_ip = "${cidrhost(var.service_cidr, "10")}"

  cluster_svc_domain = "cluster.local"

  cluster_svc_name = "kubernetes"

  cluster_svc_fqdn = "${local.cluster_svc_name}.default.svc.${local.cluster_svc_domain}"
}

// Get the etcd discovery token.
provider "http" {}

data "http" "etcd_discovery" {
  url = "https://discovery.etcd.io/new?size=${var.ctl_count}"
}

locals {
  etcd_discovery = "${data.http.etcd_discovery.body}"
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

////////////////////////////////////////////////////////////////////////////////
//                             First Boot Env Vars                            //
////////////////////////////////////////////////////////////////////////////////

// Written to /etc/default/yakity
data "template_file" "yakity_env" {
  count = "${var.ctl_count + var.wrk_count}"

  template = <<EOF
DEBUG="$${debug}"

# Information about the host's network.
NETWORK_DOMAIN="$${network_domain}"
NETWORK_IPV4_SUBNET_CIDR="$${network_ipv4_subnet_cidr}"
NETWORK_DNS_1="$${network_dns_1}"
NETWORK_DNS_2="$${network_dns_2}"
NETWORK_DNS_SEARCH="$${network_dns_search}"

# Can be generated with:
#  head -c 32 /dev/urandom | base64
ENCRYPTION_KEY="$${encryption_key}"

# The etcd discovery URL used by etcd members to join the etcd cluster.
# This URL can be curled to obtain FQDNs and IP addresses for the 
# members of the etcd cluster.
ETCD_DISCOVERY="$${etcd_discovery}"

# The number of controller nodes in the cluster.
NUM_CONTROLLERS="$${num_controllers}"

# The number of nodes in the cluster.
NUM_NODES="$${num_nodes}"

# The gzip'd, base-64 encoded CA cert/key pair used to generate certificates
# for the cluster.
TLS_CA_CRT_GZ="$${tls_ca_crt}"
TLS_CA_KEY_GZ="$${tls_ca_key}"

# The name of the cloud provider to use.
CLOUD_PROVIDER=vsphere

# The gzip'd, base-64 encoded cloud provider configuration to use.
CLOUD_CONFIG="$${cloud_config}"

# The K8s cluster admin.
CLUSTER_ADMIN="$${k8s_cluster_admin}"

# The K8s cluster CIDR.
CLUSTER_CIDR="$${k8s_cluster_cidr}"

# The name of the K8s cluster.
CLUSTER_NAME="$${k8s_cluster_name}"

# The FQDN of the K8s cluster.
CLUSTER_FQDN="$${k8s_cluster_fqdn}"

# The secure port on which the K8s API server is advertised.
SECURE_PORT=$${k8s_secure_port}

# The K8s cluster's service CIDR.
SERVICE_CIDR="$${k8s_service_cidr}"

# The IP address used to access the K8s API server on the service network.
SERVICE_IPV4_ADDRESS="$${k8s_service_ip}"

# The IP address of the DNS server for the service network.
SERVICE_DNS_IPV4_ADDRESS="$${k8s_service_dns_ip}"

# The domain name used by the K8s service network.
SERVICE_DOMAIN="$${k8s_service_domain}"

# The FQDN used to access the K8s API server on the service network.
SERVICE_FQDN="$${k8s_service_fqdn}"

# The name of the service record that points to the K8s API server on
# the service network.
SERVICE_NAME="$${k8s_service_name}"

# Versions of the software packages installed on the controller and
# worker nodes. Please note that not all the software packages listed
# below are installed on both controllers and workers. Some is intalled
# on one, and some the other. Some software, such as jq, is installed
# on both controllers and workers.
K8S_VERSION="$${k8s_version}"
CNI_PLUGINS_VERSION="$${cni_plugins_version}"
CONTAINERD_VERSION="$${containerd_version}"
COREDNS_VERSION="$${coredns_version}"
CRICTL_VERSION="$${crictl_version}"
ETCD_VERSION="$${etcd_version}"
JQ_VERSION="$${jq_version}"
VERSION="$${k8s_version}"
NGINX_VERSION="$${nginx_version}"
RUNC_VERSION="$${runc_version}"
RUNSC_VERSION="$${runsc_version}"
EOF

  vars {
    //
    debug = "${var.debug}"

    //
    network_domain           = "${var.network_domain}"
    network_ipv4_subnet_cidr = "${var.network_ipv4_gateway}/24"
    network_dns_1            = "${var.network_dns_1}"
    network_dns_2            = "${var.network_dns_2}"
    network_dns_search       = "${var.network_search_domains}"

    //
    etcd_discovery = "${local.etcd_discovery}"

    //
    num_controllers = "${var.ctl_count}"
    num_nodes       = "${var.ctl_count + var.wrk_count}"

    //
    encryption_key = "${var.k8s_encryption_key}"

    //
    cloud_config = "${base64gzip(data.template_file.cloud_provider_config.rendered)}"

    //
    tls_ca_crt = "${base64gzip(local.tls_ca_crt)}"
    tls_ca_key = "${base64gzip(local.tls_ca_key)}"

    //
    k8s_version        = "${var.k8s_version}"
    k8s_cluster_admin  = "${var.cluster_admin}"
    k8s_cluster_cidr   = "${var.cluster_cidr}"
    k8s_cluster_fqdn   = "${local.cluster_fqdn}"
    k8s_cluster_name   = "${var.cluster_name}"
    k8s_secure_port    = "${var.api_secure_port}"
    k8s_service_cidr   = "${var.service_cidr}"
    k8s_service_ip     = "${local.cluster_svc_ip}"
    k8s_service_dns_ip = "${local.cluster_svc_dns_ip}"
    k8s_service_domain = "${local.cluster_svc_domain}"
    k8s_service_fqdn   = "${local.cluster_svc_fqdn}"
    k8s_service_name   = "${local.cluster_svc_name}"

    //
    cni_plugins_version = "${var.cni_plugins_version}"
    containerd_version  = "${var.containerd_version}"
    coredns_version     = "${var.coredns_version}"
    crictl_version      = "${var.crictl_version}"
    etcd_version        = "${var.etcd_version}"
    jq_version          = "${var.jq_version}"
    k8s_version         = "${var.k8s_version}"
    nginx_version       = "${var.nginx_version}"
    runc_version        = "${var.runc_version}"
    runsc_version       = "${var.runsc_version}"
  }
}
