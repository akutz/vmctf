#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

# Generate the X509 cert/key pair(s) for CoreDNS
gencerts.sh

# Prepend the CLUSTER_FQDN=ETCD_MEMBER_IPS to DNS_ENTRIES so
# round-robin records are created for CLUSTER_FQDN that point to
# the member IPs.
etcd_member_ips=$(echo "${ETCD_MEMBER_IP_ADDRESSES}" | tr ' ' ',')
DNS_ENTRIES="${CLUSTER_FQDN}=${etcd_member_ips} ${DNS_ENTRIES}"
echo DNS_ENTRIES="${DNS_ENTRIES}"

# This loop expects DNS_ENTRIES to be a space-delimited list of values 
# matching the pattern FQDN=IP_ADDRESS[,IP_ADDRESS]. If an entry has
# multiple IP addresses then multiple A records are created for that
# entry, resulting in an round-robin response to queries.
for e in ${DNS_ENTRIES}; do
  fqdn=$(echo "${e}" | awk -F= '{print $1}')
  fqdn_rev=$(echo "${fqdn}" | tr '.' '\n' | \
      sed '1!x;H;1h;$!d;g' | tr '\n' '.' | \
      sed 's/.$//' | tr '.' '/')

  addr=$(echo "${e}" | awk -F= '{print $2}')
  
  # If the address has a comma in it then treat the entry as an A record
  # with a round-robin set of IP address targets.
  if echo "${addr}" | grep ',' >/dev/null 2>&1; then

    # Replace the commas with spaces.
    addrs=$(echo "${addr}" | tr ',' ' ')

    # Define an index to use when creating the A records.
    idx_addr=1

    # Loop over the addresses, creating an A record for each one.
    for a in ${addrs}; do
      # Create the A-Record
      etcdctl put "/skydns/${fqdn_rev}/${idx_addr}" '{"host":"'"${a}"'"}'
      printf 'created DNS A-record\n\t'
      etcdctl get --print-value-only "/skydns/${fqdn_rev}"

      # Increment the address index.
      idx_addr=$((idx_addr+1))
    done

  else
    addr_slashes=$(echo "${addr}" | tr '.' '/')

    # Create the A-Record
    etcdctl put "/skydns/${fqdn_rev}" '{"host":"'"${addr}"'"}'
    printf 'created DNS A-record\n\t'
    etcdctl get --print-value-only "/skydns/${fqdn_rev}"

    # Create the reverse lookup record
    etcdctl put "/skydns/arpa/in-addr/${addr_slashes}" '{"host":"'"${fqdn}"'"}'
    printf 'created DNS reverse lookup record\n\t'
    etcdctl get --print-value-only "/skydns/arpa/in-addr/${addr_slashes}"
  fi
done

# Remove the symlink for system's resolv.conf
rm -f /etc/resolv.conf /var/lib/coredns/resolv.conf

# Create a resolv.conf that points to the local CoreDNS server.
for e in ${DNS_SERVERS}; do
  echo "nameserver ${e}" >> /var/lib/coredns/resolv.conf
done

# Add a search directive to the file.
if [ -n "${DNS_SEARCH}" ]; then
  echo "search ${DNS_SEARCH}" >> /var/lib/coredns/resolv.conf
fi

# Link the CoreDNS resolv.conf to /etc/resolv.conf
ln -s /var/lib/coredns/resolv.conf /etc/resolv.conf

# Indicate the script has completed
echo "$(basename "${0}" | sed 's/.sh/.service/') running"
