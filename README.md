# VMC Terraform Scripts
This project contains Terraform scripts for deploying systems to
VMware Cloud (VMC) on AWS.

## Build
Build the docker image from this directory with the following command:

```shell
$ docker build -t vmctf .
```

## Configuration
The environment variables listed below are common to all of the Terraform
scripts in this repository:

| Environment Variable | Description |
|------|-------------|
| `VSPHERE_SERVER` | The IP/FQDN of the vSphere server |
| `VSPHERE_USER` | A vSphere username used to create/destroy vSphere resources |
| `VSPHERE_PASSWORD` | The password for `VSPHERE_USER` |

## Provision
New systems may be provisioned with the script `run.sh`:

```shell
usage: run.sh deploy|destroy SYSTEM
```

Supported systems are:

* `openldap`

### Transforming Environment Variables
The script looks for environment variables with the prefix `VMCTF_(.*)` and
writes them to a temporary file as `$1` and `TF_VAR_lcase($1)`. For example:

```shell
$ export VMCTF_NAME=hello
$ export VMCTF_FQDN=hello.com
```

The script will create a temporary file with the following contents:

```shell
NAME=hello
TF_VAR_name=hello
FQDN=hello
TF_VAR_fqdn=hello
```

The temporary file is used as the environment variable file when
launching a new container for the Docker image `vmctf`.