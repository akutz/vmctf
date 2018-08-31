#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# This shell script replaces well-known tokens in files located
# in /etc/default with runtime values POST etcd startup on the
# etcd member nodes.

is_num() {
  echo "${1}" | grep '^[[:digit:]]\{1,\}$' >/dev/null 2>&1
}

# This is set to the number of expected etcd members.
if ! is_num "${ETCD_MEMBER_COUNT}"; then
  echo "error: invalid ETCD_MEMBER_COUNT=${ETCD_MEMBER_COUNT}"
  exit 1
fi

# Keep getting the etcd member IPs until they match the expected
# numbrer of members.
while true; do
  etcd_members=$(curl -sSL --retry-max-time 120 "${ETCD_DISCOVERY}" | \
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
    tr '\n' ' ' | \
    sed 's/\(.\{1,\}\).$/\1/')

  num_mem=$(echo "${etcd_members}" | wc -w | awk '{print $1}')
  if ! is_num "${num_mem}"; then
    echo "error: invalid ACTUAL_ETCD_MEMBER_COUNT=${num_mem}"
    exit 1
  fi
  [ "${num_mem}" -ge "${ETCD_MEMBER_COUNT}" ] && break
  sleep 1
done

member_ip_addresses="${etcd_members}"
client_endpoints=
for ip in ${member_ip_addresses}; do
  client_endpoints="${client_endpoints}https://${ip}:2379,"
done
client_endpoints=$(echo "${client_endpoints}" | sed 's/\(.\{1,\}\).$/\1/')

find /etc/default -type f -exec sed -i \
  -e 's~{ETCD_MEMBER_IP_ADDRESSES}~'"${member_ip_addresses}"'~g' \
  -e 's~{ETCD_CLIENT_ENDPOINTS}~'"${client_endpoints}"'~g' \
  {} \;

# Remove the symlink for system's resolv.conf
rm -f /etc/resolv.conf /var/lib/coredns/resolv.conf

# Create a resolv.conf that points to the cluster's DNS servers.
for e in ${member_ip_addresses}; do
  echo "nameserver ${e}" >> /var/lib/kubernetes/resolv.conf
done

# Add a search directive to the file.
if [ -n "${DNS_SEARCH}" ]; then
  echo "search ${DNS_SEARCH}" >> /var/lib/kubernetes/resolv.conf
fi

# Link to /etc/resolv.conf
ln -s /var/lib/kubernetes/resolv.conf /etc/resolv.conf

# Wait until the cluster can be resolved via DNS. After 100 failed 
# attempts over 5 minutes the script will exit with an error.
i=1
while true; do
  if [ "${i}" -gt 100 ]; then
    echo "cluster fqdn dns lookup failed"
    exit 1
  fi
  echo "cluster fqdn dns lookup attempt: ${i}"
  host "${CLUSTER_FQDN}" >/dev/null 2>&1 && break
  sleep 3
  i=$((i+1))
done

# Get the etcd discovery URL's token value.
etcd_disco_token=$(echo "${ETCD_DISCOVERY}" | awk -F/ '{print $NF;exit}')

# Build a signal URL for creating DNS entries.
signal_url="http://${CLUSTER_FQDN}:3080/signal?type=dns"

# Include the etcd discovery token to make sure the control plane
# can identify this request as part of the same cluster to which
# the control plane members belong.
signal_url="${signal_url}&tok=${etcd_disco_token}"

# Include this node's FQDN and IP values used to create the DNS entry.
signal_url="${signal_url}&fqdn=${HOSTFQDN}&ip=${IPV4_ADDRESS}"

# Create a DNS entry for the worker by sending a crafted URL to the
# control plane. This signal causes the control plane to create a DNS
# entry for the information encoded in the URL's query string.
echo "sending signal to control plane: ${signal_url}"
curl -sSL --retry-max-time 120 "${signal_url}"

# Wait until the worker node can be resolved via DNS. After 100 failed 
# attempts over 5 minutes the script will exit with an error.
i=1
while true; do
  if [ "${i}" -gt 100 ]; then
    echo "worker node dns lookup failed"
    exit 1
  fi
  echo "worker node dns lookup attempt: ${i}"
  host "${HOSTFQDN}" >/dev/null 2>&1 && \
    host "${IPV4_ADDRESS}" >/dev/null 2>&1 && \
    break
  sleep 3
  i=$((i+1))
done

# Wait until the kubernetes health check reports "ok". After 100 failed 
# attempts over 5 minutes the script will exit with an error.
i=1
while true; do
  if [ "${i}" -gt 100 ]; then
    echo "control plane health check failed"
    exit 1
  fi
  echo "control plane health check attempt: ${i}"
  response=$(curl -sSL "http://${CLUSTER_FQDN}/healthz")
  [ "${response}" = "ok" ] && break
  sleep 3
  i=$((i+1))
done

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
