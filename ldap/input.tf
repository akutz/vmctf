// The name of the VM
variable "name" {
  default = "ldap"
}

# The host name assigned to the VM as well as the value of the 
# --hostname flag when starting the LDAP container.
variable "hostname" {
  default = "ldap.vmware.ci"
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

// The users to create with Ignition. The variable format is a map of
// of key/value pairs with the keys the user names and the values the
// public SSH keys for the corresponding user. 
//
// The value may be specified with an environment variable using HCL
// syntax. For example:
//
//     TF_VAR_users='{"akutz","ssh_key","luoh",ssh_key",...}'
variable users {
  default = {
    akutz = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDE0c5FczvcGSh/tG4iw+Fhfi/O5/EvUM/96js65tly4++YTXK1d9jcznPS5ruDlbIZ30oveCBd3kT8LLVFwzh6hepYTf0YmCTpF4eDunyqmpCXDvVscQYRXyasEm5olGmVe05RrCJSeSShAeptv4ueIn40kZKOghinGWLDSZG4+FFfgrmcMCpx5YSCtX2gvnEYZJr0czt4rxOZuuP7PkJKgC/mt2PcPjooeX00vAj81jjU2f3XKrjjz2u2+KIt9eba+vOQ6HiC8c2IzRkUAJ5i1atLy8RIbejo23+0P4N2jjk17QySFOVHwPBDTYb0/0M/4ideeU74EN/CgVsvO6JrLsPBR4dojkV5qNbMNxIVv5cUwIy2ThlLgqpNCeFIDLCWNZEFKlEuNeSQ2mPtIO7ETxEL2Cz5y/7AIuildzYMc6wi2bofRC8HmQ7rMXRWdwLKWsR0L7SKjHblIwarxOGqLnUI+k2E71YoP7SZSlxaKi17pqkr0OMCF+kKqvcvHAQuwGqyumTEWOlH6TCx1dSPrW+pVCZSHSJtSTfDW2uzL6y8k10MT06+pVunSrWo5LHAXcS91htHV1M1UrH/tZKSpjYtjMb5+RonfhaFRNzvj7cCE1f3Kp8UVqAdcGBTtReoE8eRUT63qIxjw03a7VwAyB2w+9cu1R9/vAo8SBeRqw== sakutz@gmail.com"
    luoh  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdCb/l7v2Gu44VQTeiUH1sQAmXQpKkJvdQUS2YriO/ysx+adfimT34fkhX7ZbiAC6kNKHFGQ6sRLnudVRv65N4P5SkQ27EtjS1W7rGEykZHarunq6szg5gAEFqVOrucn5Xey+iqDwMvM9w8pqKbJYvDy/7SGfz/cDvnWEcqIoYLy66IUPIaNwN7/eR6bZ7ab3IMpAkaR9gWrl4vpFql0fEVJgisbC8oPuX7sREhpaaO4BSWwEUyn97NnAFbDRN1fsohaLJVYD2vA6oXet/J5w0eFEGEgYAZuBB1VqbUXD4FfLxf8MP7qFniuCcfZHgzO5cbyK4xjrpknkHkk+b7sgON/2olCqM7+XDfgeuSxZgN9OJTRl2TesNMvhbXgFpnWJxIAkH0mbByDUNo+TQK58khTkVDlB6BOchRKN5EzKpUdzlBxVGJie35xAIqcFQGBw7E1nWBgDgAA9KXz4/jAdn3e81aOHzIGmVf9glj65TQRb2qQ4Rr/VwPfyUHCQTeGL5ykcHid7QbvMMXSx6EEXV4zP21vL98eOnwnoTyLD4JrxkEUAJS+9yxB75Ck6DF2AVkF+hnW0BUmcHI0BnWyXdb9SLsGwG4W0O4jOVXmq/yz+I5JkkPX4OB/eugetbb3L1CPczG/N0RbXCykU7TJdLSpBV27P7ho9JfK+UWAC2Gw== luoh@luoh-m01.vmware.com"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                Networking                                  //
////////////////////////////////////////////////////////////////////////////////

// The name of the network to use.
variable "network_name" {
  default = "sddc-cgw-network-2"
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
  default = "192.168.2.3/24"
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
#                                    DC=vmware,DC=run
#                             DC=cna,DC=vmware,DC=run
#                      DC=cnx,DC=cna,DC=vmware,DC=run
#              DC=cicd,DC=cnx,DC=cna,DC=vmware,DC=run
#     OU=users,DC=cicd,DC=cnx,DC=cna,DC=vmware,DC=run
#    OU=groups,DC=cicd,DC=cnx,DC=cna,DC=vmware,DC=run
variable "ldap_domain" {
  default = "vmware.ci"
}

variable "ldap_root_user" {
  default = "root"
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

# Indicates how the server handles client-side certificates.
# Valid values include: never, allow, and try.
variable "ldap_tls_verify" {
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
