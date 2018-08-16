////////////////////////////////////////////////////////////////////////////////
//                                vSphere                                     //
////////////////////////////////////////////////////////////////////////////////

provider vsphere {
  user                 = "${var.vsphere_user}"
  password             = "${var.vsphere_password}"
  vsphere_server       = "${var.vsphere_server}"
  allow_unverified_ssl = "${var.vsphere_allow_unverified_ssl}"
}

data "vsphere_datacenter" "datacenter" {
  name = "${var.vsphere_datacenter}"
}

data "vsphere_resource_pool" "resource_pool" {
  name          = "${var.vsphere_resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.vsphere_datastore}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_network" "network" {
  name          = "${var.vsphere_network}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.vsphere_template}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}