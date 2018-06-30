# OpenLDAP
Provisions a minimal Linux host running OpenLDAP.

## Run locally
The OpenLDAP host may be run locally using Docker.

### Getting started
Build, launch, and query the LDAP server with a few short commands.

#### Build the Docker image
```shell
$ docker build -t slapd . 
```

#### Start the LDAP server
```shell
$ docker run --name slapd --rm -p 3889:389 slapd
5b355b36 @(#) $OpenLDAP: slapd 2.4.45 (Nov  9 2017 20:08:19) $
	buildozer@build-3-7-x86_64:/home/buildozer/aports/main/openldap/src/openldap-2.4.45/servers/slapd
5b355b36 slapd starting
```

#### Query the LDAP server
```shell
$ ldapwhoami -H ldap://localhost:3889 -x -D "cn=root,DC=vmware,DC=local" -w admin
dn:cn=root,dc=vmware,dc=com
```

#### Stop the LDAP server
```shell
$ docker stop slapd
```

### Configuration
The following environment variables are used to configure the LDAP server:

| Environment Variable | Description | Default |
|---|---|---|
| `LDAP_DOMAIN` | The FQDN of the LDAP server's root object | `vmware.local` |
| `LDAP_ORG` | The name of the LDAP server's root orginization | `VMware` |
| `LDAP_ROOT_USER` | The LDAP server's admin user | `root` |
| `LDAP_ROOT_PASS` | The hashed password for the LDAP server's admin user | `slappasswd -h "{SSHA}" -s admin)` |
| `SLAPD_CONF` | The path to the LDAP server's config file. Use a mapped Docker file/volume to place a valid config file at the configured path | `/etc/openldap/slapd.conf` |
| `SLAPD_DATA ` | The path to the LDAP server's database. Use a mapped Docker volume to persist the LDAP server's data | `/var/lib/openldap/openldap-data` |

### Seeding the server
The LDAP server can be seeded with LDIF data via environment variable and
by mapping a volume.

#### Seed by environment variable
The environment variable `LDAP_LDIF` may be used to seed the LDAP server
with LDIF content. The content must be base64-encoded.

##### Store base64-encoded LDIF content in environment variable
```shell
$ export LDAP_LDIF=$(base64 <<EOF
dn: cn=akutz,{{ LDAP_USERS_DN }}
cn: akutz
displayName: Andrew Kutz
givenName: Andrew
sn: Kutz
objectClass: inetOrgPerson
userPassword: {SSHA}9WkeaxRp+lJYB305009gIPaqxxL+3/5A
mail: akutz@vmware.com
EOF
)
```

##### Start the LDAP server with seed data via environment variable
```shell
$ docker run --name slapd --rm -p 3889:389 -e LDAP_LDIF=$LDAP_LDIF slapd
5b355c88 @(#) $OpenLDAP: slapd 2.4.45 (Nov  9 2017 20:08:19) $
	buildozer@build-3-7-x86_64:/home/buildozer/aports/main/openldap/src/openldap-2.4.45/servers/slapd
5b355c88 slapd starting
```

##### Query the LDAP server
```shell
$ ldapsearch -LLL -H ldap://localhost:3889 -b "DC=vmware,DC=local" \
  -x -D "cn=root,DC=vmware,DC=local" -w admin \
  "(objectClass=inetOrgPerson)" 

dn: cn=akutz,dc=vmware,dc=com
cn: akutz
displayName: Andrew Kutz
givenName: Andrew
sn: Kutz
objectClass: inetOrgPerson
userPassword:: e1NTSEF9OVdrZWF4UnArbEpZQjMwNTAwOWdJUGFxeHhMKzMvNUE=
mail: akutz@vmware.com
```

##### Stop the LDAP server
```shell
$ docker stop slapd
```

#### Seed by mapped volume
A directory with one or more LDIF files may be mapped to `/ldif`. The
files in this directory will be used to seed the LDAP server.

##### Write two LDIF files to disk
```shell
$ rm -fr /tmp/ldif && \
  mkdir -p /tmp/ldif && \
  cat <<EOF > /tmp/ldif/akutz.ldif &&
dn: cn=akutz,{{ LDAP_USERS_DN }}
cn: akutz
displayName: Andrew Kutz
givenName: Andrew
sn: Kutz
objectClass: inetOrgPerson
userPassword: {SSHA}9WkeaxRp+lJYB305009gIPaqxxL+3/5A
mail: akutz@vmware.com
EOF
  cat <<EOF > /tmp/ldif/luoh.ldif
dn: cn=luoh,{{ LDAP_USERS_DN }}
cn: luoh
displayName: Hui Luo
givenName: Hui
sn: Luo
objectClass: inetOrgPerson
userPassword: {SSHA}VSqDz8z4vDjZaf+LT5ou0Zw5qMFzhXWI
mail: luoh@vmware.com
EOF
```

##### Start the LDAP server with seed data via a mapped volume
```shell
$ docker run --name slapd --rm -p 3889:389 -v /tmp/ldif:/ldif slapd
5b355e9d @(#) $OpenLDAP: slapd 2.4.45 (Nov  9 2017 20:08:19) $
	buildozer@build-3-7-x86_64:/home/buildozer/aports/main/openldap/src/openldap-2.4.45/servers/slapd
5b355e9d slapd starting
```

##### Query the LDAP server
```shell
$ ldapsearch -LLL -H ldap://localhost:3889 -b "DC=vmware,DC=local" \
  -x -D "cn=root,DC=vmware,DC=local" -w admin \
  "(objectClass=inetOrgPerson)" 

dn: cn=akutz,dc=vmware,dc=com
cn: akutz
displayName: Andrew Kutz
givenName: Andrew
sn: Kutz
objectClass: inetOrgPerson
userPassword:: e1NTSEF9OVdrZWF4UnArbEpZQjMwNTAwOWdJUGFxeHhMKzMvNUE=
mail: akutz@vmware.com

dn: cn=luoh,dc=vmware,dc=com
cn: luoh
displayName: Hui Luo
givenName: Hui
sn: Luo
objectClass: inetOrgPerson
userPassword:: e1NTSEF9VlNxRHo4ejR2RGpaYWYrTFQ1b3UwWnc1cU1GemhYV0k=
mail: luoh@vmware.com
```

##### Stop the LDAP server
```shell
$ docker stop slapd
```

## Run Remotely
The OpenLDAP host may be provisioned to a remote VMware vSphere server. Please
see the root [`README.md`](../README.md) for information on how to provision
systems to vSphere. A few notes:

* Environment variables listed in the previous sections must be prefixed with 
`VMCTF_` when deploying this system remotely using the root project's `run.sh` 
script.
* The steps below expect the working directory to be the project root.
* The steps below expect the root Docker image, `vmctf`, has been built per the
root [`README.md`](../README.md).

### Provision an LDAP server
```shell
$ ./run.sh deploy openldap
```

### Provision an LDAP server with a custom LDAP domain
```shell
$ VMCTF_LDAP_DOMAIN=cnx.cna.vmware.local ./run.sh deploy openldap
```

### Provision an LDAP server with seed data via environment variable
```shell
$ VMCTF_LDAP_LDIF=$(base64 <<EOF
dn: cn=akutz,{{ LDAP_USERS_DN }}
cn: akutz
displayName: Andrew Kutz
givenName: Andrew
sn: Kutz
objectClass: inetOrgPerson
userPassword: {SSHA}9WkeaxRp+lJYB305009gIPaqxxL+3/5A
mail: akutz@vmware.com
EOF
) ./run.sh deploy openldap
```
