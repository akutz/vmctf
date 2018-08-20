////////////////////////////////////////////////////////////////////////////////
//                                   CNI                                      //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "worker_cni_bin_dir" {
  filesystem = "root"
  path       = "${data.ignition_directory.bin_dir.path}/cni"

  // mode = 0755
  mode = 493
}

data "ignition_directory" "worker_cni_netd_dir" {
  filesystem = "root"
  path       = "/etc/cni/net.d"

  // mode = 0755
  mode = 493
}

data "template_file" "worker_cni_netd_10_bridge_conf" {
  count    = "${var.worker_count}"
  template = "${file("${path.module}/worker/etc/cni_net.d_10_bridge.conf")}"

  vars {
    pod_cidr = "${data.template_file.worker_pod_cidr.*.rendered[count.index]}"
  }
}

data "ignition_file" "worker_cni_netd_10_bridge_conf" {
  count      = "${var.worker_count}"
  filesystem = "root"
  path       = "${data.ignition_directory.worker_cni_netd_dir.path}/10-bridge.conf"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_cni_netd_10_bridge_conf.*.rendered[count.index]}"
  }
}

data "ignition_file" "worker_cni_netd_99_loopback_conf" {
  filesystem = "root"
  path       = "${data.ignition_directory.worker_cni_netd_dir.path}/99-loopback.conf"

  // mode = 0644
  mode = 420

  content {
    content = "${file("${path.module}/worker/etc/cni_net.d_99_loopback.conf")}"
  }
}