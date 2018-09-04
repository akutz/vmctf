#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# If there is a single argument then its an environment file to load.
if [ -n "${1}" ] && [ -e "${1}" ]; then
  echo "loading kcfg environment file ${1}"
  # shellcheck disable=SC1090
  { set -o allexport && . "${1}" && set +o allexport; } || exit "${?}"
  { cat "${1}" && echo; } || exit "${?}"
fi

eval_i() {
  k1="${1}"
  k2="${2:-$(echo "${k1}" | tr '[:lower:]' '[:upper:]')}"
  k3="${3:-${k2}}"

  # Parameter expansion is often implemented with ":-". The lack of
  # the colon below means k1 will be assigned an empty value if
  # k2_i is defined at all. This provides the ability to set an
  # empty value even when k3 is defined and non-empty.
  eval "${k1}=\${${k2}_${i}-\${${k3}}}"
}

# i is the index used to check for kubeconfig IDs, and is incremented
# at the end of the below while loop's iteration. When 
# KUBECONFIG_${i} is not set, the loop exits.
i=0

while true; do
  # Check for a kubeconfig ID. If one is not set then exit the loop.
  kfg_id=; eval "kfg_id=\$KFG_${i}"
  if [ -z "${kfg_id}" ]; then break; fi

  # Get the kubeconfig file path
  kfg_file_path=;
  eval_i kfg_file_path KFG_FILE_PATH kfg_id
  if [ "${kfg_file_path}" = "${kfg_id}" ]; then
    kfg_file_path="/var/lib/kubernetes/${kfg_id}.kubeconfig"
    [ -d /var/lib/kubernetes ] || mkdir /var/lib/kubernetes
  fi

  # If the kubeconfig already exists then do not regenerate it.
  [ -f "${kfg_file_path}" ] && continue

  # Get the TLS certificate and key with which to generate the kubeconfig.
  kfg_crt=; eval "kfg_crt=\$KFG_CRT_${i}"
  kfg_key=; eval "kfg_key=\$KFG_KEY_${i}"

  # If either the cert or key are missing then skip this kubeconfig.
  if [ -z "${kfg_crt}" ] || [ -z "${kfg_key}" ]; then
    echo "generate ${kfg_file_path} failed: missing crt and/or key"
    continue
  fi

  # Get the rest of the kubeconfig information.
  kfg_cluster=;      eval_i kfg_cluster
  kfg_ca_crt=;       eval_i kfg_ca_crt
  kfg_server=;       eval_i kfg_server
  kfg_user=;         eval_i kfg_user
  kfg_context=;      eval_i kfg_context
  kfg_uid=;          eval_i kfg_uid
  kfg_gid=;          eval_i kfg_gid
  kfg_perm=;         eval_i kfg_perm

  # Generate the kubeconfig.
  kubectl config set-cluster "${kfg_cluster}" \
    --certificate-authority="${kfg_ca_crt}" \
    --embed-certs=true \
    --server="${kfg_server}" \
    --kubeconfig="${kfg_file_path}"

  kubectl config set-credentials "${kfg_user}" \
    --client-certificate="${kfg_crt}" \
    --client-key="${kfg_key}" \
    --embed-certs=true \
    --kubeconfig="${kfg_file_path}"

  kubectl config set-context "${kfg_context}" \
    --cluster="${kfg_cluster}" \
    --user="${kfg_user}" \
    --kubeconfig="${kfg_file_path}"

  kubectl config use-context "${kfg_context}" \
    --kubeconfig="${kfg_file_path}"

  chown "${kfg_uid}"  "${kfg_file_path}"
  chgrp "${kfg_gid}"  "${kfg_file_path}"
  chmod "${kfg_perm}" "${kfg_file_path}"

  # Increment the index
  i=$((i+1))
done
