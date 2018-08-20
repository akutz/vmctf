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

variable "master_count" {
  default = "2"
}

variable "worker_count" {
  default = "1"
}

variable "cluster_name" {
  default = "k8s.%s"
}

// A list of DNS SANs to add to the cluster's TLS certificate
variable "cluster_sans_dns_names" {
  default = [
    "api.cicd.cnx.cna.vmware.run",
  ]
}

// Can be generated with:
//
//  head -c 32 /dev/urandom | base64
variable "k8s_encryption_key" {
  default = ""
}

variable "service_cluster_ip_range" {
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
variable "master_vm_name" {
  default = "k8s-m%02d"
}

variable "worker_vm_name" {
  default = "k8s-w%02d"
}

variable "master_api_secure_port" {
  default = "443"
}

variable "master_vm_num_cpu" {
  default = "8"
}

variable "master_vm_num_cores_per_socket" {
  default = "4"
}

variable "master_vm_memory" {
  default = "65536"
}

variable "worker_vm_num_cpu" {
  default = "8"
}

variable "worker_vm_num_cores_per_socket" {
  default = "4"
}

variable "worker_vm_memory" {
  default = "65536"
}

////////////////////////////////////////////////////////////////////////////////
//                                Networking                                  //
////////////////////////////////////////////////////////////////////////////////
variable "master_network_hostname" {
  default = "k8s-m%02d.%s"
}

variable "worker_network_hostname" {
  default = "k8s-w%02d.%s"
}

// The IP range for masters is 192.168.2.128-191, 63 hosts.
//
// Please see cidrhost at https://www.terraform.io/docs/configuration/interpolation.html 
// and http://www.rjsmith.com/CIDR-Table.html for more information. 
variable "master_network_ipv4_address" {
  default = "192.168.2.128/25"
}

// The IP range for masters is 192.168.2.192-254, 62 hosts.
//
// Please see cidrhost at https://www.terraform.io/docs/configuration/interpolation.html 
// and http://www.rjsmith.com/CIDR-Table.html for more information. 
variable "worker_network_ipv4_address" {
  default = "192.168.2.192/26"
}

////////////////////////////////////////////////////////////////////////////////
//                              Artifacts                                     //
////////////////////////////////////////////////////////////////////////////////

// master

// https://github.com/coreos/etcd/releases
variable "etcd_artifact" {
  default = "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz"
}

// https://github.com/coredns/coredns/releases
variable "coredns_artifact" {
  default = "https://github.com/coredns/coredns/releases/download/v1.2.0/coredns_1.2.0_linux_amd64.tgz"
}

// Valid versions include:
//   * v1.14.0
//   * v1.15.2
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
  default = "2018-08-17"
}

// https://github.com/containernetworking/plugins/releases
variable "cni_plugins_version" {
  default = "0.7.1"
}

// https://github.com/containerd/containerd/releases
variable "containerd_version" {
  default = "1.1.0"
}
