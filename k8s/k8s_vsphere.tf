////////////////////////////////////////////////////////////////////////////////
//                                vSphere                                     //
////////////////////////////////////////////////////////////////////////////////
data "vsphere_virtual_machine" "centos_cloud_template" {
  name          = "centos_cloud_template"
  datacenter_id = "${data.vsphere_datacenter.datacenter.id}"
}

/*
locals {
  // Static MAC addresses are used for the K8s controller and worker nodes
  // in order to keep the network happy while testing.
  //
  // The number of elements in the list must equal or exceed the value
  // of var.ctl_count.

  ctl_mac_addresses = [
    "00:00:0f:41:1b:d3",
    "00:00:0f:59:aa:c3",
    "00:00:0f:77:88:e3",
  ]
}
*/

resource "vsphere_virtual_machine" "controller" {
  count = "${var.ctl_count}"

  name = "${format(var.ctl_vm_name, count.index+1)}"

  resource_pool_id     = "${data.vsphere_resource_pool.resource_pool.id}"
  datastore_id         = "${data.vsphere_datastore.datastore.id}"
  folder               = "${var.vsphere_folder}"
  guest_id             = "${data.vsphere_virtual_machine.centos_cloud_template.guest_id}"
  scsi_type            = "${data.vsphere_virtual_machine.centos_cloud_template.scsi_type}"
  num_cpus             = "${var.ctl_vm_num_cpu}"
  num_cores_per_socket = "${var.ctl_vm_num_cores_per_socket}"
  memory               = "${var.ctl_vm_memory}"

  // Required by the vSphere cloud provider
  enable_disk_uuid = true

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.centos_cloud_template.network_interface_types[0]}"

    //use_static_mac = true
    //mac_address    = "${local.ctl_mac_addresses[count.index]}"
  }

  disk {
    label            = "disk0"
    size             = "${var.ctl_vm_disk_size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.centos_cloud_template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.centos_cloud_template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.centos_cloud_template.id}"
  }

  extra_config {
    "guestinfo.metadata"          = "${base64gzip(data.template_file.ctl_cloud_metadata.*.rendered[count.index])}"
    "guestinfo.metadata.encoding" = "gzip+base64"
    "guestinfo.userdata"          = "${base64gzip(data.template_file.ctl_cloud_config.*.rendered[count.index])}"
    "guestinfo.userdata.encoding" = "gzip+base64"
  }
}

resource "vsphere_virtual_machine" "worker" {
  count = "${var.wrk_count}"

  name = "${format(var.wrk_vm_name, count.index+1)}"

  resource_pool_id     = "${data.vsphere_resource_pool.resource_pool.id}"
  datastore_id         = "${data.vsphere_datastore.datastore.id}"
  folder               = "${var.vsphere_folder}"
  guest_id             = "${data.vsphere_virtual_machine.centos_cloud_template.guest_id}"
  scsi_type            = "${data.vsphere_virtual_machine.centos_cloud_template.scsi_type}"
  num_cpus             = "${var.wrk_vm_num_cpu}"
  num_cores_per_socket = "${var.wrk_vm_num_cores_per_socket}"
  memory               = "${var.wrk_vm_memory}"

  // Required by the vSphere cloud provider
  enable_disk_uuid = true

  network_interface {
    network_id   = "${data.vsphere_network.network.id}"
    adapter_type = "${data.vsphere_virtual_machine.centos_cloud_template.network_interface_types[0]}"

    //use_static_mac = true
    //mac_address    = "${local.wrk_mac_addresses[count.index]}"
  }

  disk {
    label            = "disk0"
    size             = "${var.wrk_vm_disk_size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.centos_cloud_template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.centos_cloud_template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.centos_cloud_template.id}"
  }

  extra_config {
    "guestinfo.metadata"          = "${base64gzip(data.template_file.wrk_cloud_metadata.*.rendered[count.index])}"
    "guestinfo.metadata.encoding" = "gzip+base64"
    "guestinfo.userdata"          = "${base64gzip(data.template_file.wrk_cloud_config.*.rendered[count.index])}"
    "guestinfo.userdata.encoding" = "gzip+base64"
  }
}
