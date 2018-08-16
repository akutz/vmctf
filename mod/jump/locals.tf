locals {
  os_users_keys          = ["${keys(var.os_users)}"]
  os_users_count         = "${length(local.os_users_keys)}"
  os_ssh_authorized_keys = ["${values(var.os_users)}"]
}
