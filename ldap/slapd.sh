#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

# Set defaults.
LDAP_DOMAIN=${LDAP_DOMAIN:-vmware.run}
LDAP_ORG=${LDAP_ORG:-VMware}
LDAP_ROOT_USER=${LDAP_ROOT_USER:-root}
LDAP_ROOT_PASS=${LDAP_ROOT_PASS:-$(slappasswd -h "{SSHA}" -s admin)}
LDAP_LOG_LEVEL=${LDAP_LOG_LEVEL:-stats}
LDAP_TLS_VERIFY=${LDAP_TLS_VERIFY:-never}
LDAP_CONF=${LDAP_CONF:-/etc/openldap/slapd.conf}
LDAP_DATA=${LDAP_DATA:-/var/lib/openldap/openldap-data}

# Figure out how many domain components there are.
print_domain_parts() {
  # shellcheck disable=SC2034
  for i; do
    echo "${@}" | tr ' ' '.'
    shift
    if [ "${#}" -eq "1" ]; then break; fi
  done
}

print_reverse_domain_parts() {
  # shellcheck disable=SC2046
  print_domain_parts $(echo "${1}" | tr '.' ' ') | sed '1!x;H;1h;$!d;g'
}

tranlsate_domain_to_ldap() {
  printf "DC=%s" "$(echo "${1}" | sed 's/\./,DC=/g')"
}

# Get the list of LDAP domains to create.
LDAP_DOMAIN_LIST=$(print_reverse_domain_parts "${LDAP_DOMAIN}")

# Get the root LDAP domain and translate it to the DC= format.
# shellcheck disable=SC2086
LDAP_DOMAIN_ROOT=$(echo ${LDAP_DOMAIN_LIST} | awk '{print $1}')
LDAP_DOMAIN_ROOT=$(tranlsate_domain_to_ldap "${LDAP_DOMAIN_ROOT}")

# Ensure the path to the .ldaprc file exists.
LDAPRC_PATH=/root/.ldaprc
mkdir -p $(dirname "${LDAPRC_PATH}")

# TLS=false
if [ "${LDAP_TLS}" = "false" ] || \
   [ -z "${LDAP_TLS_CRT}" ] || \
   [ -z "${LDAP_TLS_KEY}" ]; then

  # Expose the non-TLS endpoint only.
  SLAPD_HOSTS="ldap:///"

  # Write the ldaprc file.
  cat <<EOF > ${LDAPRC_PATH}
BASE        ${LDAP_DOMAIN_ROOT}
URI         ldap://127.0.0.1
BINDDN      CN=${LDAP_ROOT_USER},${LDAP_DOMAIN_ROOT}
EOF

# TLS=true
else

  # Expose the non-TLS and TLS endpoints.
  SLAPD_HOSTS="ldap:/// ldaps:///"

  # Ensure the directory for the certficates exists & set its perms.
  mkdir -p /etc/openldap/tls && chmod 0755 /etc/openldap/tls

  # If the CA isn't set then it's likely a self-signed cert. In that
  # case use the cert as the CA.
  if [ -z "${LDAP_TLS_CA}" ]; then LDAP_TLS_CA=$LDAP_TLS_CRT; fi

  echo "${LDAP_TLS_CA}"  | base64 -d | gzip -d > /etc/openldap/tls/ca.pem
  echo "${LDAP_TLS_KEY}" | base64 -d | gzip -d > /etc/openldap/tls/key.pem
  echo "${LDAP_TLS_CRT}" | base64 -d | gzip -d > /etc/openldap/tls/crt.pem

  # Injected into the slapd configuration file.
  LDAP_TLS_CONF=$(cat <<EOF
TLSCACertificateFile  /etc/openldap/tls/ca.pem
TLSCertificateKeyFile /etc/openldap/tls/key.pem
TLSCertificateFile    /etc/openldap/tls/crt.pem
TLSVerifyClient       ${LDAP_TLS_VERIFY}
EOF
)

  # Ensure the CA and cert are world readable.
  chmod 0644 /etc/openldap/tls/ca.pem \
             /etc/openldap/tls/crt.pem

  # Make the key immutable.
  chmod 0400 /etc/openldap/tls/key.pem

  # Write the ldaprc file.
  cat <<EOF > ${LDAPRC_PATH}
BASE        ${LDAP_DOMAIN_ROOT}
URI         ldaps://127.0.0.1
BINDDN      CN=${LDAP_ROOT_USER},${LDAP_DOMAIN_ROOT}

TLS_CACERT  /etc/openldap/tls/ca.pem
TLS_REQCERT demand
EOF

fi

# The default ACL says:
# * users can write to themselves
# * anon users can authenticate
# * authenticated users can read all
ACCESS_CONTROL=${ACCESS_CONTROL:-'access to * by self write by anonymous auth by * read'}

# If LDAP_CONF is not defined then create a default config file.
if [ ! -e "${LDAP_CONF}" ]; then
  cat > "${LDAP_CONF}" <<EOF
include     /etc/openldap/schema/core.schema
include     /etc/openldap/schema/cosine.schema
include     /etc/openldap/schema/inetorgperson.schema

pidfile     /run/openldap/slapd.pid
argsfile    /run/openldap/slapd.args

modulepath  /usr/lib/openldap
moduleload  back_mdb.so

${ACCESS_CONTROL}

${LDAP_TLS_CONF}

database    mdb
maxsize     1073741824
suffix      ${LDAP_DOMAIN_ROOT}
rootdn      cn=${LDAP_ROOT_USER},${LDAP_DOMAIN_ROOT}

rootpw      ${LDAP_ROOT_PASS}
directory   ${LDAP_DATA}

index       objectClass	eq
index       mail eq
EOF
fi

# Get the LDAP domain where the users OU will be created and translate
# the domain to the DC= format.
# shellcheck disable=SC2086
LDAP_BASE_DN=$(echo ${LDAP_DOMAIN_LIST} | awk '{print $NF}')
LDAP_BASE_DN=$(tranlsate_domain_to_ldap "${LDAP_BASE_DN}")

# Build the Users and Groups DNs
LDAP_USERS_DN="OU=users,${LDAP_BASE_DN}"
LDAP_GROUPS_DN="OU=groups,${LDAP_BASE_DN}"

# Add all of the parts of the domain
for d in ${LDAP_DOMAIN_LIST}; do
  slapadd <<EOF
dn: $(tranlsate_domain_to_ldap "${d}")
objectClass: dcObject
objectClass: organization
o: ${LDAP_ORG}
EOF
done

# Create the users OU.
slapadd <<EOF
dn: ${LDAP_USERS_DN}
objectClass: organizationalUnit
ou: users

dn: ${LDAP_GROUPS_DN}
objectClass: organizationalUnit
ou: groups
EOF

# If LDAP_LDIF is defined then decode it, interpolate it, write it
# to a file, and import it.
if [ -n "${LDAP_LDIF}" ]; then
  if ldif=$(echo "${LDAP_LDIF}" | base64 -d | gzip -d); then
    echo "${ldif}" | \
      sed -e 's/{{ LDAP_BASE_DN }}/'"${LDAP_BASE_DN}"'/g' \
          -e 's/{{ LDAP_USERS_DN }}/'"${LDAP_USERS_DN}"'/g' \
          -e 's/{{ LDAP_GROUPS_DN }}/'"${LDAP_GROUPS_DN}"'/g' | \
      slapadd
  fi
fi

# Add any scripts in /ldif
if ldif_files=$(ls /ldif/*.ldif 2> /dev/null); then
  for f in $ldif_files; do slapadd -l "${f}"; done
fi

# Exit to shell if the first argument to the script is "shell"
if [ "${1}" = "shell" ]; then exec /bin/sh; fi

if [ "${LDAP_LOG_LEVEL}" = "255" ]; then
  echo && cat "${LDAP_CONF}" && echo
fi

# Start slapd
exec slapd -d "${LDAP_LOG_LEVEL}" \
           -f "${LDAP_CONF}" \
           -h "${SLAPD_HOSTS}"