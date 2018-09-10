////////////////////////////////////////////////////////////////////////////////
//                                    K8s                                     //
////////////////////////////////////////////////////////////////////////////////

// k8s_version may be set to:
//
//    * release/(latest|stable|<version>)
//    * ci/(latest|<version>)
variable "k8s_version" {
  default = "release/v1.11.2"
}

// The name of the cluster
variable "cluster_name" {
  default = "k8s"
}

// The port on which K8s advertises the API server
variable "api_secure_port" {
  default = "443"
}

// The number of controller nodes
variable "ctl_count" {
  default = "2"
}

// The number of worker nodes
variable "wrk_count" {
  default = "1"
}

variable "cluster_admin" {
  default = "kubernetes"
}

// A list of DNS SANs to add to the cluster's TLS certificate
variable "cluster_sans_dns_names" {
  default = []
}

// Can be generated with:
//
//  head -c 32 /dev/urandom | base64
variable "k8s_encryption_key" {
  default = ""
}

variable "service_cidr" {
  default = "10.32.0.0/24"
}

variable "cluster_cidr" {
  default = "10.200.0.0/16"
}

variable "pod_cidr" {
  default = "10.200.%d.0/24"
}

////////////////////////////////////////////////////////////////////////////////
//                                   VM                                       //
////////////////////////////////////////////////////////////////////////////////
variable "ctl_vm_name" {
  default = "k8s-c%02d"
}

variable "wrk_vm_name" {
  default = "k8s-w%02d"
}

variable "ctl_vm_num_cpu" {
  default = "8"
}

variable "ctl_vm_num_cores_per_socket" {
  default = "4"
}

variable "ctl_vm_memory" {
  default = "32768"
}

variable "ctl_vm_disk_size" {
  default = "20"
}

variable "wrk_vm_num_cpu" {
  default = "16"
}

variable "wrk_vm_num_cores_per_socket" {
  default = "4"
}

variable "wrk_vm_memory" {
  default = "65536"
}

variable "wrk_vm_disk_size" {
  default = "100"
}

////////////////////////////////////////////////////////////////////////////////
//                                Networking                                  //
////////////////////////////////////////////////////////////////////////////////
variable "ctl_network_hostname" {
  default = "k8s-c%02d"
}

variable "wrk_network_hostname" {
  default = "k8s-w%02d"
}

// The IP range for masters is 192.168.2.128-191, 63 hosts.
//
// Please see cidrhost at https://www.terraform.io/docs/configuration/interpolation.html 
// and http://www.rjsmith.com/CIDR-Table.html for more information. 
variable "ctl_network_ipv4_address" {
  default = "192.168.2.128/25"
}

// The IP range for masters is 192.168.2.192-254, 62 hosts.
//
// Please see cidrhost at https://www.terraform.io/docs/configuration/interpolation.html 
// and http://www.rjsmith.com/CIDR-Table.html for more information. 
variable "wrk_network_ipv4_address" {
  default = "192.168.2.192/26"
}

// A boolean true opens iptables wide-open. This setting should only be
// used during development.
variable "iptables_allow_all" {
  default = true
}

////////////////////////////////////////////////////////////////////////////////
//                              Artifacts                                     //
////////////////////////////////////////////////////////////////////////////////

variable "jq_version" {
  default = "1.5"
}

// controller

// https://github.com/etcd-io/etcd/releases
variable "etcd_version" {
  default = "3.3.9"
}

// https://github.com/coredns/coredns/releases
variable "coredns_version" {
  default = "1.2.2"
}

// Valid versions include:
//   * 1.14.0
//   * 1.15.2
variable "nginx_version" {
  default = "1.14.0"
}

// worker

// https://github.com/kubernetes-incubator/cri-tools/releases
variable "crictl_version" {
  default = "1.11.1"
}

// https://github.com/opencontainers/runc/releases
variable "runc_version" {
  default = "1.0.0-rc5"
}

// https://storage.googleapis.com/gvisor/releases/nightly
variable "runsc_version" {
  default = "2018-09-01"
}

// https://github.com/containernetworking/plugins/releases
variable "cni_plugins_version" {
  default = "0.7.1"
}

// https://github.com/containerd/containerd/releases
variable "containerd_version" {
  //default = "1.1.0"
  default = "1.2.0-beta.2"
}

////////////////////////////////////////////////////////////////////////////////
//                                  TLS                                        //
////////////////////////////////////////////////////////////////////////////////
variable "tls_ca_crt" {
  default = ""
}

variable "tls_ca_key" {
  default = ""
}

locals {
  tls_ca_crt = "${base64decode(var.tls_ca_crt)}"
  tls_ca_key = "${base64decode(var.tls_ca_key)}"
}

variable "tls_bits" {
  default = "2048"
}

variable "tls_days" {
  default = "365"
}

variable "tls_org" {
  default = "VMware"
}

variable "tls_ou" {
  default = "CNX"
}

variable "tls_country" {
  default = "US"
}

variable "tls_province" {
  default = "California"
}

variable "tls_locality" {
  default = "Palo Alto"
}

variable "tls_email" {
  default = "cnx@vmware.com"
}
