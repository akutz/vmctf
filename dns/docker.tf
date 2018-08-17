////////////////////////////////////////////////////////////////////////////////
//                               Filesystem                                   //
////////////////////////////////////////////////////////////////////////////////
data "ignition_file" "docker_env" {
  filesystem = "root"
  path       = "/etc/default/docker"

  // mode = 0644
  mode = 420

  content {
    content = "${file("${path.module}/etc/docker.env")}"
  }
}

////////////////////////////////////////////////////////////////////////////////
//                                 SystemD                                    //
////////////////////////////////////////////////////////////////////////////////
data "ignition_systemd_unit" "docker_service_conf" {
  name    = "docker.service"
  enabled = true

  dropin = [
    {
      name    = "docker.conf"
      content = "[Service]\nEnvironmentFile=${data.ignition_file.docker_env.path}"
    },
  ]
}