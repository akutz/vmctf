////////////////////////////////////////////////////////////////////////////////
//                                Ignition                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_config" "config" {
  count = "${var.count}"

  directories = [
    "${data.ignition_directory.tls_dir.id}",
    "${data.ignition_directory.coredns_root.id}",
    "${data.ignition_directory.etcd_root.id}",
  ]

  files = [
    "${data.ignition_file.path_sh.id}",
    "${data.ignition_file.sshd_config.id}",
    "${data.ignition_file.docker_env.id}",
    "${data.ignition_file.tls_ca_crt.id}",
    "${data.ignition_file.tls_ca_key.id}",
    "${data.ignition_file.hostname.*.id[count.index]}",
    "${data.ignition_file.bins_env.id}",
    "${data.ignition_file.coredns_init_env.*.id[count.index]}",
    "${data.ignition_file.coredns_corefile.*.id[count.index]}",
    "${data.ignition_file.coredns_init_sh.id}",
    "${data.ignition_file.bins_sh.id}",
    "${data.ignition_file.etcd_env.*.id[count.index]}",
    "${data.ignition_file.etcd_tls_client_crt.*.id[count.index]}",
    "${data.ignition_file.etcd_tls_client_key.*.id[count.index]}",
    "${data.ignition_file.etcd_tls_peer_crt.*.id[count.index]}",
    "${data.ignition_file.etcd_tls_peer_key.*.id[count.index]}",
    "${data.ignition_file.etcdctl_sh.*.id[count.index]}",
    "${data.ignition_file.etcdctl_tls_crt.*.id[count.index]}",
    "${data.ignition_file.etcdctl_tls_key.*.id[count.index]}",
    "${data.ignition_file.coredns_tls_crt.*.id[count.index]}",
    "${data.ignition_file.coredns_tls_key.*.id[count.index]}",
  ]

  networkd = [
    "${data.ignition_networkd_unit.networkd_unit.*.id[count.index]}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.docker_service_conf.id}",
    "${data.ignition_systemd_unit.bins_service.id}",
    "${data.ignition_systemd_unit.dns_online_target.id}",
    "${data.ignition_systemd_unit.etcd_service.*.id[count.index]}",
    "${data.ignition_systemd_unit.coredns_init_service.*.id[count.index]}",
    "${data.ignition_systemd_unit.coredns_service.*.id[count.index]}",
  ]

  groups = [
    "${data.ignition_group.groups.*.id}",
    "${data.ignition_group.coredns.id}",
  ]

  users = [
    "${data.ignition_user.users.*.id}",
    "${data.ignition_user.coredns.id}",
  ]
}
