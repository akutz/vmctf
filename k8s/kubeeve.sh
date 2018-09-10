#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

#
# Turns up a Kubernetes cluster. Supports single-node, single-master,
# and multi-master deployments.
#
# usage: kubeeve.sh
#        kubeeve.sh NODE_TYPE ETCD_DISCOVERY NUM_CONTROLLERS NUM_NODES
#
#   SINGLE NODE CLUSTER
#     To deploy a single node cluster execute "kubeeve.sh" with no arguments.
#
#   MULTI NODE CLUSTER
#     To deploy a multi-node cluster execute "kubeeve.sh" with the following
#     arguments on each controller and worker node in the cluster.
#
#       NODE_TYPE        May be set to "controller", "worker", or "both".
#       ETCD_DISCOVERY   The etcd discovery URL returned by a call to
#                        https://discovery.etcd.io/new?size=NUM_CONTROLLERS.
#       NUM_CONTROLLERS  The total number of controller nodes.
#       NUM_NODES        The total number of nodes. Defaults to
#                        NUM_CONTROLLERS.
#

set -o pipefail

# Parses the argument and normalizes a truthy value to lower-case "true".
parse_bool() {
  { echo "${1}" | grep -oiq 'true\|yes\|1' && echo 'true'; } || echo 'false'
}

# Normalize the possible truthy value of DEBUG to lower-case "true".
DEBUG=$(parse_bool "${DEBUG}")
is_debug() { [ "${DEBUG}" = "true" ]; }

# Debug mode enables tracing.
is_debug && set -x && echo "tracing enabled"

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -qF "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# debug MSG
#   Prints the supplies message to stderr, but only if debug mode is
#   activated.
debug() {
  is_debug && return
  echo "DEBUG: ${1}" 1>&2
}

# warn MSG
#   Prints the supplies message to stderr.
warn() {
  echo "WARN: ${1}" 1>&2
}

# error MSG [EXIT_CODE]
#  Prints the supplied message to stderr and returns the shell's
#  last known exit code, $?. If a second argument is provided the
#  function returns its value as the return code.
error() {
  exit_code="${?}"; [ -n "${2}" ] && exit_code="${2}"
  [ "${exit_code}" -eq "0" ] && return 0
  echo "ERROR [${exit_code}] - ${1}" 1>&2; return "${exit_code}"
}

# fatal MSG [EXIT_CODE]
#  Prints the supplied message to stderr and exits with the shell's
#  last known exit code, $?. If a second argument is provided the 
#  program exits with that value as the exit code.
fatal() {
  exit_code="${?}"; [ -n "${2}" ] && exit_code="${2}"
  [ "${exit_code}" -eq "0" ] && return 0
  echo "FATAL [${exit_code}] - ${1}" 1>&2; exit "${exit_code}"
}

# Warn the user if certain, expected directories do not exist.
warn_and_mkdir_sysdir() {
  [ ! -d "${1}" ] && \
    warn "${1} does not exist, system may be unsupported" && \
    mkdir -p "${1}"
}
warn_and_mkdir_sysdir /etc/default
warn_and_mkdir_sysdir /etc/profile.d
warn_and_mkdir_sysdir /etc/systemd/system
warn_and_mkdir_sysdir /etc/sysconfig
warn_and_mkdir_sysdir /etc/modules-load.d
warn_and_mkdir_sysdir /etc/sysctl.d

# If the kubeeve defaults file is present then load it.
KUP_DEFAULTS=${KUP_DEFAULTS:-/etc/default/kubeeve}
if [ -e "${KUP_DEFAULTS}" ]; then
  echo "loading defaults = ${KUP_DEFAULTS}"
  # shellcheck disable=SC1090
  . "${KUP_DEFAULTS}" || fatal "failed to load defaults = ${KUP_DEFAULTS}"
fi

# NODE_TYPE is first assgined to the value of the first argument, $1. 
# If unset, NODE_TYPE is assigned the value of the environment variable
# NODE_TYPE. If unset, NODE_TYPE defaults to "both".
NODE_TYPE="${1:-${NODE_TYPE:-both}}"

# ETCD_DISCOVERY is first assgined to the value of the second argument, $2. 
# If unset, ETCD_DISCOVERY is assigned the value of the environment variable
# ETCD_DISCOVERY.
ETCD_DISCOVERY="${2:-${ETCD_DISCOVERY}}"

# NUM_CONTROLLERS is first assgined to the value of the third argument, $3. 
# If unset, NUM_CONTROLLERS is assigned the value of the environment variable
# NUM_CONTROLLERS. If unset, NUM_CONTROLLERS defaults to "1".
NUM_CONTROLLERS="${3:-${NUM_CONTROLLERS}}"
NUM_CONTROLLERS="${NUM_CONTROLLERS:-1}"

# NUM_NODES is first assgined to the value of the fourth argument, $4. 
# If unset, NUM_NODES is assigned the value of the environment variable
# NUM_NODES. If unset, NUM_NODES defaults to the value of the environment
# variable NUM_CONTROLLERS.
NUM_NODES="${4:-${NUM_NODES}}"
NUM_NODES="${NUM_NODES:-${NUM_CONTROLLERS}}"

echo "pre-processed input"
echo "  NODE_TYPE       = ${NODE_TYPE}"
echo "  ETCD_DISCOVERY  = ${ETCD_DISCOVERY}"
echo "  NUM_CONTROLLERS = ${NUM_CONTROLLERS}"
echo "  NUM_NODES       = ${NUM_NODES}"

# A quick var and function that indicates whether this is a single
# node cluster.
is_single() { [ -z "${ETCD_DISCOVERY}" ]; }

# Returns a success if the provided argument is a whole number.
is_whole_num() { echo "${1}" | grep -q '^[[:digit:]]\{1,\}$'; }

if is_single; then
  echo "deploying single node cluster"
  NODE_TYPE=both; NUM_CONTROLLERS=1; NUM_NODES=1
else
  echo "deploying multi-node cluster"

  [ -z "${NODE_TYPE}" ] && fatal "missing NODE_TYPE"
  [ -z "${NUM_CONTROLLERS}" ] && fatal "missing NUM_CONTROLLERS"
  [ -z "${NUM_NODES}" ] && fatal "missing NUM_NODES"

  # Normalize NODE_TYPE to "controller", "worker", or "both". If NODE_TYPE
  # is none of these then the script exits with an error.
  NODE_TYPE=$(echo "${NODE_TYPE}" | \
    grep -io '^both\|controller\|worker$' | \
    tr '[:upper:]' '[:lower:]') || \
    fatal "invalid NODE_TYPE=${NODE_TYPE}"

  # Ensure NUM_CONTROLLERS and NUM_NODES are both set to whole numbers.
  # If either is not set to a whole number then the script exits with
  # an error.
  ! is_whole_num "${NUM_CONTROLLERS}" && \
    fatal "invalid NUM_CONTROLLERS=${NUM_CONTROLLERS}"
  ! is_whole_num "${NUM_NODES}" && \
    fatal "invalid NUM_NODES=${NUM_NODES}"
fi

echo "post-processed input"
echo "  NODE_TYPE       = ${NODE_TYPE}"
echo "  ETCD_DISCOVERY  = ${ETCD_DISCOVERY}"
echo "  NUM_CONTROLLERS = ${NUM_CONTROLLERS}"
echo "  NUM_NODES       = ${NUM_NODES}"

################################################################################
##                                Config                                      ##
################################################################################

HOST_FQDN=$(hostname) || fatal "failed to get host fqdn"
HOST_NAME=$(hostname -s) || fatal "failed to get host name"
IPV4_ADDRESS=$(ip route get 1 | awk '{print $NF;exit}') || \
  fatal "failed to get ipv4 address"
IPV4_DEFAULT_GATEWAY="$(ip route get 1 | awk '{print $3;exit}')" || \
  fatal "failed to get ipv4 default gateway"

# Network information about the host.
NETWORK_DOMAIN="${NETWORK_DOMAIN:-cluster.local}"
NETWORK_IPV4_SUBNET_CIDR="${NETWORK_IPV4_SUBNET_CIDR:-${IPV4_DEFAULT_GATEWAY}/24}"
NETWORK_DNS_1="${NETWORK_DNS_1:-8.8.8.8}"
NETWORK_DNS_2="${NETWORK_DNS_2:-8.8.4.4}"
NETWORK_DNS_SEARCH="${NETWORK_DNS_SEARCH:-${NETWORK_DOMAIN}}"

# Set to "true" to configure IP tables to allow all 
# inbound and outbond connections.
IPTABLES_ALLOW_ALL=true
{ is_debug && IPTABLES_ALLOW_ALL=true; } || \
IPTABLES_ALLOW_ALL=$(parse_bool "${IPTABLES_ALLOW_ALL}")

# Setting this to true causes all of the temporary content stored
# in etcd for sharing assets to NOT be removed once the deploy process
# has completed.
CLEANUP_DISABLED=true
{ is_debug && CLEANUP_DISABLED=true; } || \
CLEANUP_DISABLED=$(parse_bool "${CLEANUP_DISABLED}")

# The directory in which the CNI plug-in binaries are located.
# The plug-ins are downloaded to CNI_BIN_DIR and then symlinked to
# /opt/cni/bin because Kubernetes --cni-bin-dir flag does not seem
# to work, and so the plug-ins need to be accessible in the default
# location.
CNI_BIN_DIR="${CNI_BIN_DIR:-/opt/bin/cni}"

# The default curl command to use instead of invoking curl directly.
CURL="curl --retry 5 --retry-delay 1 --retry-max-time 120"

# Setting CURL_DEBUG to a truthy value causes the default curl command
# to use verbose mode. Please keep in mind that this can negatively
# affect pattern matching that may be applied to curl output.
CURL_DEBUG=$(parse_bool "${CURL_DEBUG}")
[ "${CURL_DEBUG}" = "true" ] && CURL="${CURL} -v"

# Set to true to download and run the kubernetes e2e conformance test suite.
RUN_CONFORMANCE_TESTS="${RUN_CONFORMANCE_TESTS:-false}"

# Can be generated with:
#  head -c 32 /dev/urandom | base64
ENCRYPTION_KEY="${ENCRYPTION_KEY:-$(head -c 32 /dev/urandom | base64)}" || \
  fatal "error generating encryption key"

# The K8s cluster admin.
CLUSTER_ADMIN="${CLUSTER_ADMIN:-kubernetes}"

# The name of the K8s cluster.
CLUSTER_NAME="${CLUSTER_NAME:-kubernetes}"

# The FQDN of the K8s cluster.
CLUSTER_FQDN="${CLUSTER_NAME}.${NETWORK_DOMAIN}"

# The K8s cluster CIDR.
CLUSTER_CIDR="${CLUSTER_CIDR:-10.200.0.0/16}"

# The format of K8s pod CIDR. The format should include a %d to be
# replaced by the index of this host in the cluster as discovered 
# via etcd. The result is assigned to POD_CIDR. If this is a single-node 
# cluster then POD_CIDR will be set to 10.200.0.0/24 (per the default
# pattern below).
POD_CIDR_FORMAT="${POD_CIDR_FORMAT:-10.200.%d.0/24}"

# The secure port on which the K8s API server is advertised.
SECURE_PORT="${SECURE_PORT:-443}"

# The K8s cluster's service CIDR.
SERVICE_CIDR="${SERVICE_CIDR:-10.32.0.0/24}"

# The IP address used to access the K8s API server on the service network.
SERVICE_IPV4_ADDRESS="${SERVICE_IPV4_ADDRESS:-10.32.0.1}"

# The IP address of the DNS server for the service network.
SERVICE_DNS_IPV4_ADDRESS="${SERVICE_DNS_IPV4_ADDRESS:-10.32.0.10}"

# The domain name used by the K8s service network.
SERVICE_DOMAIN="${SERVICE_DOMAIN:-cluster.local}"

# The name of the service record that points to the K8s API server on
# the service network.
SERVICE_NAME="${SERVICE_NAME:-${CLUSTER_NAME}}"

# The FQDN used to access the K8s API server on the service network.
SERVICE_FQDN="${SERVICE_NAME}.default.svc.${SERVICE_DOMAIN}"

# The name of the cloud provider to use.
#CLOUD_PROVIDER=

# The gzip'd, base-64 encoded cloud provider configuration to use.
#CLOUD_CONFIG=

# Versions of the software packages installed on the controller and
# worker nodes. Please note that not all the software packages listed
# below are installed on both controllers and workers. Some is intalled
# on one, and some the other. Some software, such as jq, is installed
# on both controllers and workers.
K8S_VERSION="${K8S_VERSION:-release/stable}"
CNI_PLUGINS_VERSION="${CNI_PLUGINS_VERSION:-0.7.1}"
CONTAINERD_VERSION="${CONTAINERD_VERSION:-1.2.0-beta.2}"
COREDNS_VERSION="${COREDNS_VERSION:-1.2.2}"
CRICTL_VERSION="${CRICTL_VERSION:-1.11.1}"
ETCD_VERSION="${ETCD_VERSION:-3.3.9}"
JQ_VERSION="${JQ_VERSION:-1.5}"
VERSION="${VERSION:-kubernetes}"
NGINX_VERSION="${NGINX_VERSION:-1.14.0}"
RUNC_VERSION="${RUNC_VERSION:-1.0.0-rc5}"
RUNSC_VERSION="${RUNSC_VERSION:-2018-09-01}"

# The paths to the TLS CA crt and key files used to sign the
# generated certificate signing request (CSR).
TLS_CA_CRT=${TLS_CA_CRT:-/etc/ssl/ca.crt}
TLS_CA_KEY=${TLS_CA_KEY:-/etc/ssl/ca.key}

# The paths to the generated key and certificate files.
# If TLS_KEY_OUT, TLS_CRT_OUT, and TLS_PEM_OUT are all unset then
# the generated key and certificate are printed to STDOUT.
#TLS_KEY_OUT=server.key
#TLS_CRT_OUT=server.crt

# The strength of the generated certificate
TLS_DEFAULT_BITS=${TLS_DEFAULT_BITS:-2048}

# The number of days until the certificate expires. The default
# value is 100 years.
TLS_DEFAULT_DAYS=${TLS_DEFAULT_DAYS:-36500}

# The components that make up the certificate's distinguished name.
TLS_COUNTRY_NAME=${TLS_COUNTRY_NAME:-US}
TLS_STATE_OR_PROVINCE_NAME=${TLS_STATE_OR_PROVINCE_NAME:-California}
TLS_LOCALITY_NAME=${TLS_LOCALITY_NAME:-Palo Alto}
TLS_ORG_NAME=${TLS_ORG_NAME:-VMware}
TLS_OU_NAME=${TLS_OU_NAME:-CNX}
TLS_COMMON_NAME=${TLS_COMMON_NAME:-${1}}
TLS_EMAIL=${TLS_EMAIL:-cnx@vmware.com}

# Set to true to indicate the certificate is a CA.
TLS_IS_CA="${TLS_IS_CA:-FALSE}"

# The certificate's key usage.
TLS_KEY_USAGE="${TLS_KEY_USAGE:-digitalSignature, keyEncipherment}"

# The certificate's extended key usage string.
TLS_EXT_KEY_USAGE="${TLS_EXT_KEY_USAGE:-clientAuth, serverAuth}"

# Set to false to disable subject alternative names (SANs).
TLS_SAN="${TLS_SAN:-true}"

# A space-delimited list of FQDNs to use as SANs.
TLS_SAN_DNS="${TLS_SAN_DNS:-localhost ${HOST_NAME} ${HOST_FQDN}}"

# A space-delimited list of IP addresses to use as SANs.
TLS_SAN_IP="${TLS_SAN_IP:-127.0.0.1 ${IPV4_ADDRESS}}"

# The deafult owner and perms for generated TLS key and certs.
TLS_KEY_UID=0
TLS_KEY_GID=0
TLS_KEY_PERM=0400
TLS_CRT_UID=0
TLS_CRT_GID=0
TLS_CRT_PERM=0644

################################################################################
##                                Functions                                   ##
################################################################################

# The lock file used when obtaining a distributed lock with etcd.
LOCK_FILE="$(basename "${0}").lock"

# The name of the distributed lock.
LOCK_KEY="$(basename "${0}").lock"

# The process ID of the "etcdctl lock" command used to obtain the
# distributed lock.
LOCK_PID=

# Releases a distributed lock obtained from the etcd server. This function will
# not work until the etcd server is online and etcdctl has been configured.
release_lock() {
  kill "${LOCK_PID}"; wait "${LOCK_PID}" || true; rm -f "${LOCK_FILE}"
  echo "released lock ${LOCK_KEY}"
}

# Obtains a distributed lock from the etcd server. This function will
# not work until the etcd server is online and etcdctl has been configured.
obtain_lock() {
  echo "create lock file=${LOCK_FILE}"
  mkfifo "${LOCK_FILE}" || { error "failed to create fifo lock file"; return; }

  echo "obtaining distributed lock=${LOCK_KEY}"
  etcdctl lock "${LOCK_KEY}" >"${LOCK_FILE}" &
  LOCK_PID="${!}"
  echo "distributed lock process pid=${LOCK_PID}"

  if ! read -r lock_name <"${LOCK_FILE}"; then
    exit_code="${?}"
    error "failed to obtain distributed lock: ${lock_name}"
    release_lock "${LOCK_KEY}" "${LOCK_PID}" "${LOCK_FILE}"
    return "${exit_code}"
  fi

  echo "obtained distributed lock: ${lock_name}"
}

# Evaluates the first argument as the name of a function to execute 
# while holding a distributed lock. Regardless of the evaluated function's
# exit code, the lock is always released. This function then exits with
# the exit code of the evaluated function.
do_with_lock() {
  echo "obtaining distributed lock to safely execute ${1}"
  obtain_lock || { error "failed to obtain lock for ${1}"; return; }
  eval "${1}"; exit_code="${?}"
  release_lock
  echo "released lock used to safeley execute ${1}"
  return "${exit_code}"
}

# Executes the supplied command until it succeeds or until 100 attempts
# have occurred over five minutes. If the command has not succeeded
# by that time, an error will be returned.
retry_until_0() {
  msg="${1}"; shift; is_debug || printf "%s" "${msg}"
  i=1 && while true; do
    [ "${i}" -gt 100 ] && { error "timed out: ${msg}" 1; return; }
    if is_debug; then
      echo "${1}: attempt ${i}" && "${@}" && break
    else
      printf "." && "${@}" >/dev/null 2>&1 && break
    fi
    sleep 3; i=$((i+1))
  done
  { is_debug && echo "${msg}: success"; } || echo "✓"
}

# Reverses an FQDN and substitutes slash characters for periods.
# For example, k8s.vmware.ci becomes ci/vmware/k8s.
reverse_fqdn() {
  echo "${1}" | tr '.' '\n' | \
    sed '1!x;H;1h;$!d;g' | tr '\n' '.' | \
    sed 's/.$//' | tr '.' '/'
}

# Reverses and IP address and removes a trailing subnet notation. 
# For example, 10.32.0.0/24 becomes 0.0.32.10.
reverse_ipv4_address() {
  echo "${1}" | sed 's~\(.\{1,\}\)/[[:digit:]]\{1,\}~\1~g' | \
    tr '.' '\n' | sed '1!x;H;1h;$!d;g' | \
    tr '\n' '.' | sed 's/.$//'
}

# Creates a new X509 certificate/key pair.
new_cert() {
  # Make a temporary directory and switch to it.
  OLDDIR=$(pwd) || return
  { MYTEMP=$(mktemp -d) && cd "${MYTEMP}"; } || return

  # Write the SSL config file to disk.
  cat > ssl.conf <<EOF
[ req ]
default_bits           = ${TLS_DEFAULT_BITS}
default_days           = ${TLS_DEFAULT_DAYS}
encrypt_key            = no
default_md             = sha1
prompt                 = no
utf8                   = yes
distinguished_name     = dn
req_extensions         = ext
x509_extensions        = ext

[ dn ]
countryName            = ${TLS_COUNTRY_NAME}
stateOrProvinceName    = ${TLS_STATE_OR_PROVINCE_NAME}
localityName           = ${TLS_LOCALITY_NAME}
organizationName       = ${TLS_ORG_NAME}
organizationalUnitName = ${TLS_OU_NAME}
commonName             = ${TLS_COMMON_NAME}
emailAddress           = ${TLS_EMAIL}

[ ext ]
basicConstraints       = CA:$(echo "${TLS_IS_CA}" | tr '[:lower:]' '[:upper:]')
keyUsage               = ${TLS_KEY_USAGE}
extendedKeyUsage       = ${TLS_EXT_KEY_USAGE}
subjectKeyIdentifier   = hash
EOF

  if [ "${TLS_SAN}" = "true" ] && \
    { [ -n "${TLS_SAN_DNS}" ] || [ -n "${TLS_SAN_IP}" ]; }; then
    cat >> ssl.conf <<EOF
subjectAltName         = @sans

# DNS.1-n-1 are additional DNS SANs parsed from TLS_SAN_DNS
# IP.1-n-1  are additional IP SANs parsed from TLS_SAN_IP
[ sans ]
EOF

    # Append any DNS SANs to the SSL config file.
    i=1 && for j in $TLS_SAN_DNS; do
      echo "DNS.${i}                  = $j" >> ssl.conf && i="$(( i+1 ))"
    done

    # Append any IP SANs to the SSL config file.
    i=1 && for j in $TLS_SAN_IP; do
      echo "IP.${i}                   = $j" >> ssl.conf && i="$(( i+1 ))"
    done
  fi

  echo "generating x509 cert/key pair"
  echo "  TLS_CA_CRT                 = ${TLS_CA_CRT}"
  echo "  TLS_CA_KEY                 = ${TLS_CA_KEY}"
  echo "  TLS_KEY_OUT                = ${TLS_KEY_OUT}"
  echo "  TLS_KEY_UID                = ${TLS_KEY_UID}"
  echo "  TLS_KEY_GID                = ${TLS_KEY_GID}"
  echo "  TLS_KEY_PERM               = ${TLS_KEY_PERM}"
  echo "  TLS_CRT_OUT                = ${TLS_CRT_OUT}"
  echo "  TLS_CRT_UID                = ${TLS_CRT_UID}"
  echo "  TLS_CRT_GID                = ${TLS_CRT_GID}"
  echo "  TLS_CRT_PERM               = ${TLS_CRT_PERM}"
  echo "  TLS_DEFAULT_BITS           = ${TLS_DEFAULT_BITS}"
  echo "  TLS_DEFAULT_DAYS           = ${TLS_DEFAULT_DAYS}"
  echo "  TLS_COUNTRY_NAME           = ${TLS_COUNTRY_NAME}"
  echo "  TLS_STATE_OR_PROVINCE_NAME = ${TLS_STATE_OR_PROVINCE_NAME}"
  echo "  TLS_LOCALITY_NAME          = ${TLS_LOCALITY_NAME}"
  echo "  TLS_ORG_NAME               = ${TLS_ORG_NAME}"
  echo "  TLS_OU_NAME                = ${TLS_OU_NAME}"
  echo "  TLS_COMMON_NAME            = ${TLS_COMMON_NAME}"
  echo "  TLS_EMAIL                  = ${TLS_EMAIL}"
  echo "  TLS_IS_CA                  = ${TLS_IS_CA}"
  echo "  TLS_KEY_USAGE              = ${TLS_KEY_USAGE}"
  echo "  TLS_EXT_KEY_USAGE          = ${TLS_EXT_KEY_USAGE}"
  echo "  TLS_SAN                    = ${TLS_SAN}"
  echo "  TLS_SAN_DNS                = ${TLS_SAN_DNS}"
  echo "  TLS_SAN_IP                 = ${TLS_SAN_IP}"

  # Generate a private key file.
  openssl genrsa -out "${TLS_KEY_OUT}" "${TLS_DEFAULT_BITS}" || \
    { error "failed to generate a new private key"; return; }

  # Generate a certificate CSR.
  openssl req -config ssl.conf \
              -new \
              -key "${TLS_KEY_OUT}" \
              -out csr.pem || \
    { error "failed to generate a csr"; return; }

  # Sign the CSR with the provided CA.
  openssl x509 -extfile ssl.conf \
               -extensions ext \
               -req \
               -in csr.pem \
               -CA "${TLS_CA_CRT}" \
               -CAkey "${TLS_CA_KEY}" \
               -CAcreateserial \
               -out "${TLS_CRT_OUT}" || \
    { error "failed to sign csr with ca"; return; }

  [ -n "${TLS_KEY_UID}" ] && chown "${TLS_KEY_UID}" "${TLS_KEY_OUT}"
  [ -n "${TLS_KEY_GID}" ] && chgrp "${TLS_KEY_GID}" "${TLS_KEY_OUT}"
  [ -n "${TLS_KEY_PERM}" ] && chmod "${TLS_KEY_PERM}" "${TLS_KEY_OUT}"

  [ -n "${TLS_CRT_UID}" ] && chown "${TLS_CRT_UID}" "${TLS_CRT_OUT}"
  [ -n "${TLS_CRT_GID}" ] && chgrp "${TLS_CRT_GID}" "${TLS_CRT_OUT}"
  [ -n "${TLS_CRT_PERM}" ] && chmod "${TLS_CRT_PERM}" "${TLS_CRT_OUT}"

  # Print the certificate's information if requested.
  openssl x509 -noout -text <"${TLS_CRT_OUT}" || \
    { error "failed to print certificate"; return; }

  cd "${OLDDIR}" || { error "failed to cd to ${OLDDIR}"; return; }
}

# Creates a new kubeconfig file.
new_kubeconfig() {
  [ -z "${KFG_FILE_PATH}" ] && { error "missing KFG_FILE_PATH"; return; }
  [ -z "${KFG_USER}" ] && { error "missing KFG_USER"; return; }
  [ -z "${KFG_TLS_CRT}" ] && { error "missing KFG_TLS_CRT"; return; }
  [ -z "${KFG_TLS_KEY}" ] && { error "missing KFG_TLS_KEY"; return; }

  kfg_cluster="${KCFG_CLUSTER:-${CLUSTER_FQDN}}"
  kfg_tls_ca_crt="${KFG_TLS_CA_CRT:-${TLS_CA_CRT}}"
  kfg_server="${KFG_SERVER:-https://${CLUSTER_FQDN}:${SECURE_PORT}}"
  kfg_context="${KFG_CONTEXT:-default}"
  kfg_uid="${KFG_UID:-root}"
  kfg_gid="${KFG_GID:-root}"
  kfg_perm="${KFG_PERM:-0400}"

  echo "generating kubeconfig"
  echo "  KFG_FILE_PATH  = ${KFG_FILE_PATH}"
  echo "  KFG_TLS_CA_CRT = ${kfg_tls_ca_crt}"
  echo "  KFG_TLS_CRT    = ${KFG_TLS_CRT}"
  echo "  KFG_TLS_KEY    = ${KFG_TLS_KEY}"
  echo "  KFG_CLUSTER    = ${kfg_cluster}"
  echo "  KFG_SERVER     = ${kfg_server}"
  echo "  KFG_CONTEXT    = ${kfg_context}"
  echo "  KFG_USER       = ${KFG_USER}"
  echo "  KFG_UID        = ${kfg_uid}"
  echo "  KFG_GID        = ${kfg_gid}"
  echo "  KFG_PERM       = ${kfg_perm}"

  kubectl config set-cluster "${kfg_cluster}" \
    --certificate-authority="${kfg_tls_ca_crt}" \
    --embed-certs=true \
    --server="${kfg_server}" \
    --kubeconfig="${KFG_FILE_PATH}" || \
    { error "failed to kubectl config set-cluster"; return; }

  kubectl config set-credentials "${KFG_USER}" \
    --client-certificate="${KFG_TLS_CRT}" \
    --client-key="${KFG_TLS_KEY}" \
    --embed-certs=true \
    --kubeconfig="${KFG_FILE_PATH}" || \
    { error "failed to kubectl config set-credentials"; return; }

  kubectl config set-context "${kfg_context}" \
    --cluster="${kfg_cluster}" \
    --user="${KFG_USER}" \
    --kubeconfig="${KFG_FILE_PATH}" || \
    { error "failed to kubectl config set-context"; return; }

  kubectl config use-context "${kfg_context}" \
    --kubeconfig="${KFG_FILE_PATH}" || \
    { error "failed to kubectl config use-context"; return; }

  chown "${kfg_uid}"  "${KFG_FILE_PATH}" || return
  chgrp "${kfg_gid}"  "${KFG_FILE_PATH}" || return
  chmod "${kfg_perm}" "${KFG_FILE_PATH}" || return
}

# Configures iptables.
configure_iptables() {
  echo "installing iptables"

  # Tell iptables to allow all incoming and outgoing connections.
  if [ "${IPTABLES_ALLOW_ALL}" = "true" ]; then
    warn "iptables allow all"
    cat <<EOF >/etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
# Allow all incoming packets.
-A INPUT -j ACCEPT
# Enable the rules.
COMMIT
EOF

  # Configure iptables for controller nodes.
  elif [ "${NODE_TYPE}" = "controller" ]; then
    echo "iptables enabled for controller node"
    cat <<EOF >/etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Block all null packets.
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Reject a syn-flood attack.
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Block XMAS/recon packets.
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow all incoming packets on the loopback interface.
-A INPUT -i lo -j ACCEPT

# Allow incoming packets for SSH.
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Allow incoming packets for the etcd client and peer endpoints.
-A INPUT -p tcp -m tcp --dport 2379 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2380 -j ACCEPT

# Allow incoming packets for DNS.
-A INPUT -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -p udp -m udp --dport 53 -j ACCEPT

# Allow incoming packets for HTTP/HTTPS.
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT

# Allow incoming packets for established connections.
-I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow all outgoing packets.
-P OUTPUT ACCEPT

# Drop everything else.
-P INPUT DROP

# Enable the rules.
COMMIT
EOF

  # Configure iptables for worker nodes.
  elif [ "${NODE_TYPE}" = "worker" ]; then
    echo "iptables enabled for worker node"
    cat <<EOF >/etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Block all null packets.
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Reject a syn-flood attack.
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Block XMAS/recon packets.
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow all incoming packets on the loopback interface.
-A INPUT -i lo -j ACCEPT

# Allow incoming packets for SSH.
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Allow incoming packets for cAdvisor, used to query container metrics.
-A INPUT -p tcp -m tcp --dport 4149 -j ACCEPT

# Allow incoming packets for the unrestricted kubelet API.
-A INPUT -p tcp -m tcp --dport 10250 -j ACCEPT

# Allow incoming packets for the unauthenticated, read-only port used
# to query the node state.
-A INPUT -p tcp -m tcp --dport 10255 -j ACCEPT

# Allow incoming packets for kube-proxy's health check server.
-A INPUT -p tcp -m tcp --dport 10256 -j ACCEPT

# Allow incoming packets for Calico's health check server.
-A INPUT -p tcp -m tcp --dport 9099 -j ACCEPT

# Allow incoming packets for NodePort services.
# https://kubernetes.io/docs/setup/independent/install-kubeadm/
-A INPUT -p tcp -m multiport --dports 30000:32767 -j ACCEPT

# Allow incoming packets for established connections.
-I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow all outgoing packets.
-P OUTPUT ACCEPT

# Drop everything else.
-P INPUT DROP

# Enable the rules.
COMMIT
EOF

  # Configure iptables for hosts that are simultaneously controller and
  # worker nodes in a multi-node cluster.
  elif ! is_single; then
    echo "iptables enabled for controller/worker node"
    cat <<EOF >/etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Block all null packets.
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Reject a syn-flood attack.
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Block XMAS/recon packets.
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow all incoming packets on the loopback interface.
-A INPUT -i lo -j ACCEPT

# Allow incoming packets for SSH.
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Allow incoming packets for the etcd client and peer endpoints.
-A INPUT -p tcp -m tcp --dport 2379 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 2380 -j ACCEPT

# Allow incoming packets for DNS.
-A INPUT -p tcp -m tcp --dport 53 -j ACCEPT
-A INPUT -p udp -m udp --dport 53 -j ACCEPT

# Allow incoming packets for HTTP/HTTPS.
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT

# Allow incoming packets for cAdvisor, used to query container metrics.
-A INPUT -p tcp -m tcp --dport 4149 -j ACCEPT

# Allow incoming packets for the unrestricted kubelet API.
-A INPUT -p tcp -m tcp --dport 10250 -j ACCEPT

# Allow incoming packets for the unauthenticated, read-only port used
# to query the node state.
-A INPUT -p tcp -m tcp --dport 10255 -j ACCEPT

# Allow incoming packets for kube-proxy's health check server.
-A INPUT -p tcp -m tcp --dport 10256 -j ACCEPT

# Allow incoming packets for Calico's health check server.
-A INPUT -p tcp -m tcp --dport 9099 -j ACCEPT

# Allow incoming packets for NodePort services.
# https://kubernetes.io/docs/setup/independent/install-kubeadm/
-A INPUT -p tcp -m multiport --dports 30000:32767 -j ACCEPT

# Allow incoming packets for established connections.
-I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow all outgoing packets.
-P OUTPUT ACCEPT

# Drop everything else.
-P INPUT DROP

# Enable the rules.
COMMIT
EOF

  # Configure iptables for a single-node cluster.
  else
    echo "iptables enabled for single node cluster"
    cat <<EOF >/etc/sysconfig/iptables
*filter
:INPUT DROP [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]

# Block all null packets.
-A INPUT -p tcp --tcp-flags ALL NONE -j DROP

# Reject a syn-flood attack.
-A INPUT -p tcp ! --syn -m state --state NEW -j DROP

# Block XMAS/recon packets.
-A INPUT -p tcp --tcp-flags ALL ALL -j DROP

# Allow all incoming packets on the loopback interface.
-A INPUT -i lo -j ACCEPT

# Allow incoming packets for SSH.
-A INPUT -p tcp -m tcp --dport 22 -j ACCEPT

# Allow incoming packets for HTTP/HTTPS.
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 443 -j ACCEPT

# Allow incoming packets for established connections.
-I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow all outgoing packets.
-P OUTPUT ACCEPT

# Drop everything else.
-P INPUT DROP

# Enable the rules.
COMMIT
EOF
  fi

  cp -f /etc/sysconfig/iptables /etc/sysconfig/ip6tables
  if systemctl is-enabled iptables.service >/dev/null 2>&1; then
    echo "restarting iptables.service"
    systemctl -l restart iptables.service || \
      { error "failed to restart iptables.service"; return; }
  fi
  if systemctl is-enabled ip6tables.service >/dev/null 2>&1; then
    echo "restarting ip6tables.service"
    systemctl -l restart ip6tables.service || \
      { error "failed to restart ip6tables.service"; return; }
  fi
}

# Enables the bridge module. This function is used by worker nodes.
enable_bridge_module() {
  # Do not enable the bridge module on controller nodes.
  [ "${NODE_TYPE}" = "controller" ] && return

  echo "installing bridge kernel module"
  echo br_netfilter > /etc/modules-load.d/br_netfilter.conf
  if systemctl is-enabled systemd-modules-load.service >/dev/null 2>&1; then
    systemctl -l restart systemd-modules-load.service || \
      { error "failed to restart systemd-modules-load.service"; return; }
  fi
  cat <<EOF >/etc/sysctl.d/k8s-bridge.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
  sysctl --system || { error "failed to sysctl --system"; return; }
}

# Enables IP forwarding.
enable_ip_forwarding() {
  echo "enabling ip forwarding"
  echo "net.ipv4.ip_forward = 1" >/etc/sysctl.d/k8s-ip-forward.conf
  sysctl --system || { error "failed to sysctl --system"; return; }
}

# Reads the CA cert/key pair from TLS_CA_CRT_GZ and TLS_CA_KEY_GZ and
# writes them to TLS_CA_CRT and TLS_CA_KEY.
install_ca_files() {
  if [ -e "${TLS_CA_CRT}" ]; then
    echo "using existing CA crt at ${TLS_CA_CRT}"
  else
    [ -z "${TLS_CA_CRT_GZ}" ] && { error "missing TLS_CA_CRT_GZ"; return; }
    echo "writing CA crt file ${TLS_CA_CRT}"
    echo "${TLS_CA_CRT_GZ}" | base64 -d | gzip -d > "${TLS_CA_CRT}" || \
      { error "failed to write CA crt"; return; }
  fi
  if [ -e "${TLS_CA_KEY}" ]; then
    echo "using existing CA key at ${TLS_CA_KEY}"
  else
    [ -z "${TLS_CA_KEY_GZ}" ] && { error "missing TLS_CA_KEY_GZ"; return; }
    echo "writing CA key file ${TLS_CA_KEY}"
    echo "${TLS_CA_KEY_GZ}" | base64 -d | gzip -d > "${TLS_CA_KEY}" || \
      { error "failed to write CA key"; return; }
  fi
}

put_string() {
  echo "putting '${2}' into etcd key '${1}'"
  etcdctl put "${1}" "${2}" || \
    { error "failed to put '${2}' into etcd key '${1}'"; return; }
}

put_file() {
  echo "putting contents of '${2}' to etcd key '${1}'"
  etcdctl put "${1}" -- <"${2}" || \
    { error "failed to put contents of '${2}' to etcd key '${1}'"; return; }
}

install_etcd() {
  # Do not install etcd on worker nodes.
  [ "${NODE_TYPE}" = "worker" ] && return

  # Create the etcd user if it doesn't exist.
  if ! getent passwd etcd >/dev/null 2>&1; then 
    echo "creating etcd user"
    useradd etcd --home /var/lib/etcd --no-user-group --system -M || \
      { error "failed to create etcd user"; return; }
  fi

  # Create the etcd directories and set their owner to etcd.
  echo "creating directories for etcd server"
  mkdir -p /var/lib/etcd/data
  chown etcd /var/lib/etcd /var/lib/etcd/data || return

  echo "generating cert for etcd client and peer endpoints"
  (TLS_KEY_OUT=/etc/ssl/etcd.key \
    TLS_CRT_OUT=/etc/ssl/etcd.crt \
    TLS_KEY_UID=etcd \
    TLS_CRT_UID=etcd \
    TLS_SAN_DNS="localhost ${HOST_NAME} ${HOST_FQDN} ${CLUSTER_FQDN}" \
    TLS_SAN_IP="127.0.0.1 ${IPV4_ADDRESS}" \
    TLS_COMMON_NAME="${HOST_FQDN}" new_cert) || \
    { error "failed to generate certs for etcd"; return; }

  echo "writing etcd defaults file=/etc/default/etcd"
  # Create the etcd environment file.
cat <<EOF > /etc/default/etcd
ETCD_DEBUG=${DEBUG}
ETCD_NAME=${HOST_NAME}
ETCD_DATA_DIR=/var/lib/etcd/data
ETCD_LISTEN_PEER_URLS=https://${IPV4_ADDRESS}:2380
ETCD_LISTEN_CLIENT_URLS=https://0.0.0.0:2379
ETCD_INITIAL_ADVERTISE_PEER_URLS=https://${IPV4_ADDRESS}:2380
ETCD_ADVERTISE_CLIENT_URLS=https://${IPV4_ADDRESS}:2379

ETCD_CERT_FILE=/etc/ssl/etcd.crt
ETCD_KEY_FILE=/etc/ssl/etcd.key
ETCD_CLIENT_CERT_AUTH=true
ETCD_TRUSTED_CA_FILE=/etc/ssl/ca.crt
ETCD_PEER_CERT_FILE=/etc/ssl/etcd.crt
ETCD_PEER_KEY_FILE=/etc/ssl/etcd.key
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_TRUSTED_CA_FILE=/etc/ssl/ca.crt
EOF

  # If ETCD_DISCOVERY is set then add it to the etcd environment file.
  if [ -n "${ETCD_DISCOVERY}" ]; then
    echo "using etcd discovery url: ${ETCD_DISCOVERY}"
    echo "ETCD_DISCOVERY=${ETCD_DISCOVERY}" >> /etc/default/etcd
  fi

  # Create the etcd systemd service.
  echo "writing etcd service file=/etc/systemd/system/etcd.service"
  cat <<EOF > /etc/systemd/system/etcd.service
[Unit]
Description=etcd.service
Documentation=https://github.com/etcd-io/etcd
After=network-online.target
Wants=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Type=notify
Restart=always
RestartSec=10s
LimitNOFILE=40000
TimeoutStartSec=0
NoNewPrivileges=true
PermissionsStartOnly=true
User=etcd
WorkingDirectory=/var/lib/etcd
EnvironmentFile=/etc/default/etcd
ExecStart=/opt/bin/etcd
EOF

  echo "enabling etcd service"
  systemctl -l enable etcd.service || \
    { error "failed to enable etcd.service"; return; }

  echo "starting etcd service"
  systemctl -l start etcd.service || \
    { error "failed to start etcd.service"; return; }
}

get_etcd_members_from_discovery_url() {
  members=$(${CURL} -sSL "${ETCD_DISCOVERY}" | \
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
    tr '\n' ' ' | \
    sed 's/\(.\{1,\}\).$/\1/') || return
  num_members=$(echo "${members}" | wc -w | awk '{print $1}') || return
  echo "discovered ${num_members}"
  [ "${num_members}" -eq "${NUM_CONTROLLERS}" ] || return
  echo "discovery complete"
}

# Polls the etcd discovery URL until the number of expected members
# have joined the cluster
discover_etcd_cluster_members() {

  # If this is a single-node cluster then there is no need for discovery.
  if is_single; then
    CONTROLLER_IPV4_ADDRESSES="${IPV4_ADDRESS}"
    echo "discovered etcd cluster members: ${CONTROLLER_IPV4_ADDRESSES}"
    return
  fi

  # Poll the etcd discovery URL until the number of members matches the
  # number of controller nodes.
  #
  # After 100 failed attempts over 5 minutes the function will exit with 
  # an error.
  i=1 && while true; do
    if [ "${i}" -gt 100 ]; then
      error "timed out waiting for etcd members to join cluster" 1; return
    fi

    echo "waiting for etcd members to join cluster: poll attempt ${i}"
    members=$(${CURL} -sSL "${ETCD_DISCOVERY}" | \
      grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
      tr '\n' ' ' | \
      sed 's/\(.\{1,\}\).$/\1/')

    # Break out of the loop if the number of members that have joined
    # the etcd cluster matches the expected number of controller nodes.
    if num_members=$(echo "${members}" | wc -w | awk '{print $1}'); then
      echo "discovered ${num_members}"
      if [ "${num_members}" -eq "${NUM_CONTROLLERS}" ]; then
        echo "discovery complete" && break
      fi
    fi

    sleep 3
    i=$((i+1))
  done

  # Assign the IPv4 addresses of the discovered etcd cluster members to
  # the environment variable that contains the IPv4 addresses of the
  # controller nodes. All controller nodes should be a member of the
  # etcd cluster.
  #
  # The sort command is used to ensure the order of the IP addresses
  # is consistent across all of the nodes.
  CONTROLLER_IPV4_ADDRESSES=$(echo "${members}" | \
    tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/\(.\{1,\}\).$/\1/')
  echo "discovered etcd cluster members: ${CONTROLLER_IPV4_ADDRESSES}"
}

configure_etcdctl() {
  echo "generating cert for etcdctl"
  (TLS_KEY_OUT=/etc/ssl/etcdctl.key \
    TLS_CRT_OUT=/etc/ssl/etcdctl.crt \
    TLS_KEY_GID=k8s-admin \
    TLS_CRT_GID=k8s-admin \
    TLS_KEY_PERM=0440 \
    TLS_SAN=false \
    TLS_COMMON_NAME="etcdctl@${HOST_FQDN}" new_cert) || \
    { error "failed to generate certs for etcdctl"; return; }

  # Create a comma-separated list of the etcd client endpoints.
  for e in ${CONTROLLER_IPV4_ADDRESSES}; do
    if [ -z "${ETCD_CLIENT_ENDPOINTS}" ]; then
      ETCD_CLIENT_ENDPOINTS="https://${e}:2379"
    else
      ETCD_CLIENT_ENDPOINTS="${ETCD_CLIENT_ENDPOINTS},https://${e}:2379"
    fi
  done

  echo "writing etcdctl defaults file=/etc/default/etcdctl"
  cat <<EOF > /etc/default/etcdctl
ETCDCTL_API=3
ETCDCTL_CERT=/etc/ssl/etcdctl.crt
ETCDCTL_KEY=/etc/ssl/etcdctl.key
ETCDCTL_CACERT=/etc/ssl/ca.crt
EOF

  if [ "${NODE_TYPE}" = "worker" ]; then
    echo "ETCDCTL_ENDPOINTS=${ETCD_CLIENT_ENDPOINTS}" >> /etc/default/etcdctl
  else
    echo "ETCDCTL_ENDPOINTS=https://127.0.0.1:2379" >> /etc/default/etcdctl
  fi

  # Load the etcdctl config into this script's process
  # shellcheck disable=SC1091
  set -o allexport && . /etc/default/etcdctl && set +o allexport

  # Make it so others can use the etcdctl config as well.
  echo "writing etcdctl profile.d file=/etc/profile.d/etcdctl.sh"
  cat <<EOF > /etc/profile.d/etcdctl.sh
#!/bin/sh
set -o allexport && . /etc/default/etcdctl && set +o allexport
EOF
}

# Creates DNS entries on the etcd server for this node and an A-record
# for the public cluster FQDN.
create_dns_entries() {
  # Create the round-robin A record for the cluster's public FQDN.
  # This will be executed on each node, and that's okay since it's 
  # no issue to overwrite an existing etcd key.
  echo "creating round-robin DNS A-record for public cluster FQDN"
  cluster_fqdn_rev=$(reverse_fqdn "${CLUSTER_FQDN}")
  i=0 && for a in ${CONTROLLER_IPV4_ADDRESSES}; do
    # Create the A-Record
    etcdctl put "/skydns/${cluster_fqdn_rev}/${i}" '{"host":"'"${a}"'"}'
    echo "created cluster FQDN DNS A-record"
    etcdctl get "/skydns/${cluster_fqdn_rev}/${i}"
    # Increment the address index.
    i=$((i+1))
  done

  fqdn_rev=$(reverse_fqdn "${HOST_FQDN}")
  addr_slashes=$(echo "${IPV4_ADDRESS}" | tr '.' '/')

  # Create the A-Record for this host.
  echo "creating DNS A-record for this host"
  put_string "/skydns/${fqdn_rev}" '{"host":"'"${IPV4_ADDRESS}"'"}' || \
    { error "failed to create DNS A-record"; return; }
  etcdctl get "/skydns/${fqdn_rev}"

  # Create the reverse lookup record for this host.
  echo "creating DNS reverse lookup record for this host"
  put_string "/skydns/arpa/in-addr/${addr_slashes}" '{"host":"'"${HOST_FQDN}"'"}' || \
    { error "failed to create DNS reverse lookup record"; return; }
  etcdctl get "/skydns/arpa/in-addr/${addr_slashes}"
}

install_nginx() {
  # Do not install nginx on worker nodes.
  [ "${NODE_TYPE}" = "worker" ] && return

  # Create the nginx user if it doesn't exist.
  if ! getent passwd nginx >/dev/null 2>&1; then 
    echo "creating nginx user"
    useradd nginx --home /var/lib/nginx --no-user-group --system -M || \
      { error "failed to create nginx user"; return; }
  fi

  echo "creating directories for nginx"
  mkdir -p  /etc/nginx \
            /var/lib/nginx \
            /var/log/nginx

  echo "writing nginx config file=/etc/nginx/nginx.conf"
  cat <<EOF > /etc/nginx/nginx.conf
user                   nginx nobody;
pid                    /var/run/nginx.pid;
error_log              syslog:server=unix:/dev/log;
worker_processes       1;

events {
  worker_connections   1024;
}

http {
  default_type         application/octet-stream;
  log_format           main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                             '\$status \$body_bytes_sent "\$http_referer" '
                             '"\$http_user_agent" "\$http_x_forwarded_for"';
  access_log           syslog:server=unix:/dev/log main;
  sendfile             on;
  keepalive_timeout    65;
  gzip                 on;

    server {
      listen      80;
      server_name ${CLUSTER_FQDN};

      location = /healthz {
        proxy_pass                    https://127.0.0.1:443/healthz;
        proxy_ssl_trusted_certificate /etc/ssl/ca.crt;
        proxy_set_header Host         \$host;
        proxy_set_header X-Real-IP    \$remote_addr;
      }

      location / {
        return 301 http://bit.ly/cnx-cicd-notes;
      }
    }
}
EOF

  echo "writing nginx service=/etc/systemd/system/nginx.service"
  cat <<EOF > /etc/systemd/system/nginx.service
[Unit]
Description=nginx.service
Documentation=http://bit.ly/howto-build-nginx-for-container-linux
After=syslog.target nss-lookup.target

[Install]
WantedBy=multi-user.target

[Service]
Type=forking
PIDFile=/var/run/nginx.pid

ExecStartPre=/opt/bin/nginx -t
ExecStart=/opt/bin/nginx
ExecReload=/opt/bin/nginx -s reload
ExecStop=/bin/kill -s QUIT \$MAINPID
PrivateTmp=true
EOF

  echo "enabling nginx.service"
  systemctl -l enable nginx.service || \
    { error "failed to enable nginx.service"; return; }

  echo "starting nginx.service"
  systemctl -l start nginx.service || \
    { error "failed to start nginx.service"; return; }
}

install_coredns() {
  # Do not install CoreDNS on worker nodes.
  [ "${NODE_TYPE}" = "worker" ] && return

  # Create the coredns user if it doesn't exist.
  if ! getent passwd coredns >/dev/null 2>&1; then 
    echo "creating coredns user"
    useradd coredns --home /var/lib/coredns --no-user-group --system -M || \
      { error "failed to create coredns user"; return; }
  fi

  echo "creating directories for CoreDNS"
  mkdir -p /etc/coredns /var/lib/coredns
  chown coredns /var/lib/coredns || \
    { error "failed to chown /var/lib/coredns"; return; }

  echo "generating certs for coredns"
  (TLS_KEY_OUT=/etc/ssl/coredns.key \
    TLS_CRT_OUT=/etc/ssl/coredns.crt \
    TLS_KEY_UID=coredns TLS_CRT_UID=coredns \
    TLS_COMMON_NAME="coredns@${HOST_FQDN}" \
    new_cert) || \
    { error "failed to generate x509 cert/key pair for CoreDNS"; return; }

  echo "writing /etc/coredns/Corefile"
  cat <<EOF > /etc/coredns/Corefile
. {
    log
    errors
    etcd ${NETWORK_DOMAIN} ${NETWORK_IPV4_SUBNET_CIDR} {
        stubzones
        path /skydns
        endpoint https://127.0.0.1:2379
        upstream ${NETWORK_DNS_1}:53 ${NETWORK_DNS_2}:53
        tls /etc/ssl/coredns.crt /etc/ssl/coredns.key /etc/ssl/ca.crt
    }
    prometheus
    cache 160 ${NETWORK_DOMAIN}
    loadbalance
    proxy . ${NETWORK_DNS_1}:53 ${NETWORK_DNS_2}:53
}
EOF

  echo "writing /etc/systemd/system/coredns.service"
  cat <<EOF > /etc/systemd/system/coredns.service
[Unit]
Description=coredns.service
Documentation=https://github.com/akutz/skydns/releases/tag/15f42ac
After=etcd.service
Requires=etcd.service

[Install]
WantedBy=multi-user.target

# Copied from http://bit.ly/systemd-coredns-service
[Service]
PermissionsStartOnly=true
LimitNOFILE=1048576
LimitNPROC=512
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
User=coredns
WorkingDirectory=/var/lib/coredns
ExecReload=/bin/kill -SIGUSR1 \$MAINPID
Restart=on-failure
ExecStart=/opt/bin/coredns -conf /etc/coredns/Corefile
EOF

  echo "enabling coredns.service"
  systemctl -l enable coredns.service || \
    { error "failed to enable coredns.service"; return; }

  echo "starting coredns.service"
  systemctl -l start coredns.service || \
    { error "failed to start coredns.service"; return; }
}

resolve_via_coredns() {
  # Even on worker nodes the custom resolv.conf is located in /var/lib/coredns.
  mkdir -p /var/lib/coredns

  # Remove the symlink for system's resolv.conf
  rm -f /etc/resolv.conf /var/lib/coredns/resolv.conf

  # Create a resolv.conf that points to the local CoreDNS server.
  if [ "${NODE_TYPE}" = "worker" ]; then
    i=1 && for e in ${CONTROLLER_IPV4_ADDRESSES}; do
      [ "${i}" -gt "3" ] && break
      echo "nameserver ${e}" >> /var/lib/coredns/resolv.conf
      i=$((i+1))
    done
  else
    echo "nameserver 127.0.0.1" >> /var/lib/coredns/resolv.conf
  fi

  # Add a search directive to the file.
  if [ -n "${NETWORK_DNS_SEARCH}" ]; then
    echo "search ${NETWORK_DNS_SEARCH}" >> /var/lib/coredns/resolv.conf
  fi

  # Link the CoreDNS resolv.conf to /etc/resolv.conf
  ln -s /var/lib/coredns/resolv.conf /etc/resolv.conf
}

# Waits until all of the nodes can be resolved by their IP addresses 
# via reverse lookup.
wait_on_reverse_lookup() {

  node_ipv4_addresses=$(get_all_node_ipv4_addresses) || \
    { error "failed to get ipv4 addresses for all nodes"; return; }

  echo "waiting on reverse lookup w node ipv4 addresses=${node_ipv4_addresses}"

  # After 100 failed attempts over 5 minutes the function will exit with 
  # an error.
  i=1 && while true; do
    if [ "${i}" -gt 100 ]; then
      error "timed out waiting for reverse lookup" 1; return
    fi

    echo "waiting for reverse lookup: attempt ${i}"

    all_resolve=true
    for a in ${node_ipv4_addresses}; do
       host "${a}" || { all_resolve=false && break; }
    done

    if [ "${all_resolve}" = "true" ]; then
      echo "all nodes resolved via reverse lookup" && break
    fi

    sleep 3
    i=$((i+1))
  done
}

# If NetworkManager is present, this function causes NetworkManager to
# stop trying to manage DNS so that the custom resolv.conf file created
# by this script will not be overriden.
disable_net_man_dns() {
  if [ -d "/etc/NetworkManager/conf.d" ]; then
    echo "disabling network manager dns"
    cat <<EOF > /etc/NetworkManager/conf.d/00-do-not-manage-dns.conf
[main]
dns=none
rc-manager=unmanaged
EOF
  fi
}

# Creates a sane shell prompt for logged-in users that includes the 
# last exit code.
configure_prompt() {
  echo '#!/bin/sh' > /etc/profile.d/prompt.sh
  echo 'export PS1="[\$?]\[\e[32;1m\]\u\[\e[0m\]@\[\e[32;1m\]\h\[\e[0m\]:\W$ \[\e[0m\]"' >> /etc/profile.d/prompt.sh
}

# Adds ${BIN_DIR} to the PATH for logged-in users.
configure_path() {
  cat <<EOF > /etc/default/path
PATH=${BIN_DIR}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
  cat <<EOF > /etc/profile.d/path.sh
#!/bin/sh
set -o allexport && . /etc/default/path && set +o allexport
EOF
}


# Uploads information about this node to the etcd server.
put_node_info() {
  # Get the number of nodes that have already stored their information.
  # This becomes the node's index, which is important as it forms
  # the node's pod-cidr.
  NODE_INDEX=$(etcdctl get '/kubeeve/nodes/' --prefix --keys-only | grep -cv '^$')

  # Build this node's pod cidr.
  # shellcheck disable=SC2059
  if [ -z "${POD_CIDR}" ]; then
    POD_CIDR=$(printf "${POD_CIDR_FORMAT}" "${NODE_INDEX}")
  fi
  
  node_info_key="/kubeeve/nodes/${NODE_INDEX}"
  echo "node info key=${node_info_key}"
  
  cat <<EOF | etcdctl put "${node_info_key}" || \
    { error "failed to put node info"; return; }
{
  "host_fqdn": "${HOST_FQDN}",
  "host_name": "${HOST_NAME}",
  "ipv4_address": "${IPV4_ADDRESS}",
  "node_type": "${NODE_TYPE}",
  "node_index": ${NODE_INDEX},
  "pod_cidr": "${POD_CIDR}"
}
EOF

  echo "put node info at ${node_info_key}"
}

get_all_node_info() {
  etcdctl get /kubeeve/nodes --sort-by=KEY --prefix
}

get_all_node_ipv4_addresses() {
  get_all_node_info | grep ipv4_address | awk '{print $2}' | tr -d '",'
}

# Polls etcd until all nodes have uploaded their information.
wait_on_all_node_info() {
  # After 100 failed attempts over 5 minutes the function will exit with 
  # an error.
  i=0 && while true; do
    [ "${i}" -gt 100 ] && { error "timed out waiting for node info" 1; return; }
    echo "waiting for all node info: poll attempt ${i}"
    
    # Break out of the loop if the number of nodes that have stored
    # their info matches the number of expected nodes.
    num_nodes=$(etcdctl get '/kubeeve/nodes/' --prefix --keys-only | grep -cv '^$')
    [ "${num_nodes}" -eq "${NUM_NODES}" ] && break

    sleep 3
    i=$((i+1))
  done
}

# Prints the information each node uploaded about itself to the etcd server.
print_all_node_info() {
  i=0 && while true; do
    node_info_key="/kubeeve/nodes/${i}"
    node_info=$(etcdctl get "${node_info_key}" --print-value-only) || break
    [ -z "${node_info}" ] && break
    echo "${node_info_key}"
    echo "${node_info}" | jq '' || \
      { error "problem printing node info"; return; }
    i=$((i+1))
  done
}

install_cni_plugins() {
  # Symlink CNI_BIN_DIR to /opt/cni/bin since Kubernetes --cni-bin-dir
  # flag does not seem to work, and containers fail if the CNI plug-ins
  # are not accessible in the default location.
  mkdir -p /opt/cni
  ln -s "${CNI_BIN_DIR}" /opt/cni/bin || \
    { error "failed to symlink ${CNI_BIN_DIR} to /opt/cni/bin"; return; }

  mkdir -p /etc/cni/net.d/

  echo "writing /etc/cni/net.d/10-bridge.conf"
  cat <<EOF > /etc/cni/net.d/10-bridge.conf
{
  "cniVersion": "0.3.1",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cnio0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [
        {
          "subnet": "${POD_CIDR}"
        }
      ]
    ],
    "routes": [
      {
        "dst": "0.0.0.0/0"
      }
    ]
  }
}
EOF

  echo "writing /etc/cni/net.d/99-loopback.conf"
  cat <<EOF >/etc/cni/net.d/99-loopback.conf
{
  "cniVersion": "0.3.1",
  "type": "loopback"
}
EOF
}

install_containerd() {
  echo "creating directories for containerd"
  mkdir -p  /etc/containerd \
            /opt/containerd \
            /var/lib/containerd \
            /var/run/containerd

  echo "writing /etc/containerd/config.toml"
  cat <<EOF >/etc/containerd/config.toml
root = "/var/lib/containerd"
state = "/var/run/containerd"
subreaper = true

[grpc]
  address = "/var/run/containerd/containerd.sock"
  uid = 0
  gid = 0

[plugins]
  [plugins.opt]
    path = "/opt/containerd"
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/opt/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/opt/bin/runsc"
      runtime_root = "/var/run/containerd/runsc"
EOF

  echo "writing /etc/systemd/system/containerd.service"
  cat <<EOF >/etc/systemd/system/containerd.service
[Unit]
Description=containerd.service
Documentation=https://containerd.io
After=network-online.target
Wants=network-online.target

[Install]
WantedBy=multi-user.target

[Service]
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
WorkingDirectory=/var/lib/containerd
EnvironmentFile=/etc/default/path
ExecStartPre=/usr/sbin/modprobe overlay
ExecStart=/opt/bin/containerd
EOF

  echo "enabling containerd service"
  systemctl -l enable containerd.service || \
    { error "failed to enable containerd.service"; return; }

  echo "starting containerd service"
  systemctl -l start containerd.service || \
    { error "failed to start containerd.service"; return; }
}

install_cloud_provider() {
  { [ -z "${CLOUD_PROVIDER}" ] || [ -z "${CLOUD_CONFIG}" ]; } && return
  mkdir -p /var/lib/kubernetes/
  CLOUD_PROVIDER_OPTS=" --cloud-provider='${CLOUD_PROVIDER}' --cloud-config=/var/lib/kubernetes/cloud-provider.config"
  echo "${CLOUD_CONFIG}" | base64 -d | gzip -d >/var/lib/kubernetes/cloud-provider.config
}

install_kube_apiserver() {
  echo "installing kube-apiserver"

  cat <<EOF > /etc/default/kube-apiserver
# Copied from http://bit.ly/2niZlvx

APISERVER_OPTS="--advertise-address=${IPV4_ADDRESS} \\
--allow-privileged=true \\
--apiserver-count=${NUM_CONTROLLERS} \\
--audit-log-maxage=30 \\
--audit-log-maxbackup=3 \\
--audit-log-maxsize=100 \\
--audit-log-path=/var/log/audit.log \\
--authorization-mode=Node,RBAC \\
--bind-address=0.0.0.0${CLOUD_PROVIDER_OPTS} \\
--client-ca-file=/etc/ssl/ca.crt \\
--enable-admission-plugins='Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota' \\
--enable-swagger-ui=true \\
--etcd-cafile=/etc/ssl/ca.crt \\
--etcd-certfile=/etc/ssl/etcd.crt \
--etcd-keyfile=/etc/ssl/etcd.key \\
--etcd-servers='${ETCD_CLIENT_ENDPOINTS}' \\
--event-ttl=1h \\
--experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
--kubelet-certificate-authority=/etc/ssl/ca.crt \\
--kubelet-client-certificate=/etc/ssl/kube-apiserver.crt \\
--kubelet-client-key=/etc/ssl/kube-apiserver.key \\
--kubelet-https=true \\
--runtime-config=api/all \\
--secure-port=${SECURE_PORT} \\
--service-account-key-file=/etc/ssl/k8s-service-accounts.key \\
--service-cluster-ip-range='${SERVICE_CIDR}' \\
--service-node-port-range=30000-32767 \\
--tls-cert-file=/etc/ssl/kube-apiserver.crt \\
--tls-private-key-file=/etc/ssl/kube-apiserver.key \\
--v=2"
EOF

  cat <<EOF > /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Requires=etcd.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-apiserver
EnvironmentFile=/etc/default/kube-apiserver
ExecStart=/opt/bin/kube-apiserver \$APISERVER_OPTS
EOF

  echo "enabling kube-apiserver.service"
  systemctl -l enable kube-apiserver.service || \
    { error "failed to enable kube-apiserver.service"; return; }

  echo "starting kube-apiserver.service"
  systemctl -l start kube-apiserver.service || \
    { error "failed to start kube-apiserver.service"; return; }
}

install_kube_controller_manager() {
  echo "installing kube-controller-manager"

  cat <<EOF >/etc/default/kube-controller-manager
CONTROLLER_OPTS="--address=0.0.0.0${CLOUD_PROVIDER_OPTS} \\
--cluster-cidr='${CLUSTER_CIDR}' \\
--cluster-name='${SERVICE_NAME}' \\
--cluster-signing-cert-file=/etc/ssl/ca.crt \\
--cluster-signing-key-file=/etc/ssl/ca.key \\
--kubeconfig=/var/lib/kube-controller-manager/kubeconfig \\
--leader-elect=true \\
--root-ca-file=/etc/ssl/ca.crt \\
--service-account-private-key-file=/etc/ssl/k8s-service-accounts.key \\
--service-cluster-ip-range='${SERVICE_CIDR}' \\
--use-service-account-credentials=true \\
--v=2"
EOF

  cat <<EOF >/etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes
After=kube-apiserver.service
Requires=kube-apiserver.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-controller-manager
EnvironmentFile=/etc/default/kube-controller-manager
ExecStart=/opt/bin/kube-controller-manager \$CONTROLLER_OPTS
EOF

  echo "enabling kube-controller-manager.service"
  systemctl -l enable kube-controller-manager.service || \
    { error "failed to enable kube-controller-manager.service"; return; }

  echo "starting kube-controller-manager.service"
  systemctl -l start kube-controller-manager.service || \
    { error "failed to start kube-controller-manager.service"; return; }
}

install_kube_scheduler() {
  echo "installing kube-scheduler"

  cat <<EOF > /var/lib/kube-scheduler/kube-scheduler-config.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: /var/lib/kube-scheduler/kubeconfig
leaderElection:
  leaderElect: true
EOF

  cat <<EOF > /etc/default/kube-scheduler
SCHEDULER_OPTS="--config=/var/lib/kube-scheduler/kube-scheduler-config.yaml --v=2"
EOF

  cat <<EOF > /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes
After=kube-apiserver.service
Requires=kube-apiserver.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-scheduler
EnvironmentFile=/etc/default/kube-scheduler
ExecStart=/opt/bin/kube-scheduler \$SCHEDULER_OPTS
EOF

  echo "enabling kube-scheduler.service"
  systemctl -l enable kube-scheduler.service || \
    { error "failed to enable kube-scheduler.service"; return; }

  echo "starting kube-scheduler.service"
  systemctl -l start kube-scheduler.service || \
    { error "failed to start kube-scheduler.service"; return; }
}

install_kubelet() {
  echo "installing kubelet"

  cat <<EOF > /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: /etc/ssl/ca.crt
authorization:
  mode: Webhook
clusterDomain: ${SERVICE_DOMAIN}
clusterDNS:
  - ${SERVICE_DNS_IPV4_ADDRESS}
podCIDR: ${POD_CIDR}
runtimeRequestTimeout: 15m
tlsCertFile: /etc/ssl/kubelet.crt
tlsPrivateKeyFile: /etc/ssl/kubelet.key
EOF

  cat <<EOF >/etc/default/kubelet
KUBELET_OPTS="--client-ca-file=/etc/ssl/ca.crt${CLOUD_PROVIDER_OPTS} \\
--cluster-domain='${SERVICE_DOMAIN}' \\
--cluster-dns='${SERVICE_DNS_IPV4_ADDRESS}' \\
--cni-bin-dir=/opt/bin/cni \\
--config=/var/lib/kubelet/kubelet-config.yaml \\
--container-runtime=remote \
--container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
--image-pull-progress-deadline=2m \\
--kubeconfig=/var/lib/kubelet/kubeconfig \\
--network-plugin=cni \\
--node-ip=${IPV4_ADDRESS} \\
--register-node=true \\
--tls-cert-file=/etc/ssl/kubelet.crt \\
--tls-private-key-file=/etc/ssl/kubelet.key \\
--v=2"
EOF

  cat <<EOF >/etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=/etc/default/path
EnvironmentFile=/etc/default/kubelet
ExecStart=/opt/bin/kubelet \$KUBELET_OPTS
EOF

  echo "enabling kubelet.service"
  systemctl -l enable kubelet.service || \
    { error "failed to enable kubelet.service"; return; }

  echo "starting kubelet.service"
  systemctl -l start kubelet.service || \
    { error "failed to start kubelet.service"; return; }
}

install_kube_proxy() {
  echo "installing kube-proxy"

  cat <<EOF > /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${CLUSTER_CIDR}"
EOF

  cat <<EOF >/etc/default/kube-proxy
KUBE_PROXY_OPTS="--config=/var/lib/kube-proxy/kube-proxy-config.yaml"
EOF

  cat <<EOF >/etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes
After=kubelet.service
Requires=kubelet.service

[Install]
WantedBy=multi-user.target

[Service]
Restart=on-failure
RestartSec=5
WorkingDirectory=/var/lib/kube-proxy
EnvironmentFile=/etc/default/kube-proxy
ExecStart=/opt/bin/kube-proxy \$KUBE_PROXY_OPTS
EOF

  echo "enabling kube-proxy.service"
  systemctl -l enable kube-proxy.service || \
    { error "failed to enable kube-proxy.service"; return; }

  echo "starting kube-proxy.service"
  systemctl -l start kube-proxy.service || \
    { error "failed to start kube-proxy.service"; return; }
}

fetch_tls() {
  etcdctl get --print-value-only "${1}" > "${3}" || \
    { error "failed to write '${1}' to '${3}'"; return; }
  etcdctl get --print-value-only "${2}" > "${4}" || \
    { error "failed to write '${2}' to '${4}'"; return; }
  { chmod 0444 "${3}" && chmod 0400 "${4}"; } || \
    { error "failed to chmod '${3}' & '${4}'"; return; }
  { chown root:root "${3}" "${4}"; } || \
    { error "failed to chown '${3}' & '${4}'"; return; }
}

fetch_kubeconfig() {
  etcdctl get --print-value-only "${1}" > "${2}" || \
    { error "failed to write '${1}' to '${2}'"; return; }
  chmod 0400 "${2}" || { error "failed to chmod '${2}'"; return; } 
  chown root:root "${2}" || { error "failed to chown '${2}'"; return; } 
}

# Generates or fetches assets that are shared between multiple 
# controller/worker nodes.
generate_or_fetch_shared_kubernetes_assets() {
  # The key prefix for shared assets.
  shared_assets_prefix="/kubeeve/shared"

  # Stores the name of the node that generates the shared assets.
  init_node_key="${shared_assets_prefix}/init-node"

  # The keys for the cert/key pairs.
  shared_tls_prefix="${shared_assets_prefix}/tls"
  shared_tls_apiserver_crt_key="${shared_tls_prefix}/kube-apiserver.crt"
  shared_tls_apiserver_key_key="${shared_tls_prefix}/kube-apiserver.key"
  shared_tls_svc_accts_crt_key="${shared_tls_prefix}/service-accounts.crt"
  shared_tls_svc_accts_key_key="${shared_tls_prefix}/service-accounts.key"
  shared_tls_kube_proxy_crt_key="${shared_tls_prefix}/kube-proxy.crt"
  shared_tls_kube_proxy_key_key="${shared_tls_prefix}/kube-proxy.key"

  # The key for the encryption key.
  shared_enc_key_key="${shared_assets_prefix}/encryption.key"

  # The keys for the kubeconfigs.
  shared_kfg_prefix="${shared_assets_prefix}/kfg"
  shared_kfg_admin_key="${shared_kfg_prefix}/k8s-admin"
  shared_kfg_controller_manager_key="${shared_kfg_prefix}/kube-controller-manager"
  shared_kfg_scheduler_key="${shared_kfg_prefix}/kube-scheduler"
  shared_kfg_kube_proxy_key="${shared_kfg_prefix}/kube-proxy"

  # Create the directories where the shared assets are generated or into
  # which the shared assets are fetched.
  mkdir -p /var/lib/kubernetes \
           /var/lib/kube-apiserver \
           /var/lib/kube-controller-manager \
           /var/lib/kube-scheduler \
           /var/lib/kube-proxy

  # Check to see if the init routine has already run on another node.
  name_of_init_node=$(etcdctl get --print-value-only "${init_node_key}") || \
    { error "failed to get name of init node"; return; }

  if [ -n "${name_of_init_node}" ]; then
    echo "shared assets already generated on ${name_of_init_node}"

    # Fetch shared controller assets.
    if [ ! "${NODE_TYPE}" = "worker" ]; then
      echo "fetching shared kube-apiserver cert/key pair"
      fetch_tls "${shared_tls_apiserver_crt_key}" \
                "${shared_tls_apiserver_key_key}" \
                /etc/ssl/kube-apiserver.crt \
                /etc/ssl/kube-apiserver.key || \
        { error "failed to fetch shared kube-apiserver cert/key pair"; return; }

      echo "fetching shared service accounts cert/key pair"
      fetch_tls "${shared_tls_svc_accts_crt_key}" \
                "${shared_tls_svc_accts_key_key}" \
                /etc/ssl/k8s-service-accounts.crt \
                /etc/ssl/k8s-service-accounts.key || \
        { error "failed to fetch shared service accounts cert/key pair"; return; }

      echo "fetching shared k8s-admin kubeconfig"
      fetch_kubeconfig "${shared_kfg_admin_key}" \
                       /var/lib/kubernetes/kubeconfig || \
        { error "failed to fetch shared k8s-admin kubeconfig"; return; }

      # Grant access to the admin kubeconfig to users belonging to the
      # "k8s-admin" group.
      chmod 0440 /var/lib/kubernetes/kubeconfig || \
        { error "failed to chmod /var/lib/kubernetes/kubeconfig"; return; }
      chown root:k8s-admin /var/lib/kubernetes/kubeconfig || \
        { error "failed to chown /var/lib/kubernetes/kubeconfig"; return; }

      echo "fetching shared kube-controller-manager kubeconfig"
      fetch_kubeconfig "${shared_kfg_controller_manager_key}" \
                       /var/lib/kube-controller-manager/kubeconfig || \
        { error "failed to fetch shared kube-controller-manager kubeconfig"; return; }
      
      echo "fetching shared kube-scheduler kubeconfig"
      fetch_kubeconfig "${shared_kfg_scheduler_key}" \
                       /var/lib/kube-scheduler/kubeconfig || \
        { error "failed to fetch shared kube-scheduler kubeconfig"; return; }

      echo "fetching shared encryption key"
      etcdctl get "${shared_enc_key_key}" --print-value-only > \
        /var/lib/kubernetes/encryption-config.yaml || \
        { error "failed to fetch shared encryption key"; return; }
    fi

    # Fetch shared worker assets.
    if [ ! "${NODE_TYPE}" = "controller" ]; then

      echo "fetching shared kube-proxy cert/key pair"
      fetch_tls "${shared_tls_kube_proxy_crt_key}" \
                "${shared_tls_kube_proxy_key_key}" \
                /etc/ssl/kube-proxy.crt \
                /etc/ssl/kube-proxy.key || \
        { error "failed to fetch shared kube-proxy cert/key pair"; return; }

      echo "fetching shared kube-proxy kubeconfig"
      fetch_kubeconfig "${shared_kfg_kube_proxy_key}" \
                       /var/lib/kube-proxy/kubeconfig || \
        { error "failed to fetch shared kube-proxy kubeconfig"; return; }

    fi

    echo "fetched all shared assets" && return
  fi

  # At this point the lock has been obtained and it's known that no other
  # node has run the initialization routine.

  # Indicate that the init process is running on this node.
  etcdctl put "${init_node_key}" "${HOST_FQDN}" || \
    { error "failed to put ${init_node_key}=${HOST_FQDN}"; return; }

  echo "generating shared kube-apiserver x509 cert/key pair"
  (TLS_KEY_OUT=/etc/ssl/kube-apiserver.key \
    TLS_CRT_OUT=/etc/ssl/kube-apiserver.crt \
    TLS_SAN_IP="127.0.0.1 ${SERVICE_IPV4_ADDRESS} ${CONTROLLER_IPV4_ADDRESSES}" \
    TLS_SAN_DNS="localhost ${CLUSTER_FQDN} ${SERVICE_FQDN} ${SERVICE_NAME}.default" \
    TLS_COMMON_NAME="${CLUSTER_ADMIN}" \
    new_cert) || \
    { error "failed to generate shared kube-apiserver x509 cert/key pair"; return; }

  echo "generating shared k8s-admin x509 cert/key pair"
  (TLS_KEY_OUT=/etc/ssl/k8s-admin.key \
    TLS_CRT_OUT=/etc/ssl/k8s-admin.crt \
    TLS_SAN=false \
    TLS_ORG_NAME="system:masters" \
    TLS_COMMON_NAME="admin" \
    new_cert) || \
    { error "failed to generate shared k8s-admin x509 cert/key pair"; return; }

  echo "generating shared kube-controller-manager x509 cert/key pair"
  (TLS_KEY_OUT=/etc/ssl/kube-controller-manager.key \
    TLS_CRT_OUT=/etc/ssl/kube-controller-manager.crt \
    TLS_SAN=false \
    TLS_ORG_NAME="system:kube-controller-manager" \
    TLS_COMMON_NAME="system:kube-controller-manager" \
    new_cert) || \
    { error "failed to generate shared kube-controller-manager x509 cert/key pair"; return; }

  echo "generating shared kube-scheduler x509 cert/key pair"
  (TLS_KEY_OUT=/etc/ssl/kube-scheduler.key \
    TLS_CRT_OUT=/etc/ssl/kube-scheduler.crt \
    TLS_SAN=false \
    TLS_ORG_NAME="system:kube-scheduler" \
    TLS_COMMON_NAME="system:kube-scheduler" \
    new_cert) || \
    { error "failed to generate shared kube-scheduler x509 cert/key pair"; return; }

  echo "generating shared k8s-service-accounts x509 cert/key pair"
  (TLS_KEY_OUT=/etc/ssl/k8s-service-accounts.key \
    TLS_CRT_OUT=/etc/ssl/k8s-service-accounts.crt \
    TLS_SAN=false \
    TLS_COMMON_NAME="service-accounts" \
    new_cert) || \
    { error "failed to generate shared k8s-service-accounts x509 cert/key pair"; return; }

  echo "generating shared kube-proxy x509 cert/key pair"
  (TLS_KEY_OUT=/etc/ssl/kube-proxy.key \
    TLS_CRT_OUT=/etc/ssl/kube-proxy.crt \
    TLS_SAN=false \
    TLS_ORG_NAME="system:node-proxier" \
    TLS_COMMON_NAME="system:kube-proxy" \
    new_cert) || \
    { error "failed to generate shared kube-proxy x509 cert/key pair"; return; }

  echo "generating shared k8s-admin kubeconfig"
  (KFG_FILE_PATH=/var/lib/kubernetes/kubeconfig \
    KFG_USER=admin \
    KFG_TLS_CRT=/etc/ssl/k8s-admin.crt \
    KFG_TLS_KEY=/etc/ssl/k8s-admin.key \
    KFG_GID=k8s-admin \
    KFG_PERM=0440 \
    KFG_SERVER="https://127.0.0.1:${SECURE_PORT}" \
    new_kubeconfig) || \
    { error "failed to generate shared kube-proxy kubeconfig"; return; }

  echo "generating shared kube-scheduler kubeconfig"
  (KFG_FILE_PATH=/var/lib/kube-scheduler/kubeconfig \
    KFG_USER="system:kube-scheduler" \
    KFG_TLS_CRT=/etc/ssl/kube-scheduler.crt \
    KFG_TLS_KEY=/etc/ssl/kube-scheduler.key \
    KFG_SERVER="https://127.0.0.1:${SECURE_PORT}" \
    new_kubeconfig) || \
    { error "failed to generate shared kube-proxy kubeconfig"; return; }

  echo "generating shared kube-controller-manager kubeconfig"
  (KFG_FILE_PATH=/var/lib/kube-controller-manager/kubeconfig \
    KFG_USER="system:kube-controller-manager" \
    KFG_TLS_CRT=/etc/ssl/kube-controller-manager.crt \
    KFG_TLS_KEY=/etc/ssl/kube-controller-manager.key \
    KFG_SERVER="https://127.0.0.1:${SECURE_PORT}" \
    new_kubeconfig) || \
    { error "failed to generate shared kube-proxy kubeconfig"; return; }

  echo "generating shared kube-proxy kubeconfig"
  (KFG_FILE_PATH=/var/lib/kube-proxy/kubeconfig \
    KFG_USER="system:kube-proxy" \
    KFG_TLS_CRT=/etc/ssl/kube-proxy.crt \
    KFG_TLS_KEY=/etc/ssl/kube-proxy.key \
    new_kubeconfig) || \
    { error "failed to generate shared kube-proxy kubeconfig"; return; }

  echo "generating shared encryption-config"
  cat <<EOF >/var/lib/kubernetes/encryption-config.yaml
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

  # Store the cert/key pairs on the etcd server.
  put_file "${shared_tls_apiserver_crt_key}"  /etc/ssl/kube-apiserver.crt || return
  put_file "${shared_tls_apiserver_key_key}"  /etc/ssl/kube-apiserver.key || return
  put_file "${shared_tls_svc_accts_crt_key}"  /etc/ssl/k8s-service-accounts.crt || return
  put_file "${shared_tls_svc_accts_key_key}"  /etc/ssl/k8s-service-accounts.key || return
  put_file "${shared_tls_kube_proxy_crt_key}" /etc/ssl/kube-proxy.crt || return
  put_file "${shared_tls_kube_proxy_key_key}" /etc/ssl/kube-proxy.key || return

  # Store the kubeconfigs on the etcd server.
  put_file "${shared_kfg_admin_key}"              /var/lib/kubernetes/kubeconfig || return
  put_file "${shared_kfg_controller_manager_key}" /var/lib/kube-controller-manager/kubeconfig || return
  put_file "${shared_kfg_scheduler_key}"          /var/lib/kube-scheduler/kubeconfig || return
  put_file "${shared_kfg_kube_proxy_key}"         /var/lib/kube-proxy/kubeconfig || return

  # Store the encryption key on the etcd server.
  put_file "${shared_enc_key_key}" /var/lib/kubernetes/encryption-config.yaml || return

  # Remove the certificates that are no longer needed once the kubeconfigs
  # have been generated.
  if [ "${NODE_TYPE}" = "controller" ]; then
    rm -fr /var/lib/kube-proxy
    rm -f  /etc/ssl/kube-proxy.*
  elif [ "${NODE_TYPE}" = "worker" ]; then
    rm -fr /var/lib/kube-apiserver
    rm -fr /var/lib/kube-controller-manager
    rm -fr /var/lib/kube-scheduler
    rm -f  /var/lib/kubernetes/kubeconfig
    rm -f  /var/lib/kubernetes/encryption-config.yaml
  fi
  rm -f /etc/ssl/k8s-admin.*
  rm -f /etc/ssl/kube-controller-manager.*
  rm -f /etc/ssl/kube-scheduler.*
}

wait_until_kube_apiserver_is_online() {
  retry_until_0 \
    "try to connect to cluster with kubectl" \
    kubectl get cs || return
  retry_until_0 \
    "ensure that the kube-system namespaces exists" \
    kubectl get namespace kube-system || return
  retry_until_0 \
    "ensure that ClusterRoles are available" \
    kubectl get ClusterRole.v1.rbac.authorization.k8s.io || return
  retry_until_0 \
    "ensure that ClusterRoleBindings are available" \
    kubectl get ClusterRoleBinding.v1.rbac.authorization.k8s.io || return
}

# Configures kubernetes to use RBAC.
configure_k8s_rbac() {
  [ "${NODE_TYPE}" = "worker" ] && return

  echo "configuring kubernetes RBAC"

  # Stores the name of the node that configures rbac.
  init_rbac_key="/kubeeve/init-rbac"

  # Check to see if the init routine has already run on another node.
  name_of_init_node=$(etcdctl get --print-value-only "${init_rbac_key}") || \
    { error "failed to get name of init node for kubernetes RBAC"; return; }

  if [ -n "${name_of_init_node}" ]; then
    echo "kubernetes RBAC has already been configured from node ${name_of_init_node}"
    return
  fi

  # Let other nodes know that this node has configured RBAC.
  put_string "${init_rbac_key}" "${HOST_FQDN}" || \
    { error "error configuring kubernetes RBAC"; return; }

  # Create the system:kube-apiserver-to-kubelet ClusterRole with 
  # permissions to access the Kubelet API and perform most common tasks 
  # associated with managing pods.
  cat <<EOF >/var/lib/kubernetes/create-cluster-role.yaml
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

  echo "configure kubernetes RBAC - creating ClusterRole"
  kubectl apply -f /var/lib/kubernetes/create-cluster-role.yaml || \
    { error "failed to configure kubernetes RBAC - create ClusterRole"; return; }

  # Bind the system:kube-apiserver-to-kubelet ClusterRole to the 
  # kubernetes user:
cat <<EOF >/var/lib/kubernetes/bind-cluster-role.yaml
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

  echo "configure kubernetes RBAC - binding ClusterRole"
  kubectl apply -f /var/lib/kubernetes/bind-cluster-role.yaml || \
    { error "failed to configure kubernetes RBAC - bind ClusterRole"; return; }

  echo "kubernetes RBAC has been configured"
}

# Configures kubernetes to use CoreDNS for service DNS resolution.
configure_k8s_dns() {
  [ "${NODE_TYPE}" = "worker" ] && return

  echo "configuring kubernetes service DNS"

  # Stores the name of the node that configures service DNS.
  init_svc_dns_key="/kubeeve/init-service-dns"

  # Check to see if the init routine has already run on another node.
  name_of_init_node=$(etcdctl get --print-value-only "${init_svc_dns_key}") || \
    { error "failed to get name of init node for kubernetes service DNS"; return; }

  if [ -n "${name_of_init_node}" ]; then
    echo "kubernetes service DNS has already been configured from node ${name_of_init_node}"
    return
  fi

  # Let other nodes know that this node has configured service DNS.
  put_string "${init_svc_dns_key}" "${HOST_FQDN}" || 
    { error "error configuring kubernetes service DNS"; return; }

  # Reverse the service CIDR and remove the subnet notation so the
  # value can be used as for reverse DNS lookup.
  rev_service_cidr="$(reverse_ipv4_address "${SERVICE_CIDR}")"
  ipv4_inaddr_arpa="${rev_service_cidr}.in-addr.arpa"
  echo "service dns ipv4 inaddr arpa=${ipv4_inaddr_arpa}"

  # Write the podspec to disk.
  echo "writing service DNS podspec=/var/lib/kubernetes/coredns-podspec.yaml"
  cat <<EOF >/var/lib/kubernetes/coredns-podspec.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: coredns
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
rules:
- apiGroups:
  - ""
  resources:
  - endpoints
  - services
  - pods
  - namespaces
  verbs:
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:coredns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:coredns
subjects:
- kind: ServiceAccount
  name: coredns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health
        kubernetes ${SERVICE_DOMAIN} ${ipv4_inaddr_arpa} ip6.arpa {
          pods insecure
          upstream
          fallthrough ${ipv4_inaddr_arpa} ip6.arpa
        }
        prometheus :9153
        proxy . /etc/resolv.conf
        cache 30
        loop
        reload
        loadbalance
    }
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: coredns
  namespace: kube-system
  labels:
    k8s-app: kube-dns
    kubernetes.io/name: "CoreDNS"
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      k8s-app: kube-dns
  template:
    metadata:
      labels:
        k8s-app: kube-dns
    spec:
      serviceAccountName: coredns
      tolerations:
        - key: node-role.kubernetes.io/master
          effect: NoSchedule
        - key: "CriticalAddonsOnly"
          operator: "Exists"
      containers:
      - name: coredns
        image: coredns/coredns:1.2.2
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            memory: 170Mi
          requests:
            cpu: 100m
            memory: 70Mi
        args: [ "-conf", "/etc/coredns/Corefile" ]
        volumeMounts:
        - name: config-volume
          mountPath: /etc/coredns
          readOnly: true
        ports:
        - containerPort: 53
          name: dns
          protocol: UDP
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 9153
          name: metrics
          protocol: TCP
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            add:
            - NET_BIND_SERVICE
            drop:
            - all
          readOnlyRootFilesystem: true
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
            scheme: HTTP
          initialDelaySeconds: 60
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
      dnsPolicy: Default
      volumes:
        - name: config-volume
          configMap:
            name: coredns
            items:
            - key: Corefile
              path: Corefile
---
apiVersion: v1
kind: Service
metadata:
  name: kube-dns
  namespace: kube-system
  annotations:
    prometheus.io/port: "9153"
    prometheus.io/scrape: "true"
  labels:
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "CoreDNS"
spec:
  selector:
    k8s-app: kube-dns
  clusterIP: ${SERVICE_DNS_IPV4_ADDRESS}
  ports:
  - name: dns
    port: 53
    protocol: UDP
  - name: dns-tcp
    port: 53
    protocol: TCP
EOF

  # Deploy a podspec that uses CoreDNS for service DNS resolution.
  kubectl create -f /var/lib/kubernetes/coredns-podspec.yaml || \
    { error "failed to configure kubernetes service DNS - deploy CoreDNS"; return; }

  echo "configured kubernetes service DNS to use CoreDNS"
}

create_k8s_admin_group() {
  getent group k8s-admin >/dev/null 2>&1 || groupadd k8s-admin
}

wait_for_healthy_kubernetes_cluster() {
  echo "waiting until the kubernetes control plane is online"
  # Wait until the kubernetes health check reports "ok". After 100 failed 
  # attempts over 5 minutes the script will exit with an error.
  i=1 && while true; do
    if [ "${i}" -gt 100 ]; then
      error "timed out waiting for a healthy kubernetes cluster" 1; return
    fi
    echo "control plane health check attempt: ${i}"
    response=$(${CURL} -sSL "http://${CLUSTER_FQDN}/healthz")
    [ "${response}" = "ok" ] && break
    sleep 3
    i=$((i+1))
  done
  echo "kubernetes cluster is healthy"
}

install_kube_apiserver_and_wait_until_its_online() {
  install_kube_apiserver || \
    { error "failed to install kube-apiserver"; return; }

  wait_until_kube_apiserver_is_online || \
    { error "error waiting until kube-apiserver is online"; return; }
}

install_kubernetes() {
  echo "installing kubernetes"

  echo "installing the cloud provider"
  install_cloud_provider || \
    { error "failed to install cloud provider"; return; }

  echo "generating or fetching shared kubernetes assets"
  do_with_lock generate_or_fetch_shared_kubernetes_assets || \
    { error "failed to generate or fetch shared kubernetes assets"; return; }

  # If the node isn't explicitly a worker then install the controller bits.
  if [ ! "${NODE_TYPE}" = "worker" ]; then
    echo "installing kubernetes control plane"

    # The rest of this process will be able to use the exported KUBECONFIG.
    export KUBECONFIG=/var/lib/kubernetes/kubeconfig

    # Create a shell profile script so that logged-in users will have
    # KUBECONFIG set to /var/lib/kubernetes/kubeconfig if the user is
    # root or belongs to the k8s-admin group.
    cat <<EOF >/etc/profile.d/k8s-admin.sh
#!/bin/sh
# Set the KUBECONFIG environment variable to point to the admin
# kubeconfig file if the current user is root or belongs to the 
# k8s-admin group.
id | grep -q 'uid=0\\|k8s-admin' && \\
  export KUBECONFIG=/var/lib/kubernetes/kubeconfig
EOF

    echo "creating directories for kubernetes control plane"
    mkdir -p  /var/lib/kubernetes \
              /var/lib/kube-apiserver \
              /var/lib/kube-controller-manager \
              /var/lib/kube-scheduler

    # Installation of the kube-apiserver and waiting until it's online
    # is synchronized in order to keep two control plane nodes from trying
    # to write to etcd at once. When this happens, sometimes one or more
    # of the kube-apiserver processes crash.
    #
    # Please see https://github.com/kubernetes/kubernetes/issues/67367
    # for more information.
    do_with_lock install_kube_apiserver_and_wait_until_its_online || return

    # Configure kubernetes to use RBAC.
    do_with_lock configure_k8s_rbac || \
      { error "failed to configure rbac for kubernetes"; return; }

    # Wait until RBAC is configured to install kube-controller-manager
    # and kube-scheduler.
    install_kube_controller_manager || \
      { error "failed to install kube-controller-manager"; return; }
    install_kube_scheduler || \
      { error "failed to install kube-scheduler"; return; }

    # Deploy CoreDNS to kubernetes for kubernetes service DNS resolution.
    do_with_lock configure_k8s_dns || \
      { error "failed to configure CoreDNS for kubernetes"; return; }
  fi

  # If the node isn't explicitly a controller then install the worker bits.
  if [ ! "${NODE_TYPE}" = "controller" ]; then
    echo "installing kubernetes worker components"

    echo "creating directories for kubernetes worker"
    mkdir -p  /var/lib/kubernetes \
              /var/lib/kubelet \
              /var/lib/kube-proxy

    echo "generating kubelet x509 cert/key pair"
    (TLS_KEY_OUT=/etc/ssl/kubelet.key \
      TLS_CRT_OUT=/etc/ssl/kubelet.crt \
      TLS_ORG_NAME="system:nodes" \
      TLS_COMMON_NAME="system:node:${HOST_FQDN}" \
      new_cert) || \
      { error "failed to generate kubelet x509 cert/key pair"; return; }

    echo "generating kubelet kubeconfig"
    (KFG_FILE_PATH=/var/lib/kubelet/kubeconfig \
      KFG_USER="system:node:${HOST_FQDN}" \
      KFG_TLS_CRT=/etc/ssl/kubelet.crt \
      KFG_TLS_KEY=/etc/ssl/kubelet.key \
      new_kubeconfig) || \
      { error "failed to generate kubelet kubeconfig"; return; }

    # Do not start the kubelet until the kubernetes cluster is reporting
    # as healthy.
    wait_for_healthy_kubernetes_cluster || \
      { error "failed while waiting for healthy kubernetes cluster"; return; }

    install_kubelet || \
      { error "failed to install kubelet"; return; }
    install_kube_proxy || \
      { error "failed to install kube-proxy"; return; }
  fi
}

create_pod_net_routes() {
  echo "creating routes to pod nets on other nodes"

  # Create a jq expression that transforms the node info for
  # all nodes but this one into one or more "ip route add"
  # calls to add routes for pod networks on other nodes.
  jqq='.[] | select (.ipv4_address != "'"${IPV4_ADDRESS}"'") | '
  jqq="${jqq}"'"ip route add \(.pod_cidr) via \(.ipv4_address)"'

  exit_code=0

  # Save the old IFS value
  OLD_IFS="${IFS}"

  # Split on newlines so to parse the output of jq correctly.
  IFS="$(printf '%b_' '\n')"; a="${a%_}"

  # Create and execute one or several commands to add routes to
  # pod networks on other nodes.
  for r in $(etcdctl get /kubeeve/nodes \
            --print-value-only --prefix | \
            jq -rs "${jqq}"); do
    echo "${r}"
    /bin/sh -c "${r}" || { exit_code="${?}" && break; }
  done
  IFS="${OLD_IFS}"
  if [ "${exit_code}" -ne "0" ]; then
    error "failed to add routes for pod network" "${exit_code}"; return
  fi
  echo "created routes for pod network"
}

download_jq() {
  JQ_URL=https://github.com/stedolan/jq/releases/download
  JQ_ARTIFACT="${JQ_URL}/jq-${JQ_VERSION}/jq-linux64"
  echo "downloading ${JQ_ARTIFACT}"
  ${CURL} -Lo "${BIN_DIR}/jq" "${JQ_ARTIFACT}" || \
    error "failed to download jq"
}

download_etcd() {
  ETCD_URL=https://github.com/etcd-io/etcd/releases/download
  ETCD_ARTIFACT="${ETCD_URL}/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
  echo "downloading ${ETCD_ARTIFACT}"
  ${CURL} -L "${ETCD_ARTIFACT}" | \
    tar --strip-components=1 --wildcards -xzvC \
    "${BIN_DIR}" '*/etcd' '*/etcdctl'
  exit_code="${?}" && \
    [ "${exit_code}" -gt "1" ] && \
    { error "failed to download etcd" "${exit_code}"; return; }
  
  # If the node is a worker then it doesn't need to install the etcd server.
  [ "${NODE_TYPE}" = "worker" ] && rm -fr "${BIN_DIR}/etcd"

  return 0
}

download_coredns() {
  COREDNS_URL=https://github.com/coredns/coredns/releases/download
  COREDNS_ARTIFACT="${COREDNS_URL}/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz"

  # Check to see if the CoreDNS artifact uses the old or new filename format.
  # The change occurred with release 1.2.2.
  if ${CURL} -I "${COREDNS_ARTIFACT}" | grep -q 'HTTP/1.1 404 Not Found'; then
    COREDNS_ARTIFACT="${COREDNS_URL}/v${COREDNS_VERSION}/release.coredns_${COREDNS_VERSION}_linux_amd64.tgz"
  fi

  echo "downloading ${COREDNS_ARTIFACT}"
  ${CURL} -L "${COREDNS_ARTIFACT}" | tar -xzvC "${BIN_DIR}" || \
    error "failed to download coredns"
}

init_kubernetes_artifact_prefix() {
  # Determine if the version points to a release or a CI build.
  K8S_URL=https://storage.googleapis.com/kubernetes-release

  # If the version does *not* begin with release/ then it's a dev version.
  if ! echo "${K8S_VERSION}" | grep '^release/' >/dev/null 2>&1; then
    K8S_URL=${K8S_URL}-dev
  fi

  # If the version is ci/latest, release/latest, or release/stable then 
  # append .txt to the version string so the next if block gets triggered.
  if echo "${K8S_VERSION}" | \
    grep '^\(ci/latest\)\|\(release/\(latest\|stable\)\)$' >/dev/null 2>&1; then
    K8S_VERSION="${K8S_VERSION}.txt"
  fi

  # If the version points to a .txt file then its *that* file that contains
  # the actual version information.
  if echo "${K8S_VERSION}" | grep '\.txt$' >/dev/null 2>&1; then
    K8S_REAL_VERSION=$(${CURL} -sL "${K8S_URL}/${K8S_VERSION}")
    K8S_VERSION_PREFIX=$(echo "${K8S_VERSION}" | awk -F/ '{print $1}')
    K8S_VERSION=${K8S_VERSION_PREFIX}/${K8S_REAL_VERSION}
  fi

  # Init the kubernetes artifact URL prefix.
  K8S_ARTIFACT_PREFIX=${K8S_URL}/${K8S_VERSION}
}

download_kubernetes_node() {
  K8S_ARTIFACT="${K8S_ARTIFACT_PREFIX}/kubernetes-node-linux-amd64.tar.gz"
  echo "downloading ${K8S_ARTIFACT}"
  ${CURL} -L "${K8S_ARTIFACT}" | \
      tar --strip-components=3 --wildcards -xzvC "${BIN_DIR}" \
      --exclude=kubernetes/node/bin/*.tar \
      --exclude=kubernetes/node/bin/*.docker_tag \
      'kubernetes/node/bin/*'
  exit_code="${?}" && \
    [ "${exit_code}" -gt "1" ] && \
    { error "failed to download kubernetes node" "${exit_code}"; return; }
  return 0
}

download_kubernetes_server() {
  K8S_ARTIFACT="${K8S_ARTIFACT_PREFIX}/kubernetes-server-linux-amd64.tar.gz"
  echo "downloading ${K8S_ARTIFACT}"
  ${CURL} -L "${K8S_ARTIFACT}" | \
    tar --strip-components=3 --wildcards -xzvC "${BIN_DIR}" \
    --exclude=kubernetes/server/bin/*.tar \
    --exclude=kubernetes/server/bin/*.docker_tag \
    'kubernetes/server/bin/*'
  exit_code="${?}" && \
    [ "${exit_code}" -gt "1" ] && \
    { error "failed to download kubernetes server" "${exit_code}"; return; }
  return 0
}

download_kubernetes_test() {
  if [ ! "${RUN_CONFORMANCE_TESTS}" = "true" ]; then
    echo "skipping download_kubernetes_test" && return
  fi

  mkdir -p /var/lib/kubernetes/e2e
  K8S_ARTIFACT="${K8S_ARTIFACT_PREFIX}/kubernetes-test.tar.gz"
  echo "downloading ${K8S_ARTIFACT}"
  ${CURL} -L "${K8S_ARTIFACT}" | \
    tar --strip-components=1 -xzvC /var/lib/kubernetes/e2e
  exit_code="${?}" && \
    [ "${exit_code}" -gt "1" ] && \
    { error "failed to download kubernetes tests" "${exit_code}"; return; }
  return 0
}

download_nginx() {
  NGINX_URL=http://cnx.vmware.s3.amazonaws.com/cicd/container-linux/nginx
  NGINX_ARTIFACT="${NGINX_URL}/v${NGINX_VERSION}/nginx.tar.gz"
  echo "downloading ${NGINX_ARTIFACT}"
  ${CURL} -L "${NGINX_ARTIFACT}" | tar -xzvC "${BIN_DIR}" || \
    error "failed to download nginx"
}

download_containerd() {
  CONTAINERD_URL=https://github.com/containerd/containerd/releases/download
  CONTAINERD_ARTIFACT="${CONTAINERD_URL}/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz"
  echo "downloading ${CONTAINERD_ARTIFACT}"
  ${CURL} -L "${CONTAINERD_ARTIFACT}" | \
    tar -xzvC "${BIN_DIR}" --strip-components=1
  exit_code="${?}" && \
    [ "${exit_code}" -gt "1" ] && \
    { error "failed to download containerd" "${exit_code}"; return; }
  return 0
}

download_cni_plugins() {
  mkdir -p "${CNI_BIN_DIR}"

  CNI_PLUGINS_URL=https://github.com/containernetworking/plugins/releases/download
  CNI_PLUGINS_ARTIFACT="${CNI_PLUGINS_URL}/v${CNI_PLUGINS_VERSION}/cni-plugins-amd64-v${CNI_PLUGINS_VERSION}.tgz"
  echo "downloading ${CNI_PLUGINS_ARTIFACT}"
  ${CURL} -L "${CNI_PLUGINS_ARTIFACT}" | tar -xzvC "${CNI_BIN_DIR}" || \
    error "failed to download cni plug-ins"
}

download_crictl() {
  CRICTL_URL=https://github.com/kubernetes-incubator/cri-tools/releases/download
  CRICTL_ARTIFACT="${CRICTL_URL}/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz"
  echo "downloading ${CRICTL_ARTIFACT}"
  ${CURL} -L "${CRICTL_ARTIFACT}" | tar -xzvC "${BIN_DIR}" || \
    error "failed to download crictl"
}

download_runc() {
  RUNC_URL=https://github.com/opencontainers/runc/releases/download
  RUNC_ARTIFACT="${RUNC_URL}/v${RUNC_VERSION}/runc.amd64"
  echo "downloading ${RUNC_ARTIFACT}"
  ${CURL} -Lo "${BIN_DIR}/runc" "${RUNC_ARTIFACT}" || \
    error "failed to download runc"
}

download_runsc() {
  RUNSC_URL=https://storage.googleapis.com/gvisor/releases/nightly
  RUNSC_ARTIFACT="${RUNSC_URL}/${RUNSC_VERSION}/runsc"
  echo "downloading ${RUNSC_ARTIFACT}"
  ${CURL} -Lo "${BIN_DIR}/runsc" "${RUNSC_ARTIFACT}" || \
    error "failed to download runsc"
}

download_binaries() {
  # Download binaries found on both control-plane and worker nodes.
  download_jq   || { error "failed to download jq"; return; }
  download_etcd || { error "failed to download etcd"; return; }

  # Initialize the kubernetes artifact prefix.
  init_kubernetes_artifact_prefix || \
    { error "failed to init kubernetes artifact prefix jq"; return; }
  echo "initialized kubernetes artifact prefix=${K8S_ARTIFACT_PREFIX}"

  # Download binaries found only on control-plane nodes.
  if [ ! "${NODE_TYPE}" = "worker" ]; then
    download_kubernetes_server || { error "failed to download kubernetes server"; return; }
    download_kubernetes_test   || { error "failed to download kubernetes test"; return; }
    download_nginx             || { error "failed to download nginx"; return; }
    download_coredns           || { error "failed to download coredns"; return; }
  fi

  # Download binaries found only on worker nodes.
  if [ ! "${NODE_TYPE}" = "controller" ]; then
    download_kubernetes_node || { error "failed to download kubernetes node"; return; }
    download_containerd      || { error "failed to download containerd"; return; }
    download_crictl          || { error "failed to download crictl"; return; }
    download_runc            || { error "failed to download runc"; return; }
    download_runsc           || { error "failed to download runsc"; return; }
    download_cni_plugins     || { error "failed to download cni-plugns"; return; }
  fi

  # Mark all the files in /opt/bin directory:
  # 1. Executable
  # 2. Owned by root:root
  echo 'update perms & owner for files in /opt/bin'
  chmod 0755 -- "${BIN_DIR}"/*
  chown root:root -- "${BIN_DIR}"/*
}

# Writes /etc/profile.d/prompt.sh to provide shells with a sane prompt.
configure_prompt || fatal "failed to configure prompt"

# Download the binaries before doing almost anything else.
download_binaries || fatal "failed to download binaries"

# Creates the k8s-admin group if it does not exist.
create_k8s_admin_group || fatal "failed to create the k8s-admin group"

# Configure iptables.
configure_iptables || fatal "failed to configure iptables"

# Writes /etc/default/path and /etc/profile.d/path.sh to make a sane,
# default path accessible by services and shells.
configure_path || fatal "failed to configure path"

# If this host used NetworkManager then this step will keep NetworkManager
# from stomping on the contents of /etc/resolv.conf upon reboot.
disable_net_man_dns || fatal "failed to disable network manager dns"

# Installs the CA files to their configured locations.
install_ca_files || fatal "failed to install CA files"

# The etcd service and its certificates are only applicable on nodes
# participating in the control plane.
if [ ! "${NODE_TYPE}" = "worker" ]; then
  # Makes the directories used by etcd, generates the certs for etcd,
  # and installs and starts the etcd service.
  install_etcd || fatal "failed to install etcd"
fi

# Uses the etcd discovery URL to wait until all members of the etcd
# cluster have joined. Then the members' IPv4 addresses are recorded
# and used later in this script.
discover_etcd_cluster_members || fatal "failed to discover etcd cluster members"

# Generates the certs for etcdctl and creates the defaults and profile
# files for etcdctl to make it easily usable by root and members of k8s-admin.
configure_etcdctl || fatal "failed to configure etcdctl"

# Records information about this node in etcd so that other nodes
# in the cluster can use the information. This function also builds
# the pod cidr for this node.
do_with_lock put_node_info || fatal "failed to put node info"

# Waits until all nodes have stored their information in etcd.
# After this step all node information should be available at
# the key prefix '/kubeeve/nodes'.
wait_on_all_node_info || fatal "failed to wait on all node info"

# Prints the information for each of the discovered nodes.
print_all_node_info || fatal "failed to print all node info"

# Creates the DNS entries in etcd that the CoreDNS servers running
# on the controller nodes will use.
create_dns_entries || fatal "failed to created DNS entries in etcd"

# CoreDNS should be installed on members of the etcd cluster.
if [ ! "${NODE_TYPE}" = "worker" ]; then
  install_coredns || fatal "failed to install CoreDNS"
fi

# DNS resolution should be handled by the CoreDNS servers installed
# on the controller nodes.
resolve_via_coredns || fatal "failed to resolve via CoreDNS"

# Waits until all the nodes can be resolved by their IP addresses.
wait_on_reverse_lookup || fatal "failed to wait on reverse lookup"

# Enable the bridge module for nodes where pod workloads are scheduled.
if [ ! "${NODE_TYPE}" = "controller" ]; then
  enable_bridge_module || fatal "failed to enable the bridge module"
fi

# Enable IP forwarding so nodes can access pod networks on other nodes.
enable_ip_forwarding || fatal "failed to enable IP forwarding"

# Ensures that this host can send traffic to any of the nodes where
# non-system pods may be scheduled.
create_pod_net_routes || fatal "failed to create pod net routes"

# If this node can schedule pod workloads then it needs CNI plug-ins
# and a container runtime.
if [ ! "${NODE_TYPE}" = "controller" ]; then
  install_cni_plugins || fatal "failed to install cni plug-ins"
  install_containerd  || fatal "failed to install containerd"
fi

# Installs kubernetes. For controller nodes this installs kube-apiserver,
# kube-controller-manager, and kube-scheduler. For worker nodes this
# installs the kubelet and kube-proxy.
install_kubernetes || fatal "failed to install kubernetes"

# nginx should be installed on control plane nodes.
if [ ! "${NODE_TYPE}" = "worker" ]; then
  install_nginx || fatal "failed to install nginx"
fi

# Unless cleanup is disabled, an attempt should be made to remove
# all of the shared assets placed on the etcd server to facilitate
# this deployment.
if [ ! "${CLEANUP_DISABLED}" = "true" ]; then
  # TODO implement cleanup
  echo "cleanup disabled"
fi

echo "So long, and thanks for all the fish."
