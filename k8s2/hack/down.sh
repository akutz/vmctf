#!/bin/sh

hackd=$(python -c "import os; print(os.path.realpath('$(dirname "${0}")'))")
cd "${hackd}/.." || exit 1 #&& terraform destroy -auto-approve

for i in 1 2 3; do
  govc vm.destroy "/SDDC-Datacenter/vm/Workloads/k8s-c0${i}" >/dev/null 2>&1
  govc vm.destroy "/SDDC-Datacenter/vm/Workloads/k8s-w0${i}" >/dev/null 2>&1
done

rm -fr .terraform.tfstate* terraform.tfstate*
