data "vsphere_datacenter" "datacenter" {
  name = "${var.datacenter}"
}

data "vsphere_resource_pool" "resource_pool" {
  name          = "${var.resource_pool}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_datastore" "datastore" {
  name          = "${var.datastore_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_network" "network" {
  name          = "${var.network_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

data "vsphere_virtual_machine" "template" {
  name          = "${var.template_name}"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}
