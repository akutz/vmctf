////////////////////////////////////////////////////////////////////////////////
//                               ContainerD                                   //
////////////////////////////////////////////////////////////////////////////////
locals {
  worker_containerd_sock_file = "unix:///var/run/containerd/containerd.sock"
}

data "ignition_directory" "worker_containerd_etc_dir" {
  filesystem = "root"
  path       = "/etc/containerd"

  // mode = 0755
  mode = 493
}

data "ignition_directory" "worker_runsc_root_dir" {
  filesystem = "root"
  path       = "/var/run/containerd/runsc"

  // mode = 0755
  mode = 493
}

data "template_file" "worker_containerd_config" {
  template = "${file("${path.module}/worker/etc/containerd.conf.toml")}"

  vars {
    bin_dir        = "${data.ignition_directory.bin_dir.path}"
    runsc_root_dir = "${data.ignition_directory.worker_runsc_root_dir.path}"
  }
}

data "ignition_file" "worker_containerd_config" {
  filesystem = "root"
  path       = "${data.ignition_directory.worker_containerd_etc_dir.path}/config.toml"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.worker_containerd_config.rendered}"
  }
}

data "template_file" "worker_containerd_service" {
  template = "${file("${path.module}/worker/systemd/containerd.service")}"

  vars {
    cmd_file = "${data.ignition_directory.bin_dir.path}/containerd"
  }
}

data "ignition_systemd_unit" "worker_containerd_service" {
  name    = "containerd.service"
  content = "${data.template_file.worker_containerd_service.rendered}"
}
