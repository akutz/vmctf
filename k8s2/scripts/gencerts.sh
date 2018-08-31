#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

set -o pipefail
if [ "${DEBUG}" = "true" ]; then set -x; fi

# Add ${BIN_DIR} to the path
BIN_DIR="${BIN_DIR:-/opt/bin}"
echo "${PATH}" | grep -q "${BIN_DIR}" || export PATH="${BIN_DIR}:${PATH}"

eval_i() {
  k1="${1}"
  k2="${2:-$(echo "${k1}" | tr '[:lower:]' '[:upper:]')}"
  k3="${3:-${k2}}"

  # Parameter expansion is often implemented with ":-". The lack of
  # the colon below means k1 will be assigned an empty value if
  # k2_i is defined at all. This provides the ability to set an
  # empty value even when k3 is defined and non-empty.
  eval "${k1}=\${${k2}_${i}-\${${k3}}}"
}

# i is the index used to check for TLS IDs, and is incremented
# at the end of the below while loop's iteration. When 
# TLS_${i} is not set, the loop exits.
i=0

while true; do
  # Check for a TLS ID. If one is not set then exit the loop.
  tls_id=; eval "tls_id=\$TLS_${i}"
  if [ -z "${tls_id}" ]; then break; fi

  # Get the common name and replace any occurences of {HOSTNAME} in
  # the common name with the hostname.
  eval_i tls_common_name TLS_COMMON_NAME tls_id
  tls_common_name=$(echo "${tls_common_name}" | \
                    sed 's/{HOSTNAME}/'"$(hostname)"'/g')

  # Get the file names for the key and cert file.
  tls_file_name=; tls_key_out=; tls_crt_out=;
  eval_i tls_file_name TLS_FILE_NAME tls_id
  tls_key_out="/etc/ssl/${tls_file_name}.key"
  tls_crt_out="/etc/ssl/${tls_file_name}.crt"

  # If the certificate and key already exist then do not regenerate them.
  if [ -f "${tls_key_out}" ] && [ -f "${tls_crt_out}" ]; then continue; fi

  # Get the rest of the certificate information.
  tls_default_bits=;           eval_i tls_default_bits
  tls_default_days=;           eval_i tls_default_days
  tls_country_name=;           eval_i tls_country_name
  tls_state_or_province_name=; eval_i tls_state_or_province_name
  tls_locality_name=;          eval_i tls_locality_name
  tls_org_name=;               eval_i tls_org_name
  tls_ou_name=;                eval_i tls_ou_name
  tls_email=;                  eval_i tls_email
  tls_key_usage=;              eval_i tls_key_usage
  tls_ext_key_usage=;          eval_i tls_ext_key_usage
  tls_san=;                    eval_i tls_san
  tls_san_dns=;                eval_i tls_san_dns
  tls_san_ip=;                 eval_i tls_san_ip
  tls_key_uid=;                eval_i tls_key_uid
  tls_key_gid=;                eval_i tls_key_gid
  tls_key_perm=;               eval_i tls_key_perm
  tls_crt_uid=;                eval_i tls_crt_uid
  tls_crt_gid=;                eval_i tls_crt_gid
  tls_crt_perm=;               eval_i tls_crt_perm

  # Generate the new cert/key pair.
  TLS_COMMON_NAME="${tls_common_name}" \
  TLS_DEFAULT_BITS="${tls_default_bits}" \
  TLS_DEFAULT_DAYS="${tls_default_days}" \
  TLS_KEY_OUT="${tls_key_out}" \
  TLS_CRT_OUT="${tls_crt_out}" \
  TLS_COUNTRY_NAME="${tls_country_name}" \
  TLS_STATE_OR_PROVINCE_NAME="${tls_state_or_province_name}" \
  TLS_LOCALITY_NAME="${tls_locality_name}" \
  TLS_ORG_NAME="${tls_org_name}" \
  TLS_OU_NAME="${tls_ou_name}" \
  TLS_EMAIL="${tls_email}" \
  TLS_KEY_USAGE="${tls_key_usage}" \
  TLS_EXT_KEY_USAGE="${tls_ext_key_usage}" \
  TLS_SAN="${tls_san}" \
  TLS_SAN_DNS="${tls_san_dns}" \
  TLS_SAN_IP="${tls_san_ip}" \
  TLS_KEY_UID="${tls_key_uid}" \
  TLS_KEY_GID="${tls_key_gid}" \
  TLS_KEY_PERM="${tls_key_perm}" \
  TLS_CRT_UID="${tls_crt_uid}" \
  TLS_CRT_GID="${tls_crt_gid}" \
  TLS_CRT_PERM="${tls_crt_perm}" \
  newcert.sh

  # Increment the index
  i=$((i+1))
done
