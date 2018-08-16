////////////////////////////////////////////////////////////////////////////////
//                                 Guest OS                                   //
////////////////////////////////////////////////////////////////////////////////
variable "os_users" {
  type = "map"
}

variable "os_seed_uid" {}
variable "os_seed_gid" {}

////////////////////////////////////////////////////////////////////////////////
//                                   VM                                       //
////////////////////////////////////////////////////////////////////////////////
variable "vm_name" {}

variable "vm_num_cpu" {}
variable "vm_num_cores_per_socket" {}
variable "vm_memory" {}

////////////////////////////////////////////////////////////////////////////////
//                                vSphere                                     //
////////////////////////////////////////////////////////////////////////////////
variable "vsphere_datacenter" {}

variable "vsphere_resource_pool" {}
variable "vsphere_datastore" {}
variable "vsphere_folder" {}
variable "vsphere_network" {}
variable "vsphere_template" {}

////////////////////////////////////////////////////////////////////////////////
//                                Networking                                  //
////////////////////////////////////////////////////////////////////////////////
variable "network_domain" {}

variable "network_hostname" {}
variable "network_device" {}
variable "network_dhcp" {}
variable "network_dns_1" {}
variable "network_dns_2" {}
variable "network_domains" {}
variable "network_ipv4_address" {}
variable "network_ipv4_gateway" {}
