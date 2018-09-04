data "template_file" "ctl_cloud_network" {
  count = "${var.ctl_count}"

  template = <<EOF
version: 1
config:
  - type: physical
    name: $${network_device}
    subnets:
      - type: dhcp
  - type: nameserver:
    address: $${network_dns}
    search: $${network_search_domains}
EOF

  vars {
    network_device         = "${var.network_device}"
    network_dns            = "${join("", formatlist("\n% 7s %s", "-", list(var.network_dns_1, var.network_dns_2)))}"
    network_search_domains = "${join("", formatlist("\n% 7s %s", "-", split(" ", var.network_search_domains)))}"
  }
}

data "template_file" "ctl_cloud_metadata" {
  count = "${var.ctl_count}"

  template = <<EOF
{
  "network": "$${network}",
  "network.encoding": "gzip+base64",
  "local-hostname": "$${local_hostname}",
  "instance-id": "$${instance_id}"
}
EOF

  vars {
    network        = "${base64gzip(data.template_file.ctl_cloud_network.*.rendered[count.index])}"
    local_hostname = "${data.template_file.ctl_network_hostfqdn.*.rendered[count.index]}"
    instance_id    = "${data.template_file.ctl_network_hostfqdn.*.rendered[count.index]}"
  }
}

data "template_file" "ctl_cloud_config" {
  count = "${var.ctl_count}"

  template = "${file("${path.module}/ctl_cloud.yaml")}"

  vars {
    debug = "${var.debug}"

    //
    users = "${join("\n", data.template_file.cloud_users.*.rendered)}"

    //
    controller_first_boot_sh = "${base64gzip(file("${path.module}/scripts/controller-first-boot.sh"))}"

    //
    defaults_env = "${base64gzip(data.template_file.defaults_env.rendered)}"

    //
    iptables = "${base64gzip(local.ctl_iptables)}"

    //
    network_manager_dns_disabled = "${base64gzip(local.network_manager_dns_disabled)}"

    //
    cloud_provider_config = "${base64gzip(data.template_file.cloud_provider_config.rendered)}"

    //
    kubeconfig_sh = "${base64gzip(local.kubeconfig_sh)}"

    //
    path_sh   = "${base64gzip(local.path_sh)}"
    prompt_sh = "${base64gzip(local.prompt_sh)}"

    //
    defaults_sh      = "${base64gzip(file("${path.module}/scripts/defaults.sh"))}"
    defaults_service = "${base64gzip(data.template_file.defaults_service.rendered)}"

    //
    bins_env     = "${base64gzip(data.template_file.ctl_bins_env.rendered)}"
    bins_sh      = "${base64gzip(file("${path.module}/scripts/ctl_bins.sh"))}"
    bins_service = "${base64gzip(local.bins_service)}"

    //
    newcert_sh   = "${base64gzip(file("${path.module}/scripts/newcert.sh"))}"
    gencerts_sh  = "${base64gzip(file("${path.module}/scripts/gencerts.sh"))}"
    gencerts_env = "${base64gzip(data.template_file.gencerts_env.rendered)}"

    //
    genkcfgs_sh  = "${base64gzip(file("${path.module}/scripts/genkcfgs.sh"))}"
    genkcfgs_env = "${base64gzip(data.template_file.ctl_genkcfgs_env.rendered)}"

    //
    tls_ca_crt = "${base64gzip(local.tls_ca_crt)}"
    tls_ca_key = "${base64gzip(local.tls_ca_key)}"

    //
    etcd_init_pre_env      = "${base64gzip(data.template_file.ctl_etcd_init_pre_env.rendered)}"
    etcd_init_pre_service  = "${base64gzip(local.ctl_etcd_init_pre_service)}"
    etcd_init_post_env     = "${base64gzip(data.template_file.ctl_etcd_init_post_env.rendered)}"
    etcd_init_post_sh      = "${base64gzip(file("${path.module}/scripts/ctl_etcd_init_post.sh"))}"
    etcd_init_post_service = "${base64gzip(local.ctl_etcd_init_post_service)}"
    etcd_env               = "${base64gzip(data.template_file.ctl_etcd_env.*.rendered[count.index])}"
    etcd_service           = "${base64gzip(local.ctl_etcd_service)}"
    etcdctl_sh             = "${base64gzip(local.ctl_etcdctl_sh)}"
    etcdctl_env            = "${base64gzip(local.ctl_etcdctl_env)}"

    //
    coredns_init_sh      = "${base64gzip(file("${path.module}/scripts/ctl_coredns_init.sh"))}"
    coredns_init_env     = "${base64gzip(data.template_file.ctl_coredns_init_env.rendered)}"
    coredns_init_service = "${base64gzip(local.ctl_coredns_init_service)}"
    coredns_service      = "${base64gzip(local.ctl_coredns_service)}"
    coredns_corefile     = "${base64gzip(data.template_file.ctl_coredns_corefile.rendered)}"

    //
    kube_dns_podspec = "${base64gzip(data.template_file.kube_dns_podspec.rendered)}"

    //
    nginx_conf    = "${base64gzip(data.template_file.ctl_nginx_conf.rendered)}"
    nginx_service = "${base64gzip(local.ctl_nginx_service)}"

    //
    handle_worker_signals_sh      = "${base64gzip(file("${path.module}/scripts/ctl_handle_worker_signals.sh"))}"
    handle_worker_signals_env     = "${base64gzip(data.template_file.ctl_handle_worker_signals_env.rendered)}"
    handle_worker_signals_service = "${base64gzip(local.ctl_handle_worker_signals_service)}"

    //
    kube_init_pre_sh      = "${base64gzip(file("${path.module}/scripts/ctl_kube_init_pre.sh"))}"
    kube_init_pre_env     = "${base64gzip(data.template_file.ctl_kube_init_pre_env.rendered)}"
    kube_init_pre_service = "${base64gzip(local.ctl_kube_init_pre_service)}"

    //
    kube_init_post_sh      = "${base64gzip(file("${path.module}/scripts/ctl_kube_init_post.sh"))}"
    kube_init_post_env     = "${base64gzip(data.template_file.ctl_kube_init_post_env.rendered)}"
    kube_init_post_service = "${base64gzip(local.ctl_kube_init_post_service)}"

    //
    k8s_encryption_config = "${base64gzip(data.template_file.ctl_k8s_encryption_config.rendered)}"

    //
    kube_apiserver_env     = "${base64gzip(data.template_file.ctl_kube_apiserver_env.rendered)}"
    kube_apiserver_service = "${base64gzip(local.ctl_kube_apiserver_service)}"

    //
    kube_controller_manager_env     = "${base64gzip(data.template_file.ctl_kube_controller_manager_env.rendered)}"
    kube_controller_manager_service = "${base64gzip(local.ctl_kube_controller_manager_service)}"

    //
    kube_scheduler_env     = "${base64gzip(local.ctl_kube_scheduler_env)}"
    kube_scheduler_config  = "${base64gzip(local.ctl_kube_scheduler_config)}"
    kube_scheduler_service = "${base64gzip(local.ctl_kube_scheduler_service)}"
  }
}
