#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# This shell script replaces well-known tokens in files located
# in /etc/default with runtime values POST etcd startup.

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
  if ! etcd_members=$(etcdctl member list); then
    echo "error: failed to list etcd members"
    exit 1
  fi
  num_mem=$(echo "${etcd_members}" | wc -l | awk '{print $1}')
  if ! is_num "${num_mem}"; then
    echo "error: invalid ACTUAL_ETCD_MEMBER_COUNT=${num_mem}"
    exit 1
  fi
  [ "${num_mem}" -ge "${ETCD_MEMBER_COUNT}" ] && break
  sleep 1
done

member_ip_addresses=$(echo "${etcd_members}" | \
    awk '{print $NF;}' | \
    grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | \
    tr '\n' ' ' | \
    sed 's/\(.\{1,\}\).$/\1/')

client_endpoints=
peer_endpoints=
for ip in ${member_ip_addresses}; do
  client_endpoints="${client_endpoints}https://${ip}:2379,"
  peer_endpoints="${peer_endpoints}https://${ip}:2380,"
done
client_endpoints=$(echo "${client_endpoints}" | sed 's/\(.\{1,\}\).$/\1/')
peer_endpoints=$(echo "${peer_endpoints}" | sed 's/\(.\{1,\}\).$/\1/')

find /etc/default -type f -exec sed -i \
  -e 's~{ETCD_MEMBER_IP_ADDRESSES}~'"${member_ip_addresses}"'~g' \
  -e 's~{ETCD_CLIENT_ENDPOINTS}~'"${client_endpoints}"'~g' \
  -e 's~{ETCD_PEER_ENDPOINTS}~'"${peer_endpoints}"'~g' \
  {} \;

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
