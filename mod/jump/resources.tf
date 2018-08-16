resource "vsphere_virtual_machine" "virtual_machine" {
  name = "${var.vm_name}"

  resource_pool_id     = "${var.vsphere_resource_pool}"
  datastore_id         = "${var.vsphere_datastore}"
  folder               = "${var.vsphere_folder}"
  guest_id             = "${data.vsphere_virtual_machine.template.guest_id}"
  scsi_type            = "${data.vsphere_virtual_machine.template.scsi_type}"
  num_cpus             = "${var.vm_num_cpu}"
  num_cores_per_socket = "${var.vm_num_cores_per_socket}"
  memory               = "${var.vm_memory}"

  network_interface {
    network_id   = "${var.vsphere_network}"
    adapter_type = "${data.vsphere_virtual_machine.template.network_interface_types[0]}"
  }

  disk {
    label            = "disk0"
    size             = "${data.vsphere_virtual_machine.template.disks.0.size}"
    eagerly_scrub    = "${data.vsphere_virtual_machine.template.disks.0.eagerly_scrub}"
    thin_provisioned = "${data.vsphere_virtual_machine.template.disks.0.thin_provisioned}"
  }

  clone {
    template_uuid = "${data.vsphere_virtual_machine.template.id}"
  }

  vapp {
    properties {
      "guestinfo.coreos.config.data"          = "${base64encode(data.ignition_config.config.rendered)}"
      "guestinfo.coreos.config.data.encoding" = "base64"
    }
  }
}
