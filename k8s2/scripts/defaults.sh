#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# This shell script replaces well-known tokens in files located
# in /etc/default with runtime values.

HOSTFQDN=$(hostname)
HOSTNAME=$(hostname -s)
IPV4_ADDRESS=$(ip route get 1 | awk '{print $NF;exit}')

find /etc/default -type f -exec sed -i \
  -e 's/{DEBUG}/'"${DEBUG}"'/g' \
  -e 's/{IPV4_ADDRESS}/'"${IPV4_ADDRESS}"'/g' \
  -e 's/{HOSTFQDN}/'"${HOSTFQDN}"'/g' \
  -e 's/{HOSTNAME}/'"${HOSTNAME}"'/g' \
  {} \;

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
