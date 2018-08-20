////////////////////////////////////////////////////////////////////////////////
//                             Users & Groups                                 //
////////////////////////////////////////////////////////////////////////////////
data "ignition_group" "master_nginx" {
  name = "nginx"
  gid  = "300"
}

data "ignition_user" "master_nginx" {
  name           = "nginx"
  uid            = "300"
  home_dir       = "/var/lib/nginx"
  no_create_home = true
  no_user_group  = true
  system         = true
  primary_group  = "${data.ignition_group.master_nginx.gid}"
}

////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_directory" "master_nginx_root" {
  filesystem = "root"
  path       = "${data.ignition_user.master_nginx.home_dir}"

  // mode = 0755
  mode = 493
  uid  = "${data.ignition_user.master_nginx.uid}"
}

data "ignition_directory" "master_nginx_log" {
  filesystem = "root"
  path       = "/var/log/nginx"

  // mode = 0755
  mode = 493
}

data "ignition_file" "master_nginx_conf" {
  filesystem = "root"
  path       = "/etc/nginx/nginx.conf"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_nginx_conf.rendered}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                               Templates                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_nginx_service" {
  template = "${file("${path.module}/master/systemd/nginx.service")}"

  vars {
    cmd_file          = "${data.ignition_directory.bin_dir.path}/nginx"
    pid_file          = "/var/run/nginx.pid"
    conf_file         = "${data.ignition_file.master_nginx_conf.path}"
    working_directory = "${data.ignition_directory.master_nginx_root.path}"
  }
}

data "template_file" "master_nginx_conf" {
  template = "${file("${path.module}/master/etc/nginx.conf")}"

  vars {
    user                   = "nginx"
    pid_file               = "/var/run/nginx.pid"
    server_name            = "${local.cluster_fqdn}"
    master_api_secure_port = "${var.master_api_secure_port}"
    tls_ca_crt             = "${data.ignition_file.tls_ca_crt.path}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_systemd_unit" "master_nginx_service" {
  name    = "nginx.service"
  content = "${data.template_file.master_nginx_service.rendered}"
}
