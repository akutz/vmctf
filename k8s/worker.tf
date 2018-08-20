////////////////////////////////////////////////////////////////////////////////
//                                Ignition                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_config" "worker_config" {
  count = "${var.worker_count}"

  directories = [
    "${data.ignition_directory.tls_dir.id}",
    "${data.ignition_directory.kubernetes_root.id}",
  ]

  files = [
    "${data.ignition_file.path_sh.id}",
    "${data.ignition_file.sshd_config.id}",
    "${data.ignition_file.docker_env.id}",
    "${data.ignition_file.tls_ca_crt.id}",
    "${data.ignition_file.tls_ca_key.id}",
    "${data.ignition_file.vsphere_cloud_provider_conf.id}",
    "${data.ignition_file.worker_containerd_config.id}",
    "${data.ignition_file.worker_kube_proxy_config.id}",
    "${data.ignition_file.worker_kube_proxy_env.id}",
    "${data.ignition_file.worker_kube_proxy_kubeconfig.id}",
    "${data.ignition_file.worker_bins_env.id}",
    "${data.ignition_file.worker_bins_sh.id}",
    "${data.ignition_file.worker_hostname.*.id[count.index]}",
    "${data.ignition_file.worker_cni_netd_10_bridge_conf.*.id[count.index]}",
    "${data.ignition_file.worker_cni_netd_99_loopback_conf.*.id[count.index]}",
    "${data.ignition_file.worker_kubelet_config.*.id[count.index]}",
    "${data.ignition_file.worker_kubelet_kubeconfig.*.id[count.index]}",
    "${data.ignition_file.worker_kubelet_env.*.id[count.index]}",
    "${data.ignition_file.worker_kubelet_tls_crt.*.id[count.index]}",
    "${data.ignition_file.worker_kubelet_tls_key.*.id[count.index]}",
  ]

  networkd = [
    "${data.ignition_networkd_unit.worker_networkd_unit.*.id[count.index]}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.docker_service_conf.id}",
    "${data.ignition_systemd_unit.worker_bins_service.id}",
    "${data.ignition_systemd_unit.worker_containerd_service.id}",
    "${data.ignition_systemd_unit.worker_kube_proxy_service.id}",
    "${data.ignition_systemd_unit.worker_kubelet_service.*.id[count.index]}",
  ]

  groups = [
    "${data.ignition_group.groups.*.id}",
  ]

  users = [
    "${data.ignition_user.users.*.id}",
  ]
}
