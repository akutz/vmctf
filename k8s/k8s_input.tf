////////////////////////////////////////////////////////////////////////////////
//                                    K8s                                     //
////////////////////////////////////////////////////////////////////////////////

# k8s_version may be set to:
# 
#    * release/(latest|stable|<version>)
#    * ci/(latest|<version>)
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
  default = "api.%s"
}

// Can be generated with:
//
//  head -c 32 /dev/urandom | base64
variable "k8s_encryption_key" {
  default = ""
}

////////////////////////////////////////////////////////////////////////////////
//                                   VM                                       //
////////////////////////////////////////////////////////////////////////////////
variable "master_vm_name" {
  default = "apim-%02d"
}

variable "worker_vm_name" {
  default = "apiw-%02d"
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
  default = "apim-%02d.%s"
}

variable "worker_network_hostname" {
  default = "apiw-%02d.%s"
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
variable "etcd_artifact" {
  default = "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz"
}

variable "coredns_artifact" {
  default = "https://github.com/coredns/coredns/releases/download/v1.2.0/coredns_1.2.0_linux_amd64.tgz"
}

variable "nginx_version" {
  default = "1.14.0"
}
