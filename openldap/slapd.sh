#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

# Set defaults.
LDAP_DOMAIN=${LDAP_DOMAIN:-vmware.com}
LDAP_ORG=${LDAP_ORG:-VMware}
LDAP_ROOT_USER=${LDAP_ROOT_USER:-root}
LDAP_ROOT_PASS=${LDAP_ROOT_PASS:-$(slappasswd -h "{SSHA}" -s admin)}
SLAPD_LOG_LEVEL=${SLAPD_LOG_LEVEL:-stats}
SLAPD_ARGS=${SLAPD_ARGS:-/run/openldap/slapd.args}
SLAPD_CONF=${SLAPD_CONF:-/etc/openldap/slapd.conf}
SLAPD_DATA=${SLAPD_DATA:-/var/lib/openldap/openldap-data}

# The default ACL says:
# * users can write to themselves
# * anon users can authenticate
# * authenticated users can read all
ACCESS_CONTROL=${ACCESS_CONTROL:-'access to * by self write by anonymous auth by * read'}

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

# If SLAPD_CONF is not defined then create a default config file.
if [ ! -e "${SLAPD_CONF}" ]; then
  cat > "${SLAPD_CONF}" <<EOF
include     /etc/openldap/schema/core.schema
include     /etc/openldap/schema/cosine.schema
include     /etc/openldap/schema/inetorgperson.schema

pidfile     /run/openldap/slapd.pid
argsfile    ${SLAPD_ARGS}

modulepath  /usr/lib/openldap
moduleload  back_mdb.so

${ACCESS_CONTROL}

database    mdb
maxsize     1073741824
suffix      ${LDAP_DOMAIN_ROOT}
rootdn      cn=${LDAP_ROOT_USER},${LDAP_DOMAIN_ROOT}

rootpw      ${LDAP_ROOT_PASS}
directory   ${SLAPD_DATA}

index       objectClass	eq
index       mail eq
EOF
fi

# Get the LDAP domain where the users OU will be created and translate
# the domain to the DC= format.
# shellcheck disable=SC2086
LDAP_DOMAIN_USERS=$(echo ${LDAP_DOMAIN_LIST} | awk '{print $NF}')
LDAP_DOMAIN_USERS=$(tranlsate_domain_to_ldap "${LDAP_DOMAIN_USERS}")

# Build the Users DN
LDAP_USERS_DN="OU=users,${LDAP_DOMAIN_USERS}"

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
EOF

# If LDAP_LDIF64 is defined then decode it, interpolate it, write it
# to a file, and import it.
if [ -n "${LDAP_LDIF64}" ]; then
  if ldif=$(echo "${LDAP_LDIF64}" | base64 -d); then
    echo "${ldif}" | \
      sed 's/{{ LDAP_BASE_DN }}/'"${LDAP_USERS_DN}"'/g' | \
      slapadd
  fi
fi

# Add any scripts in /ldif
if ldif_files=$(ls /ldif/*.ldif 2> /dev/null); then
  for f in $ldif_files; do slapadd -l "${f}"; done
fi

# Exit to shell if the first argument to the script is "shell"
if [ "${1}" = "shell" ]; then exec /bin/sh; fi

# Start slapd
exec slapd -d "${SLAPD_LOG_LEVEL}" -f "${SLAPD_CONF}"