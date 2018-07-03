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
| `LDAP_CONF` | The path to the LDAP server's config file. Use a mapped Docker file/volume to place a valid config file at the configured path | `/etc/openldap/slapd.conf` |
| `LDAP_DATA ` | The path to the LDAP server's database. Use a mapped Docker volume to persist the LDAP server's data | `/var/lib/openldap/openldap-data` |
| `LDAP_LOG_LEVEL` | The LDAP server's log level [value](https://www.openldap.org/doc/admin24/slapdconfig.html#loglevel%20%3Clevel%3E). | `0` |
| `LDAP_LDIF` | The base64-encoded, gzipped LDIF data used to seed the LDAP server | |
| `LDAP_TLS_CA` | The base64-encoded, gzipped, PEM-formatted CA file used with the LDAP server's TLS configuration. | |
| `LDAP_TLS_KEY` | The base64-encoded, gzipped, PEM-formatted key file used with the LDAP server's TLS configuration. | |
| `LDAP_TLS_CRT` | The base64-encoded, gzipped, PEM-formatted certificateused with the LDAP server's TLS configuration. | |

### TLS
In order for the LDAP server to expose a TLS endpoint on TCP port `636`,
`LDAP_TLS_KEY` and `LDAP_TLS_CRT` must both be set. If `LDAP_TLS_CA` is
omitted then a self-signed certificate is assumed and `LDAP_TLS_CRT` is
assigned the value of `LDAP_TLS_CRT`.

#### Generating a self-signed certificate
A self-signed certificate may be generated using the `newcert.sh` script
or with the Docker image built from `Dockerfile.tls`. 

##### Configure certificate generation
Each method is configured the same:

| Environment Variable | Description | Default |
|---|---|---|
| `TLS_KEY_OUT` | The path of the generated key file. |  |
| `TLS_CRT_OUT` | The path of the generated crt file. |  |
| `TLS_PEM_OUT` | The path of the generated key and certificate combined into a single, PEM-formatted file. |  |
| `TLS_DEFAULT_BITS` | The strength of the certificate's RSA encryption. | `2048` |
| `TLS_DEFAULT_DAYS` | The number of days until the certificate expires. The default value is 100 years. | `36500` |
| `TLS_COUNTRY_NAME ` | The certificate subject's country value. | `US` |
| `TLS_STATE_OR_PROVINCE_NAME` | The certificate subject's state or province value. | `California` |
| `TLS_LOCALITY_NAME` | The certificate subject's locality value. | `Palo Alto` |
| `TLS_ORG_NAME` | The certificate subject's organization value. | `VMware` |
| `TLS_OU_NAME` | The certificate subject's organizational unit value. | `CNX` |
| `TLS_COMMON_NAME` | The certificate subject's common name value. | `ldap.cicd.cnx.cna.vmware.run` |
| `TLS_EMAIL` | The certificate subject's e-mail value. | `akutz@vmware.com` |
| `TLS_IS_CA` | Set to `true` to indicate the certificate is a CA. | `false` |
| `TLS_KEY_USAGE` | The certificate's key usage. | `keyCertSign` |
| `TLS_EXT_KEY_USAGE` | The certificate's extended key usage string. | `serverAuth` |
| `TLS_SAN` | Set to false to disable subject alternative names (SANs). | `true` |
| `TLS_SAN_DNS` | A space-delimited list of FQDNs to use as DNS SANs. |  |
| `TLS_SAN_IP` | A space-delimited list of IP addresses to use as IP SANs. |  |
| `TLS_PLAIN_TEXT` | Set to `true` to print the result of `openssl x509 -noout -text` on the newly generated certificate |

##### Generate a self-signed certificate
The first step in generating a new, self-signed certificate is to build
the Docker image:

```shell
$ docker build -t newcert -f Dockerfile.tls .
```

Once the image has been built, simply start a new container from the image
with any of the above environment variables to configure the generation:

```shell
$ docker run --rm \
  -e TLS_SAN_DNS=$(hostname) \
  -e TLS_COMMON_NAME=ldap.local \
  -e TLS_KEY_OUT=/tls/key.pem \
  -e TLS_CRT_OUT=/tls/crt.pem \
  -e TLS_PLAIN_TEXT=true \
  -v $(pwd):/tls \
  newcert
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC8icwWEF3+tKFi
vuyqTOUgYWYV8NKtNd+TUmfdkvMCmGe/qoWpJy+kT7AzcIvn1oy8TuSj1SAOfOJT
5Dh4+9qV3Q4ixMOJ302X3DX3/VQowx8mr1OiW7WvVnZL0moiOofVqYX4xJqSWXH6
Ya+6H9NaHrKNL6UstY465oJWkJLqndYBbMePNP+P8ETRqd/Q4PG24YGMxJqtj2Xf
c+keu6rGgE7Vpit3plgHAa8EhV8cU6vn7ilXUIBaPKuqencWTO64J6dlB5noi/Sl
kY4oYDSMxXQASxCfh7uM3Jxn0RO6VLgb/alLE7YC+gbrU/J20T4zhti/gGmaZEeA
WwvKQQ2tAgMBAAECggEAVa4toC1J+hFuciif9vjA+8knknsB0xNzikjdyNUaOKi4
JWNCINAdF4fbZFUWT4KyLHWR9F5Llins1QEXJOwXtxlhbi2LS2G+qm+52vw2PdwG
kRcGY/dXhto9IlH6R5nf1xqWNqpqMG4TnRy9tlD2RLNEo2LupnXPsDbHLr2+9n2B
jjAiJzllytr5GyOJcep7w0R+vGBzEOYZZzcc7viJmcLnchCe56XRxlPUWgViBTjq
HTyeu9lkThzlI+mKVqh5pXY0w5t4JDJbuYOTzwRg4soISdzud3PglDzqkzYA8y2x
L6L/vOlTfz7yW8u2pwHtcVU0O5bwutWQ+18w9R525QKBgQDxWxZtjNIBoeAQGgEM
uP6lXqwkEFlfPiTqf2XsA+Z0qc1yJb0J8PCWtkI0BmfpCh4gZw+cHbSi1Z5QUoM/
NEghMFL3AJdSIN+knm236TAE7/ABPavXJbudDYY/LijjHhiSJtEc8I3fz826vH2Q
1Ryn8jnH6yexVryfWI9ggRHDVwKBgQDH+k87STEWFMVZFYRSssRc4mwIVwtEo1TV
+k4giOci/j2OsRilrglrkLyAJIN0hMvi1RuLrrIeJLDlKDQFUFXJf/VmzswiVz+H
ToO1WvVtjOgxxUAT+GOWwZQkRTIe4E5MgXfieQcXqr3HqxFTVMVIvRIfGYwpQRCr
dOeGOCl4mwKBgQDCdqXHdqLudcLWtl0KJzPlgjYoiJO5zZRo7GTumOXiMb46rnV1
wQ/YHtmQmWi3t1M2wFMvci/M01lPVmwxTKqhMxJlubAymBIZzRySBeyOzdQO6+W8
38YecHsuBL8k32bkuynZq2hkYEZeouh4/XytRNmRXsMIe95WdUBwfQ4W2QKBgEEH
HUKbD1It2OqZ+5hkt0O5AQZJP8nHDuwx47viqL6RS/Udk3U0va1zuEg3F2QJVr9h
Kv7mBNeWeMtbombj87F9YZBXyLuWAXt/RYbwmARSoKKmkKqtx7ybIBAXTDAMIonw
Q8qqLms8w0+tSgn989UuXjksto4nsUL/1dWoZ5vnAoGBAJEVus04wrCtKLeM4ktG
Yj51ME9whQczuzS9RzI2TU5+9gS/Tqxn/fkB/YQm0uVTcilkl4oItKzEUn47dOAU
pRtPWo4GmbmgUMZltws6yMbPq+4hIu5VGoMoEPkAeA/dzrV1FavoIHyI4Bkf3dB+
kq062uJK5Djzkn517FLyHump
-----END PRIVATE KEY-----

-----BEGIN CERTIFICATE-----
MIIECjCCAvKgAwIBAgIJAMyFiC06nQdqMA0GCSqGSIb3DQEBBQUAMIGLMQswCQYD
VQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTESMBAGA1UEBwwJUGFsbyBBbHRv
MQ8wDQYDVQQKDAZWTXdhcmUxDDAKBgNVBAsMA0NOWDETMBEGA1UEAwwKbGRhcC5s
b2NhbDEfMB0GCSqGSIb3DQEJARYQYWt1dHpAdm13YXJlLmNvbTAeFw0xODA3MDQx
ODA4MzZaFw0xODA4MDMxODA4MzZaMIGLMQswCQYDVQQGEwJVUzETMBEGA1UECAwK
Q2FsaWZvcm5pYTESMBAGA1UEBwwJUGFsbyBBbHRvMQ8wDQYDVQQKDAZWTXdhcmUx
DDAKBgNVBAsMA0NOWDETMBEGA1UEAwwKbGRhcC5sb2NhbDEfMB0GCSqGSIb3DQEJ
ARYQYWt1dHpAdm13YXJlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
ggEBALyJzBYQXf60oWK+7KpM5SBhZhXw0q0135NSZ92S8wKYZ7+qhaknL6RPsDNw
i+fWjLxO5KPVIA584lPkOHj72pXdDiLEw4nfTZfcNff9VCjDHyavU6Jbta9WdkvS
aiI6h9WphfjEmpJZcfphr7of01oeso0vpSy1jjrmglaQkuqd1gFsx480/4/wRNGp
39Dg8bbhgYzEmq2PZd9z6R67qsaATtWmK3emWAcBrwSFXxxTq+fuKVdQgFo8q6p6
dxZM7rgnp2UHmeiL9KWRjihgNIzFdABLEJ+Hu4zcnGfRE7pUuBv9qUsTtgL6ButT
8nbRPjOG2L+AaZpkR4BbC8pBDa0CAwEAAaNvMG0wCQYDVR0TBAIwADALBgNVHQ8E
BAMCAgQwEwYDVR0lBAwwCgYIKwYBBQUHAwEwHQYDVR0OBBYEFCH6auXHAxPtxT5b
GqWMxjI1iIuuMB8GA1UdEQQYMBaCCmxkYXAubG9jYWyCCHBheC5rdXR6MA0GCSqG
SIb3DQEBBQUAA4IBAQCkHD3Shzn/4VHZuPaP6FB4a1gGTvBJCTdAUXjHrODERNmM
7OJMHj/BVcxl/jkFyTx2cx/7MthofeUkGeprvZAzhA3qO1CMKMOxGJ4E0NWxuvDw
1T16F/VJJ1tFQpMDp5pUWn123P/uo1QTuLIxYuMsD4XFFDHXCnaMw0yxXKRl1J6o
VCUeHJnJ6vFsQTfHUCql05TgLJINCGK5/v4EZmyVBDQedWnwK93QkS0IEKDy1HW7
TPBKVESLkj9k0RZEwbz+azTfBqGrV/j9dGduehgnFFiZP9LUTUzFFhnbaPeZxZe+
u+boBdNrPrHHHJVE3aM8Jd8kf558OKidvQgyEBsm
-----END CERTIFICATE-----

Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            cc:85:88:2d:3a:9d:07:6a
    Signature Algorithm: sha1WithRSAEncryption
        Issuer: C=US, ST=California, L=Palo Alto, O=VMware, OU=CNX, CN=ldap.local/emailAddress=akutz@vmware.com
        Validity
            Not Before: Jul  4 18:08:36 2018 GMT
            Not After : Aug  3 18:08:36 2018 GMT
        Subject: C=US, ST=California, L=Palo Alto, O=VMware, OU=CNX, CN=ldap.local/emailAddress=akutz@vmware.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:bc:89:cc:16:10:5d:fe:b4:a1:62:be:ec:aa:4c:
                    e5:20:61:66:15:f0:d2:ad:35:df:93:52:67:dd:92:
                    f3:02:98:67:bf:aa:85:a9:27:2f:a4:4f:b0:33:70:
                    8b:e7:d6:8c:bc:4e:e4:a3:d5:20:0e:7c:e2:53:e4:
                    38:78:fb:da:95:dd:0e:22:c4:c3:89:df:4d:97:dc:
                    35:f7:fd:54:28:c3:1f:26:af:53:a2:5b:b5:af:56:
                    76:4b:d2:6a:22:3a:87:d5:a9:85:f8:c4:9a:92:59:
                    71:fa:61:af:ba:1f:d3:5a:1e:b2:8d:2f:a5:2c:b5:
                    8e:3a:e6:82:56:90:92:ea:9d:d6:01:6c:c7:8f:34:
                    ff:8f:f0:44:d1:a9:df:d0:e0:f1:b6:e1:81:8c:c4:
                    9a:ad:8f:65:df:73:e9:1e:bb:aa:c6:80:4e:d5:a6:
                    2b:77:a6:58:07:01:af:04:85:5f:1c:53:ab:e7:ee:
                    29:57:50:80:5a:3c:ab:aa:7a:77:16:4c:ee:b8:27:
                    a7:65:07:99:e8:8b:f4:a5:91:8e:28:60:34:8c:c5:
                    74:00:4b:10:9f:87:bb:8c:dc:9c:67:d1:13:ba:54:
                    b8:1b:fd:a9:4b:13:b6:02:fa:06:eb:53:f2:76:d1:
                    3e:33:86:d8:bf:80:69:9a:64:47:80:5b:0b:ca:41:
                    0d:ad
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            X509v3 Key Usage: 
                Certificate Sign
            X509v3 Extended Key Usage: 
                TLS Web Server Authentication
            X509v3 Subject Key Identifier: 
                21:FA:6A:E5:C7:03:13:ED:C5:3E:5B:1A:A5:8C:C6:32:35:88:8B:AE
            X509v3 Subject Alternative Name: 
                DNS:ldap.local, DNS:pax.kutz
    Signature Algorithm: sha1WithRSAEncryption
         a4:1c:3d:d2:87:39:ff:e1:51:d9:b8:f6:8f:e8:50:78:6b:58:
         06:4e:f0:49:09:37:40:51:78:c7:ac:e0:c4:44:d9:8c:ec:e2:
         4c:1e:3f:c1:55:cc:65:fe:39:05:c9:3c:76:73:1f:fb:32:d8:
         68:7d:e5:24:19:ea:6b:bd:90:33:84:0d:ea:3b:50:8c:28:c3:
         b1:18:9e:04:d0:d5:b1:ba:f0:f0:d5:3d:7a:17:f5:49:27:5b:
         45:42:93:03:a7:9a:54:5a:7d:76:dc:ff:ee:a3:54:13:b8:b2:
         31:62:e3:2c:0f:85:c5:14:31:d7:0a:76:8c:c3:4c:b1:5c:a4:
         65:d4:9e:a8:54:25:1e:1c:99:c9:ea:f1:6c:41:37:c7:50:2a:
         a5:d3:94:e0:2c:92:0d:08:62:b9:fe:fe:04:66:6c:95:04:34:
         1e:75:69:f0:2b:dd:d0:91:2d:08:10:a0:f2:d4:75:bb:4c:f0:
         4a:54:44:8b:92:3f:64:d1:16:44:c1:bc:fe:6b:34:df:06:a1:
         ab:57:f8:fd:74:67:6e:7a:18:27:14:58:99:3f:d2:d4:4d:4c:
         c5:16:19:db:68:f7:99:c5:97:be:bb:e6:e8:05:d3:6b:3e:b1:
         c7:1c:95:44:dd:a3:3c:25:df:24:7f:9e:7c:38:a8:9d:bd:08:
         32:10:1b:26
```

#### Start the LDAP server with TLS
The command below starts the LDAP server with TLS using the newly generated 
certificate:

```shell
$ docker run --rm \
  --name slapd \
  --hostname ldap.local \
  -p 6336:636 \
  -e LDAP_TLS_KEY=$(cat key.pem | gzip -9 | base64) \
  -e LDAP_TLS_CRT=$(cat crt.pem | gzip -9 | base64) \
  slapd
5b3d0c46 @(#) $OpenLDAP: slapd 2.4.45 (Nov  9 2017 20:08:19) $
	buildozer@build-3-7-x86_64:/home/buildozer/aports/main/openldap/src/openldap-2.4.45/servers/slapd
5b3d0c47 slapd starting
```

#### Query the server using TLS
The environment variable `LDAPTLS_CACERT` is used to specify a file
with one or more trusted certificate authorities. Use `LDAPTLS_CACERT`
with the self-signed certificate file to query the LDAP server's TLS
endpoint:

```shell
$ LDAPTLS_CACERT=crt.pem ldapwhoami \
  -H ldaps://localhost:6336 \
  -x -D "CN=root,DC=vmware,DC=local" -w admin 
dn:cn=root,dc=vmware,dc=local
```

### Seeding the server
The LDAP server can be seeded with LDIF data via environment variable and
by mapping a volume.

#### Seed by environment variable
The environment variable `LDAP_LDIF` may be used to seed the LDAP server
with LDIF content. The content must be base64-encoded.

##### Store gzipped, base64-encoded LDIF content in environment variable
```shell
$ export LDAP_LDIF=$(gzip -9 <<EOF | base64
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
$ VMCTF_LDAP_LDIF=$(gzip -9 <<EOF | base64
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
