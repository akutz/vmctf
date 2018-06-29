// The name of the VM
variable "name" {
  default = "openldap"
}

// The total number of vCPUs.
variable "num_cpu" {
  default = "4"
}

// The number of cores per CPU socket. This value determines the number
// of sockets a VM has. If num_cpu=8 and num_cores_per_socket=4, then
// a VM will have two sockets with four cores each.
variable "num_cores_per_socket" {
  default = "2"
}

// The VM's memory in MB
variable "memory" {
  default = "16384"
}

// The name of the datacenter in which the VM is created
variable "datacenter" {
  default = "SDDC-Datacenter"
}

// The name of the resource pool in which the VM is created
variable "resource_pool" {
  default = "Compute-ResourcePool"
}

// The name of the datastore in which the VM is created
variable "datastore_name" {
  default = "WorkloadDatastore"
}

// The folder path in which the VM is created
variable "folder_path" {
  default = "Workloads"
}

// The name of the template to use when cloning.
variable "template_name" {
  default = "Templates/coreos_production_vmware_ova"
}

////////////////////////////////////////////////////////////////////////////////
//                                Networking                                  //
////////////////////////////////////////////////////////////////////////////////

// The name of the network to use.
variable "network_name" {
  default = "VMC Networks/sddc-cgw-network-2"
}

variable "network_domain" {
  default = "local"
}

variable "network_device" {
  default = "ens192"
}

//
// See https://www.freedesktop.org/software/systemd/man/systemd.network.html
// for information on what values to use with the properties prefixed with 
// "network_". 
variable "network_dhcp" {
  default = "no"
}

variable "network_dns_1" {
  default = "8.8.8.8"
}

variable "network_dns_2" {
  default = "8.8.4.4"
}

variable "network_domains" {
  default = ""
}

// Per https://www.freedesktop.org/software/systemd/man/systemd.network.html:
//
// > A static IPv4 or IPv6 address and its prefix length, separated by a 
// > "/" character. 
variable "network_ipv4_address" {
  default = "192.168.2.2/24"
}

variable "network_ipv4_gateway" {
  default = "192.168.2.1"
}

////////////////////////////////////////////////////////////////////////////////
//                                 LDAP                                       //
////////////////////////////////////////////////////////////////////////////////
variable "ldap_org" {
  default = "VMware"
}

variable "ldap_domain" {
  default = "cicd.cnx.cna.vmware.com"
}

variable "ldap_root_user" {
  default = ""
}

variable "ldap_root_pass" {
  default = ""
}

variable "ldap_ldif64" {
  default = ""
}
