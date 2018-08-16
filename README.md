# CNX CICD Environment Provisioner
This project is used to provision the CNX CICD environment to vSphere
running on VMC.

## Overview
The CNX CICD environment consists of the following systems:

| System | Description |
|--------|-------------|
| `api.cicd.cnx.cna.vmware.run` | A Kubernetes cluster for scheduling CICD-related workloads. |
| `jump.cicd.cnx.cna.vmware.run` | A jump host for accessing the hosts that do not have SSH publicly available. |
| `ldap.cicd.cnx.cna.vmware.run` | An OpenLDAP system that provides identity control for the VMC vSphere environment. |

## Build
Build the docker image from this directory with the following command:

```shell
$ docker build -t cnx-cicd .
```

## Configuration
The environment variables listed below are common to all of the Terraform
scripts in this repository:

| Environment Variable | Description |
|------|-------------|
| `VSPHERE_SERVER` | The IP/FQDN of the vSphere server |
| `VSPHERE_USER` | A vSphere username used to create/destroy vSphere resources |
| `VSPHERE_PASSWORD` | The password for `VSPHERE_USER` |

The script `run.sh` (described below) automatically provides all environment
variables prefixed with `TF_VAR_` to the Docker image.

## Provision
New systems may be provisioned with the script `run.sh`:

```shell
usage: run.sh deploy|destroy
```

This script automatically provides all environment variables prefixed with 
`TF_VAR_` to the Docker image via a temporary file. A temp file is used to
prevent the process list from reflecting possibly sensitive information.