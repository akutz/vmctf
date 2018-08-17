////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "bins_env" {
  template = "${file("${path.module}/etc/bins.env")}"

  vars {
    bin_dir         = "${data.ignition_directory.bin_dir.path}"
    etcd_version    = "${var.etcd_version}"
    coredns_version = "${var.coredns_version}"
  }
}

data "template_file" "bins_service" {
  template = "${file("${path.module}/systemd/bins.service")}"

  vars {
    unit_name         = "bins.service"
    env_file          = "${data.ignition_file.bins_env.path}"
    cmd_file          = "${data.ignition_file.bins_sh.path}"
    working_directory = "${data.ignition_directory.bin_dir.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "bins_env" {
  filesystem = "root"
  path       = "/etc/default/bins"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.bins_env.rendered}"
  }
}

data "ignition_file" "bins_sh" {
  filesystem = "root"
  path       = "${data.ignition_directory.bin_dir.path}/bins.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${file("${path.module}/scripts/bins.sh")}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_systemd_unit" "bins_service" {
  name    = "bins.service"
  content = "${data.template_file.bins_service.*.rendered[count.index]}"
}
