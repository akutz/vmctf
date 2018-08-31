#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# The name of the server that runs this script.
service_name=kube-init-pre.service

# The key prefix for controller node files.
ctl_files_prefix_key="${service_name}.controller.files"

# The keys for the controller node cert/key pairs.
ctl_tls_prefix_key="${ctl_files_prefix_key}.tls"
ctl_tls_apiserver_crt_key="${ctl_tls_prefix_key}.kube-apiserver.crt"
ctl_tls_apiserver_key_key="${ctl_tls_prefix_key}.kube-apiserver.key"
ctl_tls_svc_accts_crt_key="${ctl_tls_prefix_key}.service-accounts.crt"
ctl_tls_svc_accts_key_key="${ctl_tls_prefix_key}.service-accounts.key"

# The keys for the kubeconfigs.
ctl_kfg_prefix_key="${ctl_files_prefix_key}.kfg"
ctl_kfg_admin_key="${ctl_kfg_prefix_key}.k8s-admin"
ctl_kfg_controller_manager_key="${ctl_kfg_prefix_key}.kube-controller-manager"
ctl_kfg_scheduler_key="${ctl_kfg_prefix_key}.kube-scheduler"

# The key for the number of controller nodes that have fetched the data.
num_key="${service_name}.controller.num"

# Create the lock file used to hold the name of the lock.
lock_file=init_pre.fifo
if ! mkfifo "${lock_file}"; then exit "$?"; fi

# Obtain a lock.
lock_key=${service_name}
echo "writing ${lock_key} to ${lock_file}"
etcdctl lock "${lock_key}" >"${lock_file}" &
lock_pid="$!"

release_lock() {
  kill "${lock_pid}"
  wait "${lock_pid}" || true
  rm -f "${lock_file}"
}

# Wait until the lock has been obtained to continue.
if ! read -r lock_name <"${lock_file}"; then
  exit_code="${?}"
  echo "lock failed: ${lock_name}"
  exit "${exit_code}"
fi

echo "lock success: ${lock_name}"

fetch_tls() {
  etcdctl get --print-value-only "${1}" > "${3}"
  etcdctl get --print-value-only "${2}" > "${4}"
  chmod 0444 "${3}" && chmod 0400 "${4}"
  chown root:root "${3}" "${4}"
}

fetch_kubeconfig() {
  etcdctl get --print-value-only "${1}" > "${2}"
  chmod 0400 "${2}" && chown root:root "${2}"
}

# Check to see if the init routine has already run on another node.
name_of_init_node=$(etcdctl get --print-value-only "${lock_key}")
if [ -n "${name_of_init_node}" ]; then
  echo "${service_name} already run on ${name_of_init_node}"

  # Fetch the kube-apiserver cert/key pair.
  fetch_tls "${ctl_tls_apiserver_crt_key}" \
            "${ctl_tls_apiserver_key_key}" \
            /etc/ssl/kube-apiserver.crt \
            /etc/ssl/kube-apiserver.key

  # Fetch the service-accounts cert/key pair.
  fetch_tls "${ctl_tls_svc_accts_crt_key}" \
            "${ctl_tls_svc_accts_key_key}" \
            /etc/ssl/k8s-service-accounts.crt \
            /etc/ssl/k8s-service-accounts.key

  # Fetch the k8s-admin kubeconfig.
  fetch_kubeconfig "${ctl_kfg_admin_key}" \
                   /var/lib/kubernetes/kubeconfig

  # Grant access to the admin kubeconfig to users belonging to the
  # "k8s-admin" group.
  chmod 0440 /var/lib/kubernetes/kubeconfig
  chown root:k8s-admin /var/lib/kubernetes/kubeconfig

  # Fetch the kube-controller-manager kubeconfig.
  fetch_kubeconfig "${ctl_kfg_controller_manager_key}" \
                   /var/lib/kube-controller-manager/kubeconfig
  
  # Fetch the kube-scheduler kubeconfig.
  fetch_kubeconfig "${ctl_kfg_scheduler_key}" \
                   /var/lib/kube-scheduler/kubeconfig

  # Increment the number of nodes that have fetched the cert/key pair.
  num_val=$(etcdctl get --print-value-only "${num_key}")

  # If the number of nodes that have fetched the files is
  # one less than the total, expected number, then this is the last
  # node that needs to fetch the files. In this case delete the keys
  # from the etcd server.
  #
  # Otherwise increment the number of nodes that have fetched the
  # files by one and store the value on the etcd server.
  if [ "${num_val}" -eq "$((ETCD_MEMBER_COUNT-1))" ]; then
    etcdctl del --prefix "${ctl_files_prefix_key}"
  else
    etcdctl put "${num_key}" "$((num_val+1))"
  fi

  release_lock
  exit 0
fi

# At this point the lock has been obtained and it's known that no other
# node has run the initialization routine.

# Indicate that the init process is running on this node.
etcdctl put "${lock_key}" "$(hostname)"

# Generate the TLS cert/key pairs.
/opt/bin/gencerts.sh

# Generate the kubeconfigs.
/opt/bin/genkcfgs.sh

# Remove the certificates that are no longer needed once the kubeconfigs
# have been generated.
rm -f /etc/ssl/k8s_admin.*
rm -f /etc/ssl/kube_controller_manager.*
rm -f /etc/ssl/kube_scheduler.*

# Store the cert/key pairs on the etcd server.
etcdctl put "${ctl_tls_apiserver_crt_key}" -- </etc/ssl/kube-apiserver.crt
etcdctl put "${ctl_tls_apiserver_key_key}" -- </etc/ssl/kube-apiserver.key
etcdctl put "${ctl_tls_svc_accts_crt_key}" -- </etc/ssl/k8s-service-accounts.crt
etcdctl put "${ctl_tls_svc_accts_key_key}" -- </etc/ssl/k8s-service-accounts.key

# Store the kubeconfigs on the etcd server.
etcdctl put "${ctl_kfg_admin_key}" -- \
            </var/lib/kubernetes/kubeconfig
etcdctl put "${ctl_kfg_controller_manager_key}" -- \
            </var/lib/kube-controller-manager/kubeconfig
etcdctl put "${ctl_kfg_scheduler_key}" -- \
            </var/lib/kube-scheduler/kubeconfig

# Set the number of nodes that have fetched the cert/key pair.
etcdctl put "${num_key}" 1

# Indicate the script has completed
release_lock
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
