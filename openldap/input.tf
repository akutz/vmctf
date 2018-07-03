// The name of the VM
variable "name" {
  default = "ldap"
}

# The host name assigned to the VM as well as the value of the 
# --hostname flag when starting the LDAP container.
variable "hostname" {
  default = "ldap.cicd.cnx.cna.vmware.run"
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

# This value is translated to an LDAP distinguished name (DN) and used
# as the base for the users and groups organizational units (OUs).
# For example, the default value results in the creation of the
# following LDAP objects:
#
#                                    DC=vmware,DC=local
#                             DC=cna,DC=vmware,DC=local
#                      DC=cnx,DC=cna,DC=vmware,DC=local
#              DC=cicd,DC=cnx,DC=cna,DC=vmware,DC=local
#     OU=users,DC=cicd,DC=cnx,DC=cna,DC=vmware,DC=local
#    OU=groups,DC=cicd,DC=cnx,DC=cna,DC=vmware,DC=local
variable "ldap_domain" {
  default = "cicd.cnx.cna.vmware.local"
}

variable "ldap_root_user" {
  default = ""
}

variable "ldap_root_pass" {
  default = ""
}

# The LDIF contents used to seed the LDAP server's database.
# The value should be the base64-encoded, gzipped contents of
# LDIF file.
variable "ldap_ldif" {
  default = ""
}

# The CA used with the LDAP server's TLS configuration. 
# The value should be the base64-encoded, gzipped contents of
# a PEM-formatted CA file.
variable "ldap_tls_ca" {
  default = ""
}

# The key file used with the LDAP server's TLS configuration.
# The value should be the base64-encoded, gzipped contents of
# a PEM-formatted key file.
variable "ldap_tls_key" {
  default = ""
}

# The crt file used with the LDAP server's TLS configuration.
# The value should be the base64-encoded, gzipped contents of 
# a PEM-formatted certificate file.
variable "ldap_tls_crt" {
  default = ""
}

/*
https://www.openldap.org/doc/admin24/slapdconfig.html#loglevel%20%3Clevel%3E

Level  Keyword         Description
-1     any             enable all debugging
0      no debugging
1      (0x1 trace)     trace function calls
2      (0x2 packets)   debug packet handling
4      (0x4 args)      heavy trace debugging
8      (0x8 conns)     connection management
16     (0x10 BER)      print out packets sent and received
32     (0x20 filter)   search filter processing
64     (0x40 config)   configuration processing
128    (0x80 ACL)      access control list processing
256    (0x100 stats)   stats log connections/operations/results
512    (0x200 stats2)  stats log entries sent
1024   (0x400 shell)   print communication with shell backends
2048   (0x800 parse)   print entry parsing debugging
16384  (0x4000 sync)   syncrepl consumer processing
32768  (0x8000 none)   only messages that get logged whatever log level is set
*/
variable "ldap_log_level" {
  default = "0"
}
