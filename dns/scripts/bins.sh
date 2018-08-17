#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

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
  tar --strip-components=1 --wildcards -xzv \
  '*/etcd' '*/etcdctl'

################################################################################
##                               CoreDNS                                      ##
################################################################################
COREDNS_URL=https://github.com/coredns/coredns/releases/download
COREDNS_ARTIFACT="${COREDNS_URL}/v${COREDNS_VERSION}/coredns_${COREDNS_VERSION}_linux_amd64.tgz"
printf '\nfetching %s\n' "${COREDNS_ARTIFACT}"
curl --retry-max-time 120 -L "${COREDNS_ARTIFACT}" | tar -xzv

################################################################################
##                                main()                                      ##
################################################################################
# Mark all the files in the working directory:
# 1. Executable
# 2. Owned by root:root
chmod 0755 -- *
chown root:root -- *

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
