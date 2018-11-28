#!/bin/sh

# posix compliant
# verified by https://www.shellcheck.net

set -e
set -o pipefail

cd "$(dirname "${0}")"

make -C .. certs; make certs
VMCTF_LDAP_TLS_CA=$(gzip -9c <../ca.crt | { base64 -w 0 || base64; })
VMCTF_LDAP_TLS_CRT=$(gzip -9c <ldap.vmware.ci.crt | { base64 -w 0 || base64; })
VMCTF_LDAP_TLS_KEY=$(gzip -9c <ldap.vmware.ci.key | { base64 -w 0 || base64; })
export VMCTF_LDAP_TLS_CA VMCTF_LDAP_TLS_CRT VMCTF_LDAP_TLS_KEY

VMCTF_LDAP_LDIF=$(gzip -9c <users.ldif | { base64 -w 0 || base64; })
export VMCTF_LDAP_LDIF

make -C .. images; make images
cd .. && ./run.sh deploy ldap
