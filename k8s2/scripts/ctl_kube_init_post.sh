#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# The name of the server that runs this script.
service_name=kube-init-post.service

# Create the lock file used to hold the name of the lock.
lock_file=init_post.fifo
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

# If the lock was obtained then check to make sure that the init
# routine has not already been executed on some other node.
#
# If the lock could not be obtained then wait until the name
# of the node that is running the init routine appears at the
# specified key value, print the name of the node, and exit.
if read -r lock_name <"${lock_file}"; then
  echo "lock success: ${lock_name}"
  name_of_init_node=$(etcdctl get --print-value-only "${lock_key}")
  if [ -n "${name_of_init_node}" ]; then
    echo "${service_name} already run on ${name_of_init_node}"
    release_lock
    exit 0
  fi
else
  echo "lock failed"
  while [ -z "${name_of_init_node}" ]; do
    name_of_init_node=$(etcdctl get --print-value-only "${lock_key}")
    if [ -z "${name_of_init_node}" ]; then sleep 1; fi
  done
  echo "${service_name} is running on ${name_of_init_node}"
  release_lock
  exit 0
fi

# Print Kubernetes's version information
kubectl version

# Indicate that the init process has started.
etcdctl put "${lock_key}" "$(hostname)"

retry_until_0() {
    echo "${1}"
    shift
    until printf "." && "${@}" >/dev/null 2>&1; do sleep 1; done; echo "✓"
}

# Wait until the necessary components are available.
retry_until_0 "trying to connect to cluster with kubectl" kubectl get cs
retry_until_0 "ensure that the kube-system namespaces exists" kubectl get namespace kube-system
retry_until_0 "ensure that ClusterRoles are available" kubectl get ClusterRole.v1.rbac.authorization.k8s.io
retry_until_0 "ensure that ClusterRoleBindings are available" kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io

# Create the system:kube-apiserver-to-kubelet ClusterRole with 
# permissions to access the Kubelet API and perform most common tasks 
# associated with managing pods.
cat <<EOF | kubectl apply --kubeconfig "${KUBECONFIG}" -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

# Bind the system:kube-apiserver-to-kubelet ClusterRole to the 
# kubernetes user:
cat <<EOF | kubectl apply --kubeconfig "${KUBECONFIG}" -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: ${CLUSTER_ADMIN}
EOF

# Deploy coredns
kubectl create -f /var/lib/kubernetes/coredns-podspec.yaml

# Indicate the script has completed
release_lock
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
