////////////////////////////////////////////////////////////////////////////////
//                             Users & Groups                                 //
////////////////////////////////////////////////////////////////////////////////
locals {
  os_users_keys          = ["${keys(var.os_users)}"]
  os_users_count         = "${length(local.os_users_keys)}"
  os_ssh_authorized_keys = ["${values(var.os_users)}"]
}

data "ignition_group" "groups" {
  count = "${local.os_users_count}"
  name  = "${element(local.os_users_keys, count.index)}"
  gid   = "${var.os_seed_gid + count.index}"
}

data "ignition_user" "users" {
  count         = "${local.os_users_count}"
  name          = "${element(local.os_users_keys, count.index)}"
  uid           = "${var.os_seed_uid + count.index}"
  no_user_group = "true"
  primary_group = "${element(local.os_users_keys, count.index)}"

  groups = [
    "wheel",
    "sudo",
  ]

  ssh_authorized_keys = [
    "${var.os_users[element(local.os_users_keys, count.index)]}",
  ]
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "bin_dir" {
  filesystem = "root"
  path       = "/opt/bin"

  // mode = 0755
  mode = 493
}

////////////////////////////////////////////////////////////////////////////////
//                                 Path                                       //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "path_sh" {
  template = "${file("${path.module}/etc/path.sh")}"

  vars {
    bin_dir = "${data.ignition_directory.bin_dir.path}"
  }
}

data "ignition_file" "path_sh" {
  filesystem = "root"
  path       = "/etc/profile.d/path.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${data.template_file.path_sh.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                  SSH                                       //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "sshd_config" {
  template = "${file("${path.module}/etc/sshd_config")}"

  vars {
    allow_users = "${join(" ", local.os_users_keys)}"
  }
}

data "ignition_file" "sshd_config" {
  filesystem = "root"
  path       = "/etc/ssh/sshd_config"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.sshd_config.rendered}"
  }
}
