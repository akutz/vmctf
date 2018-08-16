////////////////////////////////////////////////////////////////////////////////
//                             Users & Groups                                 //
////////////////////////////////////////////////////////////////////////////////
data "ignition_group" "master_nginx" {
  name = "nginx"
  gid  = "301"
}

data "ignition_user" "master_nginx" {
  name           = "nginx"
  uid            = "301"
  no_create_home = true
  no_user_group  = true
  system         = true
  primary_group  = "${data.ignition_group.master_nginx.gid}"

  groups = [
    "wheel",
    "docker",
  ]
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_nginx_root" {
  filesystem = "root"
  path       = "/var/lib/nginx"

  // mode = 0755
  mode = 493
  uid  = "${data.ignition_user.master_nginx.uid}"
}

data "ignition_file" "master_nginx_env" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "/etc/default/nginx"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_nginx_env.*.rendered[count.index]}"
  }
}

data "ignition_file" "master_nginx_conf" {
  count      = "${var.master_count}"
  filesystem = "root"
  path       = "/etc/nginx/nginx.conf"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_nginx_conf.*.rendered[count.index]}"
  }
}

locals {
  nginx_version = "${var.nginx_version}-alpine"
}

////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_nginx_service" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/systemd/nginx.service")}"

  vars {
    user              = "${data.ignition_user.master_nginx.name}"
    cmd_file          = "${data.ignition_directory.bin_dir.path}/nginx"
    env_file          = "${data.ignition_file.master_nginx_env.*.path[count.index]}"
    conf_file         = "${data.ignition_file.master_nginx_conf.*.path[count.index]}"
    working_directory = "${data.ignition_directory.master_nginx_root.path}"
    version           = "${local.nginx_version}"
  }
}

data "template_file" "master_nginx_env" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/nginx.env")}"

  vars {
    conf_file  = "${data.ignition_file.master_nginx_conf.*.path[count.index]}"
    version    = "${local.nginx_version}"
    tls_ca_crt = "${data.ignition_file.tls_ca_crt.path}"
  }
}

data "template_file" "master_nginx_conf" {
  count    = "${var.master_count}"
  template = "${file("${path.module}/master/etc/nginx.conf")}"

  vars {
    server_name            = "${local.cluster_name}"
    network_ipv4_address   = "${data.template_file.master_network_ipv4_address.*.rendered[count.index]}"
    master_api_secure_port = "${var.master_api_secure_port}"
    tls_ca_crt             = "${data.ignition_file.tls_ca_crt.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_systemd_unit" "master_nginx_service" {
  count   = "${var.master_count}"
  name    = "nginx.service"
  content = "${data.template_file.master_nginx_service.*.rendered[count.index]}"
}
