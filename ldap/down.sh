#!/bin/sh

# posix compliant
# verified by https://www.shellcheck.net

set -e
set -o pipefail

govc vm.destroy -vm.ipath "/SDDC-Datacenter/vm/Workloads/ldap"
