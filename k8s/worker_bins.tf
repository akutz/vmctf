////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "worker_bins_env" {
  template = "${file("${path.module}/worker/etc/bins.env")}"

  vars {
    bin_dir             = "${data.ignition_directory.bin_dir.path}"
    cni_bin_dir         = "${data.ignition_directory.worker_cni_bin_dir.path}"
    k8s_version         = "${var.k8s_version}"
    crictl_version      = "${var.crictl_version}"
    runc_version        = "${var.runc_version}"
    runsc_version       = "${var.runsc_version}"
    cni_plugins_version = "${var.cni_plugins_version}"
    containerd_version  = "${var.containerd_version}"
  }
}

data "template_file" "worker_bins_service" {
  template = "${file("${path.module}/systemd/bins.service")}"

  vars {
    unit_name         = "bins.service"
    env_file          = "${data.ignition_file.worker_bins_env.path}"
    cmd_file          = "${data.ignition_file.worker_bins_sh.path}"
    working_directory = "${data.ignition_directory.bin_dir.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "worker_bins_env" {
  filesystem = "root"
  path       = "/etc/default/bins"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_bins_env.rendered}"
  }
}

data "ignition_file" "worker_bins_sh" {
  filesystem = "root"
  path       = "${data.ignition_directory.bin_dir.path}/bins.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${file("${path.module}/worker/scripts/bins.sh")}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_systemd_unit" "worker_bins_service" {
  name    = "bins.service"
  content = "${data.template_file.worker_bins_service.*.rendered[count.index]}"
}
