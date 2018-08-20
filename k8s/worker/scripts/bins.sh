#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

# This script is executed via the systemd service, bins.service. The
# service executes the script using the working directory into which
# the binaries are extracted.

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
K8S_ARTIFACT=${K8S_URL}/${K8S_VERSION}/kubernetes-node-linux-amd64.tar.gz

printf '\nfetching %s\n' "${K8S_ARTIFACT}"
curl --retry-max-time 120 -L \
  "${K8S_ARTIFACT}" | \
  tar --strip-components=3 --wildcards -xzv \
  --exclude=kubernetes/node/bin/*.tar \
  --exclude=kubernetes/node/bin/*.docker_tag \
  'kubernetes/node/bin/*'

################################################################################
##                                crictl                                      ##
################################################################################
CRICTL_URL=https://github.com/kubernetes-incubator/cri-tools/releases/download
CRICTL_ARTIFACT="${CRICTL_URL}/v${CRICTL_VERSION}/crictl-v${CRICTL_VERSION}-linux-amd64.tar.gz"
printf '\nfetching %s\n' "${CRICTL_ARTIFACT}"
curl --retry-max-time 120 -L "${CRICTL_ARTIFACT}" | tar -xzv

################################################################################
##                                 runc                                       ##
################################################################################
RUNC_URL=https://github.com/opencontainers/runc/releases/download
RUNC_ARTIFACT="${RUNC_URL}/v${RUNC_VERSION}/runc.amd64"
printf '\nfetching %s\n' "${RUNC_ARTIFACT}"
curl --retry-max-time 120 -Lo "${BIN_DIR}/runc" "${RUNC_ARTIFACT}"

################################################################################
##                                 runsc                                      ##
################################################################################
RUNSC_URL=https://storage.googleapis.com/gvisor/releases/nightly
RUNSC_ARTIFACT="${RUNSC_URL}/${RUNSC_VERSION}/runsc"
printf '\nfetching %s\n' "${RUNSC_ARTIFACT}"
curl --retry-max-time 120 -LO "${RUNSC_ARTIFACT}"

################################################################################
##                              CNI plug-ins                                  ##
################################################################################
CNI_PLUGINS_URL=https://github.com/containernetworking/plugins/releases/download
CNI_PLUGINS_ARTIFACT="${CNI_PLUGINS_URL}/v${CNI_PLUGINS_VERSION}/cni-plugins-amd64-v${CNI_PLUGINS_VERSION}.tgz"
printf '\nfetching %s\n' "${CNI_PLUGINS_ARTIFACT}"
curl --retry-max-time 120 -L "${CNI_PLUGINS_ARTIFACT}" | tar -xzvC "${CNI_BIN_DIR}"

################################################################################
##                               ContainerD                                   ##
################################################################################
CONTAINERD_URL=https://github.com/containerd/containerd/releases/download
CONTAINERD_ARTIFACT="${CONTAINERD_URL}/v${CONTAINERD_VERSION}/containerd-${CONTAINERD_VERSION}.linux-amd64.tar.gz"
printf '\nfetching %s\n' "${CONTAINERD_ARTIFACT}"
curl --retry-max-time 120 -L "${CONTAINERD_ARTIFACT}" | tar -xzv --strip-components=1

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
