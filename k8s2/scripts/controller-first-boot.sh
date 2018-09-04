#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

load_defaults() {
  echo "writing /etc/default/defaults"

  hostfqdn_val=$(hostname) || exit "${?}"
  hostname_val=$(hostname -s) || exit "${?}"
  ip4addr_val=$(ip route get 1 | awk '{print $NF;exit}') || exit "${?}"
  
  find /etc/default -type f -exec sed -i \
    -e 's/{HOSTFQDN}/'"${hostfqdn_val}"'/g' \
    -e 's/{HOSTNAME}/'"${hostname_val}"'/g' \
    -e 's/{HOST_FQDN}/'"${hostfqdn_val}"'/g' \
    -e 's/{HOST_NAME}/'"${hostname_val}"'/g' \
    -e 's/{IPV4_ADDRESS}/'"${ip4addr_val}"'/g' \
    {} \;

  echo "exporting /etc/default/defaults"
  # shellcheck disable=SC1091
  { set -o allexport && . /etc/default/defaults && set +o allexport; } || \
    exit "${?}"

  find /etc/default -type f -exec sed -i \
    -e 's/{DEBUG}/'"${DEBUG}"'/g' \
    {} \;

  { cat /etc/default/defaults && echo; } || exit "${?}"
}

generate_etcd_certs() {
  echo "generating etcd certs"
  
  temp_file=$(mktemp) || exit "${?}"

  cat <<EOF > "${temp_file}"
TLS_0=etcdctl
TLS_COMMON_NAME_0="etcdctl@${HOST_FQDN}"
TLS_SAN_0=false
TLS_KEY_PERM_0=0444

TLS_1=etcd-client
TLS_COMMON_NAME_1="${HOST_FQDN}"
TLS_SAN_DNS_1="localhost ${HOST_NAME} ${HOST_FQDN} ${CLUSTER_FQDN}"
TLS_KEY_UID_1=etcd
TLS_CRT_UID_1=etcd

TLS_2=etcd-peer
TLS_COMMON_NAME_2="${HOST_FQDN}"
TLS_KEY_UID_2=etcd
TLS_CRT_UID_2=etcd
EOF

  /opt/bin/gencerts.sh "${temp_file}"
}

generate_certs() {
  echo "exporting /etc/default/gencerts"
  # shellcheck disable=SC1091
  { set -o allexport && . /etc/default/gencerts && set +o allexport; } || \
    exit "${?}"
  { cat /etc/default/gencerts && echo; } || exit "${?}"

  generate_etcd_certs || exit "${?}"
}

install_jq() {
  echo "installing jq"
  JQ_URL=https://github.com/stedolan/jq/releases/download
  JQ_ARTIFACT="${JQ_URL}/jq-${JQ_VERSION}/jq-linux64"
  printf '  fetching %s\n' "${JQ_ARTIFACT}"
  curl --retry-max-time 120 -Lo "${BIN_DIR}/jq" "${JQ_ARTIFACT}" || exit "${?}"
}

install_etcd() {
  echo "installing etcd"
  ETCD_URL=https://github.com/etcd-io/etcd/releases/download
  ETCD_ARTIFACT="${ETCD_URL}/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
  printf '  fetching %s\n' "${ETCD_ARTIFACT}"
  curl --retry-max-time 120 -L \
    "${ETCD_ARTIFACT}" | \
    tar --strip-components=1 --wildcards -xzvC "${BIN_DIR}" \
    '*/etcd' '*/etcdctl' || exit "${?}"
  
  mkdir -p /var/lib/etcd/data
  chown etcd /var/lib/etcd /var/lib/etcd/data
}

install_k8s() {
  echo "installing kubernetes"
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
    K8S_REAL_VERSION=$(curl --retry-max-time 120 -sL "${K8S_URL}/${K8S_VERSION}")
    K8S_VERSION_PREFIX=$(echo "${K8S_VERSION}" | awk -F/ '{print $1}')
    K8S_VERSION=${K8S_VERSION_PREFIX}/${K8S_REAL_VERSION}
  fi

  # Build the actual artifact URL.
  K8S_ARTIFACT=${K8S_URL}/${K8S_VERSION}/kubernetes-server-linux-amd64.tar.gz

  printf '  fetching %s\n' "${K8S_ARTIFACT}"
  curl --retry-max-time 120 -L \
    "${K8S_ARTIFACT}" | \
    tar --strip-components=3 --wildcards -xzvC "${BIN_DIR}" \
    --exclude=kubernetes/server/bin/*.tar \
    --exclude=kubernetes/server/bin/*.docker_tag \
    'kubernetes/server/bin/*' || exit "${?}"

  mkdir -p /var/lib/kubernetes \
           /var/lib/kube-apiserver \
           /var/lib/kube-controller-manager \
           /var/lib/kube-scheduler
}

install_coredns() {
  echo "installing coredns"
  COREDNS_URL=https://github.com/coredns/coredns/releases/download
  COREDNS_ARTIFACT="${COREDNS_URL}/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz"

  # Check to see if the CoreDNS artifact uses the old or new filename format.
  # The change occurred with release 1.2.2.
  if curl -I "${COREDNS_ARTIFACT}" | grep 'HTTP/1.1 404 Not Found'; then
    COREDNS_ARTIFACT="${COREDNS_URL}/v${COREDNS_VERSION}/release.coredns_${COREDNS_VERSION}_linux_amd64.tgz"
  fi

  printf '  fetching %s\n' "${COREDNS_ARTIFACT}"
  curl --retry-max-time 120 -L "${COREDNS_ARTIFACT}" | \
    tar -xzvC "${BIN_DIR}" || exit "${?}"

  mkdir -p /var/lib/coredns
  chown coredns /var/lib/coredns
}

install_nginx() {
  echo "installing nginx"
  NGINX_URL=http://cnx.vmware.s3.amazonaws.com/cicd/container-linux/nginx
  NGINX_ARTIFACT="${NGINX_URL}/v${NGINX_VERSION}/nginx.tar.gz"
  printf '  fetching %s\n' "${NGINX_ARTIFACT}"
  curl --retry-max-time 120 -L "${NGINX_ARTIFACT}" | \
    tar -xzvC "${BIN_DIR}" || exit "${?}"

  mkdir -p /var/lib/nginx /var/log/nginx
  chown nginx /var/lib/nginx /var/log/nginx
}

install_binaries() {
  echo "exporting /etc/default/bins"
  # shellcheck disable=SC1091
  . /etc/default/bins || exit "${?}"

  { cat /etc/default/bins && echo; } || exit "${?}"

  install_jq || exit "${?}"
  install_etcd || exit "${?}"
  install_coredns || exit "${?}"
  install_k8s || exit "${?}"
  install_nginx || exit "${?}"

  # Mark all the files in /opt/bin directory:
  # 1. Executable
  # 2. Owned by root:root
  echo 'update perms & owner for files in /opt/bin'
  chmod 0755 -- "${BIN_DIR}"/*
  chown root:root -- "${BIN_DIR}"/*
}

reload_iptables() {
  echo "reloading iptables"
  systemctl restart iptables ip6tables
}

reload_services() {
  echo "detecting new/changed services"
  systemctl daemon-reload
}

enable_services() {
  echo "enabling systemd services"
  find /opt/systemd -type f -exec systemctl enable {} \;
}

start_services() {
  echo "starting systemd services"
  systemctl start handle-worker-signals.service \
                  kube-init-post.service \
                  kube-controller-manager.service \
                  kube-scheduler.service
}

# Load the default configuration properties.
load_defaults || exit "${?}"

# Install all of the controller's required binaries.
install_binaries || exit "${?}"

# Generate X509 cert/key pairs.
generate_certs || exit "${?}"

# Detect new systemd unit files.
reload_services || exit "${?}"

# Pick up any new iptable rules.
reload_iptables || exit "${?}"

# Enable all of the new services.
enable_services || exit "${?}"

# Start the new services.
start_services || exit "${?}"
