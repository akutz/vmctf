#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# This shell script replaces well-known tokens in files located
# in /etc/default with runtime values.

HOST_FQDN=$(hostname)
HOST_NAME=$(hostname -s)
IPV4_ADDRESS=$(ip route get 1 | awk '{print $NF;exit}')

find /etc/default -type f -exec sed -i \
  -e 's/{DEBUG}/'"${DEBUG}"'/g' \
  -e 's/{IPV4_ADDRESS}/'"${IPV4_ADDRESS}"'/g' \
  -e 's/{HOSTFQDN}/'"${HOST_FQDN}"'/g' \
  -e 's/{HOSTNAME}/'"${HOST_NAME}"'/g' \
  -e 's/{HOST_FQDN}/'"${HOST_FQDN}"'/g' \
  -e 's/{HOST_NAME}/'"${HOST_NAME}"'/g' \
  {} \;

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
