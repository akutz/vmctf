////////////////////////////////////////////////////////////////////////////////
//                                Ignition                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_config" "worker_config" {
  count = "${var.worker_count}"

  directories = [
    "${data.ignition_directory.tls_dir.id}",
  ]

  files = [
    "${data.ignition_file.path_sh.id}",
    "${data.ignition_file.sshd_config.id}",
    "${data.ignition_file.docker_env.id}",
    "${data.ignition_file.tls_ca_crt.id}",
    "${data.ignition_file.tls_ca_key.id}",
    "${data.ignition_file.worker_hostname.*.id[count.index]}",
    "${data.ignition_file.worker_bins_env.id}",
    "${data.ignition_file.worker_bins_sh.id}",
  ]

  networkd = [
    "${data.ignition_networkd_unit.worker_networkd_unit.*.id[count.index]}",
  ]

  systemd = [
    "${data.ignition_systemd_unit.docker_service_conf.id}",
    "${data.ignition_systemd_unit.worker_bins_service.id}",
  ]

  groups = [
    "${data.ignition_group.groups.*.id}",
  ]

  users = [
    "${data.ignition_user.users.*.id}",
  ]
}
