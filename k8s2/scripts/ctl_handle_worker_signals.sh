#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# This script watches the log /var/log/nginx/k8s-worker-signal.log
# for signals from worker nodes such as:
#
#   * Create DNS entry
#   * TBD

is_num() {
  echo "${1}" | grep '^[[:digit:]]\{1,\}$' >/dev/null 2>&1
}

# Ensure that WORKER_COUNT is set to a number before continuing.
if ! is_num "${WORKER_COUNT}"; then
  echo "invalid worker count: ${WORKER_COUNT}" && exit 1
fi

etcd_disco_token=$(echo "${ETCD_DISCOVERY}" | awk -F/ '{print $NF;exit}')

# Ensure the etcd discovery token is set.
if [ -z "${etcd_disco_token}" ]; then
  echo "etcd discovery token missing" && exit 1
fi

signal_log=/var/log/nginx/k8s-worker-signal.log
signal_fifo=worker-signal.fifo

echo "WORKER_COUNT=${WORKER_COUNT}"
echo "WORKER_SIGNAL_LOG=${signal_log}"
echo "ETCD_DISCOVERY_TOKEN=${etcd_disco_token}"

signal_fifo=worker-signal.fifo
echo "mkfifo ${signal_fifo}" && mkfifo "${signal_fifo}" || exit 1

# Define a POSIX regex for matching IP addresses.
ip_rx='[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'

# Define the URL for DNS signals.
dns_sig_rx=$(printf 'POST /signal?type=%s&tok=%s' dns "${etcd_disco_token}")
dns_sig_rx=''"${dns_sig_rx}"'&fqdn=\[^&\]\{1,\}&ip='"${ip_rx}"
echo "DNS_SIGNAL_RX=${dns_sig_rx}"

# Monitor the signal log for one or more matching patterns and write
# any matches to the fifo. This process is backgrounded so the fifo
# can be read for any data that needs to be handled.
tail -f "${signal_log}" | grep --line-buffered -o \
  -e ''"${dns_sig_rx}"'' \
  >"${signal_fifo}" &
signal_pid="${!}"

while true; do
  # Read the next signal from the fifo.
  read -r signal <"${signal_log}"

  # Handle DNS signals.
  if echo "${signal}" | grep 'type=dns'; then
    echo "processing dns signal: ${signal}"
    fqdn=$(echo "${signal}" | grep -o 'fqdn=[^&]\{1,\}' | awk -F= '{print $2}')
    addr=$(echo "${signal}" | grep -o 'ip=[^&[:space:]]\{1,\}' | awk -F= '{print $2}')

    # Create the A-Record
    fqdn_rev=$(echo "${fqdn}" | tr '.' '\n' | \
      sed '1!x;H;1h;$!d;g' | tr '\n' '.' | \
      sed 's/.$//' | tr '.' '/')
    etcdctl put "/skydns/${fqdn_rev}" '{"host":"'"${addr}"'"}'
    printf 'created DNS A-record\n\t'
    etcdctl get --print-value-only "/skydns/${fqdn_rev}"

    # Create the reverse lookup record
    addr_slashes=$(echo "${addr}" | tr '.' '/')
    etcdctl put "/skydns/arpa/in-addr/${addr_slashes}" '{"host":"'"${fqdn}"'"}'
    printf 'created DNS reverse lookup record\n\t'
    etcdctl get --print-value-only "/skydns/arpa/in-addr/${addr_slashes}"
  fi
done

# Stop monitoring the signal log.
kill "${signal_pid}"
wait "${signal_pid}" || true

# Remove the fifo.
/bin/rm -f "${signal_fifo}"

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
