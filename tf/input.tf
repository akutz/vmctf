////////////////////////////////////////////////////////////////////////////////
//                                  Global                                    //
////////////////////////////////////////////////////////////////////////////////

// Enables debug functionality in parts of the deployment, such as causing
// shell scripts to enable set -x.
variable "debug" {
  default = "false"
}

////////////////////////////////////////////////////////////////////////////////
//                                 Guest OS                                   //
////////////////////////////////////////////////////////////////////////////////

// The users created on the host. The variable format is a map of
// of key/value pairs with the keys the user names and the values the
// public SSH keys for the corresponding user. 
//
// The value may be specified with an environment variable using HCL
// syntax. For example:
//
//     TF_VAR_os_users='{"akutz","ssh_key","luoh",ssh_key",...}'
variable "os_users" {
  default = {
    akutz = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDE0c5FczvcGSh/tG4iw+Fhfi/O5/EvUM/96js65tly4++YTXK1d9jcznPS5ruDlbIZ30oveCBd3kT8LLVFwzh6hepYTf0YmCTpF4eDunyqmpCXDvVscQYRXyasEm5olGmVe05RrCJSeSShAeptv4ueIn40kZKOghinGWLDSZG4+FFfgrmcMCpx5YSCtX2gvnEYZJr0czt4rxOZuuP7PkJKgC/mt2PcPjooeX00vAj81jjU2f3XKrjjz2u2+KIt9eba+vOQ6HiC8c2IzRkUAJ5i1atLy8RIbejo23+0P4N2jjk17QySFOVHwPBDTYb0/0M/4ideeU74EN/CgVsvO6JrLsPBR4dojkV5qNbMNxIVv5cUwIy2ThlLgqpNCeFIDLCWNZEFKlEuNeSQ2mPtIO7ETxEL2Cz5y/7AIuildzYMc6wi2bofRC8HmQ7rMXRWdwLKWsR0L7SKjHblIwarxOGqLnUI+k2E71YoP7SZSlxaKi17pqkr0OMCF+kKqvcvHAQuwGqyumTEWOlH6TCx1dSPrW+pVCZSHSJtSTfDW2uzL6y8k10MT06+pVunSrWo5LHAXcS91htHV1M1UrH/tZKSpjYtjMb5+RonfhaFRNzvj7cCE1f3Kp8UVqAdcGBTtReoE8eRUT63qIxjw03a7VwAyB2w+9cu1R9/vAo8SBeRqw== sakutz@gmail.com"
    luoh  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDdCb/l7v2Gu44VQTeiUH1sQAmXQpKkJvdQUS2YriO/ysx+adfimT34fkhX7ZbiAC6kNKHFGQ6sRLnudVRv65N4P5SkQ27EtjS1W7rGEykZHarunq6szg5gAEFqVOrucn5Xey+iqDwMvM9w8pqKbJYvDy/7SGfz/cDvnWEcqIoYLy66IUPIaNwN7/eR6bZ7ab3IMpAkaR9gWrl4vpFql0fEVJgisbC8oPuX7sREhpaaO4BSWwEUyn97NnAFbDRN1fsohaLJVYD2vA6oXet/J5w0eFEGEgYAZuBB1VqbUXD4FfLxf8MP7qFniuCcfZHgzO5cbyK4xjrpknkHkk+b7sgON/2olCqM7+XDfgeuSxZgN9OJTRl2TesNMvhbXgFpnWJxIAkH0mbByDUNo+TQK58khTkVDlB6BOchRKN5EzKpUdzlBxVGJie35xAIqcFQGBw7E1nWBgDgAA9KXz4/jAdn3e81aOHzIGmVf9glj65TQRb2qQ4Rr/VwPfyUHCQTeGL5ykcHid7QbvMMXSx6EEXV4zP21vL98eOnwnoTyLD4JrxkEUAJS+9yxB75Ck6DF2AVkF+hnW0BUmcHI0BnWyXdb9SLsGwG4W0O4jOVXmq/yz+I5JkkPX4OB/eugetbb3L1CPczG/N0RbXCykU7TJdLSpBV27P7ho9JfK+UWAC2Gw== luoh@luoh-m01.vmware.com"
  }
}

variable "os_seed_uid" {
  default = "1000"
}
variable "os_seed_gid" {
  default = "1000"
}

////////////////////////////////////////////////////////////////////////////////
//                                Networking                                  //
////////////////////////////////////////////////////////////////////////////////

// The FQDN of the domain to which all hosts should belong.
variable "network_domain" {
  default = "vmware.ci"
}

// The name of the first network device in VMs provisioned from the CoreOS
// template.
variable "network_device" {
  default = "ens192"
}

// Please see the following URL for more information on "network_" variables:
// https://www.freedesktop.org/software/systemd/man/systemd.network.html.
variable "network_dhcp" {
  default = "no"
}

variable "network_dns_1" {
  default = "8.8.8.8"
}

variable "network_dns_2" {
  default = "8.8.4.4"
}

// A space-separated list of search domains.
variable "network_search_domains" {
  default = "vmware.ci"
}

// Per https://www.freedesktop.org/software/systemd/man/systemd.network.html
//
// > A static IPv4 or IPv6 address and its prefix length, separated by a 
// > "/" character. 
//variable "network_ipv4_address" {}

variable "network_ipv4_gateway" {
  default = "192.168.3.1"
}

////////////////////////////////////////////////////////////////////////////////
//                                vSphere                                     //
////////////////////////////////////////////////////////////////////////////////

variable "vsphere_user" {}

variable "vsphere_password" {}

variable "vsphere_server" {
  default = "vcenter.sddc-54-70-161-229.vmc.vmware.com"
}

variable "vsphere_server_port" {
  default = "443"
}

variable "vsphere_allow_unverified_ssl" {
  default = false
}

// The name of the datacenter to which VMs belong
variable "vsphere_datacenter" {
  default = "SDDC-Datacenter"
}

// The name of the resource pool to which VMs belong
variable "vsphere_resource_pool" {
  default = "Compute-ResourcePool"
}

// The name of the datastore where VMs are located
variable "vsphere_datastore" {
  default = "WorkloadDatastore"
}

// The folder path where VMs are located
variable "vsphere_folder" {
  default = "Workloads"
}

// The name of the vSphere network to which the VMs' NICs will be attached.
variable "vsphere_network" {
  default = "VMC Networks/sddc-cgw-network-3"
}

// The path of the template to use when cloning.
variable "vsphere_template" {
  default = "Templates/coreos_production_vmware_ova"
}
