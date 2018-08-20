////////////////////////////////////////////////////////////////////////////////
//                                Ignition                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_config" "master_config" {
  count = "${var.master_count}"

  directories = [
    "${data.ignition_directory.tls_dir.id}",
    "${data.ignition_directory.kubernetes_root.id}",
    "${data.ignition_directory.master_nginx_root.id}",
    "${data.ignition_directory.master_nginx_log.id}",
    "${data.ignition_directory.master_coredns_root.id}",
    "${data.ignition_directory.master_etcd_root.id}",
    "${data.ignition_directory.master_kube_controller_manager_root.id}",
    "${data.ignition_directory.master_kube_scheduler_root.id}",
  ]

  files = [
    "${data.ignition_file.path_sh.id}",
    "${data.ignition_file.sshd_config.id}",
    "${data.ignition_file.docker_env.id}",
    "${data.ignition_file.tls_ca_crt.id}",
    "${data.ignition_file.tls_ca_key.id}",
    "${data.ignition_file.vsphere_cloud_provider_conf.id}",
    "${data.ignition_file.k8s_service_accounts_tls_crt.id}",
    "${data.ignition_file.k8s_service_accounts_tls_key.id}",
    "${data.ignition_file.master_nginx_conf.id}",
    "${data.ignition_file.master_hostname.*.id[count.index]}",
    "${data.ignition_file.master_bins_env.id}",
    "${data.ignition_file.master_coredns_init_env.*.id[count.index]}",
    "${data.ignition_file.master_coredns_corefile.*.id[count.index]}",
    "${data.ignition_file.master_coredns_init_sh.id}",
    "${data.ignition_file.master_bins_sh.id}",
    "${data.ignition_file.master_etcd_env.*.id[count.index]}",
    "${data.ignition_file.master_etcd_tls_client_crt.*.id[count.index]}",
    "${data.ignition_file.master_etcd_tls_client_key.*.id[count.index]}",
    "${data.ignition_file.master_etcd_tls_peer_crt.*.id[count.index]}",
    "${data.ignition_file.master_etcd_tls_peer_key.*.id[count.index]}",
    "${data.ignition_file.master_etcdctl_sh.*.id[count.index]}",
    "${data.ignition_file.master_etcdctl_tls_crt.*.id[count.index]}",
    "${data.ignition_file.master_etcdctl_tls_key.*.id[count.index]}",
    "${data.ignition_file.master_coredns_tls_crt.*.id[count.index]}",
    "${data.ignition_file.master_coredns_tls_key.*.id[count.index]}",
    "${data.ignition_file.master_kube_apiserver_env.*.id[count.index]}",
    "${data.ignition_file.master_kube_controller_manager_env.id}",
    "${data.ignition_file.master_kube_controller_manager_kubeconfig.id}",
    "${data.ignition_file.master_kube_scheduler_config.id}",
    "${data.ignition_file.master_kube_scheduler_env.id}",
    "${data.ignition_file.master_kube_scheduler_kubeconfig.id}",
    "${data.ignition_file.master_kube_encryption_config.id}",
    "${data.ignition_file.master_kube_init_sh.id}",
    "${data.ignition_file.master_kube_init_env.id}",
    "${data.ignition_file.master_kubeconfig.id}",
    "${data.ignition_file.master_kube_apiserver_tls_crt.id}",
    "${data.ignition_file.master_kube_apiserver_tls_key.id}",
  ]

  networkd = [
    "${data.ignition_networkd_unit.master_networkd_unit.*.id[count.index]}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.docker_service_conf.id}",
    "${data.ignition_systemd_unit.master_nginx_service.id}",
    "${data.ignition_systemd_unit.master_bins_service.id}",
    "${data.ignition_systemd_unit.master_etcd_service.*.id[count.index]}",
    "${data.ignition_systemd_unit.master_coredns_init_service.*.id[count.index]}",
    "${data.ignition_systemd_unit.master_coredns_service.*.id[count.index]}",
    "${data.ignition_systemd_unit.master_kube_apiserver_service.*.id[count.index]}",
    "${data.ignition_systemd_unit.master_kube_controller_manager_service.id}",
    "${data.ignition_systemd_unit.master_kube_scheduler_service.id}",
    "${data.ignition_systemd_unit.master_kube_init_service.id}",
  ]

  groups = [
    "${data.ignition_group.groups.*.id}",
    "${data.ignition_group.master_coredns.id}",
    "${data.ignition_group.master_nginx.id}",
  ]

  users = [
    "${data.ignition_user.users.*.id}",
    "${data.ignition_user.master_coredns.id}",
    "${data.ignition_user.master_nginx.id}",
  ]
}
