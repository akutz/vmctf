#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# This script is executed via the systemd service, bins.service. The
# service executes the script using the working directory into which
# the binaries are extracted.

################################################################################
##                                 etcd                                       ##
################################################################################
ETCD_URL=https://github.com/coreos/etcd/releases/download
ETCD_ARTIFACT="${ETCD_URL}/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
printf '\nfetching %s\n' "${ETCD_ARTIFACT}"
curl --retry-max-time 120 -L \
  "${ETCD_ARTIFACT}" | \
  tar --strip-components=1 --wildcards -xzvC "${BIN_DIR}" \
  '*/etcd' '*/etcdctl'

################################################################################
##                                  K8s                                       ##
################################################################################

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

printf '\nfetching %s\n' "${K8S_ARTIFACT}"
curl --retry-max-time 120 -L \
  "${K8S_ARTIFACT}" | \
  tar --strip-components=3 --wildcards -xzvC "${BIN_DIR}" \
  --exclude=kubernetes/server/bin/*.tar \
  --exclude=kubernetes/server/bin/*.docker_tag \
  'kubernetes/server/bin/*'

################################################################################
##                               CoreDNS                                      ##
################################################################################
COREDNS_URL=https://github.com/coredns/coredns/releases/download
COREDNS_ARTIFACT="${COREDNS_URL}/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz"
printf '\nfetching %s\n' "${COREDNS_ARTIFACT}"
curl --retry-max-time 120 -L "${COREDNS_ARTIFACT}" | tar -xzvC "${BIN_DIR}"

################################################################################
##                                nginx                                       ##
################################################################################
NGINX_URL=http://cnx.vmware.s3.amazonaws.com/cicd/container-linux/nginx
NGINX_ARTIFACT="${NGINX_URL}/v${NGINX_VERSION}/nginx.tar.gz"
printf '\nfetching %s\n' "${NGINX_ARTIFACT}"
curl --retry-max-time 120 -L "${NGINX_ARTIFACT}" | tar -xzvC "${BIN_DIR}"

################################################################################
##                                main()                                      ##
################################################################################
# Mark all the files in the working directory:
# 1. Executable
# 2. Owned by root:root
chmod 0755 -- "${BIN_DIR}"/*
chown root:root -- "${BIN_DIR}"/*

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"

echo "${IPV4_ADDRESS}" > /opt/ip.txt
