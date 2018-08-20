////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "template_file" "master_kube_init_env" {
  template = "${file("${path.module}/master/etc/kube_init.env")}"

  vars {
    bin_dir        = "${data.ignition_directory.bin_dir.path}"
    etcd_endpoints = "https://127.0.0.1:2379"
    tls_crt        = "${data.ignition_file.master_kube_apiserver_tls_crt.path}"
    tls_key        = "${data.ignition_file.master_kube_apiserver_tls_key.path}"
    tls_ca         = "${data.ignition_file.tls_ca_crt.path}"
    kubeconfig     = "${data.ignition_file.master_kubeconfig.path}"
  }
}

data "ignition_file" "master_kube_init_env" {
  filesystem = "root"
  path       = "/etc/default/kube-init"

  // mode = 0644
  mode = 420

  content {
    content = "${data.template_file.master_kube_init_env.rendered}"
  }
}


data "ignition_file" "master_kube_init_sh" {
  filesystem = "root"
  path       = "${data.ignition_directory.bin_dir.path}/kube_init.sh"

  // mode = 0755
  mode = 493

  content {
    content = "${file("${path.module}/master/scripts/kube_init.sh")}"
  }
}


data "template_file" "master_kube_init_service" {
  template = "${file("${path.module}/master/systemd/kube_init.service")}"

  vars {
    unit_name         = "kube-init.service"
    env_file          = "${data.ignition_file.master_kube_init_env.path}"
    cmd_file          = "${data.ignition_file.master_kube_init_sh.path}"
    working_directory = "${data.ignition_directory.bin_dir.path}"
  }
}

data "ignition_systemd_unit" "master_kube_init_service" {
  name    = "kube-init.service"
  content = "${data.template_file.master_kube_init_service.rendered}"
}
