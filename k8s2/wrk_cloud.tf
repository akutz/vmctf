data "template_file" "wrk_cloud_network" {
  count = "${var.wrk_count}"

  template = <<EOF
version: 1
config:
  - type: physical
    name: $${network_device}
    subnets:
      - type: dhcp
  - type: nameserver:
    address:
      - 8.8.8.8
      - 8.8.4.4
    search: $${network_search_domains}
EOF

  vars {
    network_device         = "${var.network_device}"
    network_search_domains = "${join("", formatlist("\n% 7s %s", "-", split(" ", var.network_search_domains)))}"
  }
}

data "template_file" "wrk_cloud_metadata" {
  count = "${var.wrk_count}"

  template = <<EOF
{
  "network": "$${network}",
  "network.encoding": "gzip+base64",
  "local-hostname": "$${local_hostname}",
  "instance-id": "$${instance_id}"
}
EOF

  vars {
    network        = "${base64gzip(data.template_file.wrk_cloud_network.*.rendered[count.index])}"
    local_hostname = "${data.template_file.wrk_network_hostfqdn.*.rendered[count.index]}"
    instance_id    = "${data.template_file.wrk_network_hostfqdn.*.rendered[count.index]}"
  }
}

data "template_file" "wrk_cloud_config" {
  count = "${var.wrk_count}"

  template = "${file("${path.module}/wrk_cloud.yaml")}"

  vars {
    debug = "${var.debug}"

    //
    users = "${join("\n", data.template_file.cloud_users.*.rendered)}"

    //
    iptables = "${base64gzip(local.wrk_iptables)}"

    //
    network_manager_dns_disabled = "${base64gzip(local.network_manager_dns_disabled)}"

    //
    cloud_provider_config = "${base64gzip(data.template_file.cloud_provider_config.rendered)}"

    //
    path_sh   = "${base64gzip(local.path_sh)}"
    prompt_sh = "${base64gzip(local.prompt_sh)}"

    //
    defaults_sh      = "${base64gzip(file("${path.module}/scripts/defaults.sh"))}"
    defaults_service = "${base64gzip(data.template_file.defaults_service.rendered)}"

    //
    bins_env     = "${base64gzip(data.template_file.wrk_bins_env.rendered)}"
    bins_sh      = "${base64gzip(file("${path.module}/scripts/wrk_bins.sh"))}"
    bins_service = "${base64gzip(local.bins_service)}"

    //
    control_plane_online_sh      = "${base64gzip(file("${path.module}/scripts/wrk_control_plane_online.sh"))}"
    control_plane_online_env     = "${base64gzip(data.template_file.wrk_control_plane_online_env.rendered)}"
    control_plane_online_service = "${base64gzip(local.wrk_control_plane_online_service)}"

    //
    newcert_sh   = "${base64gzip(file("${path.module}/scripts/newcert.sh"))}"
    gencerts_sh  = "${base64gzip(file("${path.module}/scripts/gencerts.sh"))}"
    gencerts_env = "${base64gzip(data.template_file.gencerts_env.rendered)}"

    //
    genkcfgs_sh  = "${base64gzip(file("${path.module}/scripts/genkcfgs.sh"))}"
    genkcfgs_env = "${base64gzip(data.template_file.wrk_genkcfgs_env.rendered)}"

    //
    tls_ca_crt = "${base64gzip(local.tls_ca_crt)}"
    tls_ca_key = "${base64gzip(local.tls_ca_key)}"

    //
    cni_bridge_config   = "${base64gzip(data.template_file.wrk_cni_bridge_config.*.rendered[count.index])}"
    cni_loopback_config = "${base64gzip(local.wrk_cni_loopback_config)}"
    containerd_config   = "${base64gzip(local.wrk_containerd_config)}"
    containerd_service  = "${base64gzip(local.wrk_containerd_service)}"

    //
    kube_init_pre_env     = "${base64gzip(local.wkr_kube_init_pre_env)}"
    kube_init_pre_service = "${base64gzip(local.wrk_kube_init_pre_service)}"

    //
    kubelet_config  = "${base64gzip(data.template_file.wrk_kubelet_config.*.rendered[count.index])}"
    kubelet_env     = "${base64gzip(data.template_file.wrk_kubelet_env.rendered)}"
    kubelet_service = "${base64gzip(local.wrk_kubelet_service)}"

    //
    kube_proxy_config  = "${base64gzip(data.template_file.wrk_kube_proxy_config.rendered)}"
    kube_proxy_env     = "${base64gzip(local.wrk_kube_proxy_env)}"
    kube_proxy_service = "${base64gzip(local.wrk_kube_proxy_service)}"
  }
}
