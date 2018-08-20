////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "vsphere_cloud_provider_conf" {
  template = "${file("${path.module}/etc/vsphere_cloud_provider.conf.yaml")}"

  vars {
    server        = "${var.vsphere_server}"
    username      = "${var.vsphere_user}"
    password      = "${var.vsphere_password}"
    port          = "${var.vsphere_server_port}"
    insecure      = "${var.vsphere_allow_unverified_ssl ? 1 : 0}"
    datacenter    = "${var.vsphere_datacenter}"
    folder        = "${var.vsphere_folder}"
    datastore     = "${var.vsphere_datastore}"
    resource_pool = "${var.vsphere_resource_pool}"
    network       = "${var.vsphere_network}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "vsphere_cloud_provider_conf" {
  filesystem = "root"
  path       = "${data.ignition_directory.kubernetes_root.path}/cloud.conf"

  // mode = 0640
  mode = 416
  uid  = 0
  gid  = 0

  content {
    content = "${data.template_file.vsphere_cloud_provider_conf.rendered}"
  }
}
