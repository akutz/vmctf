#!/bin/sh

hackd=$(python -c "import os; print(os.path.realpath('$(dirname "${0}")'))")
cd "${hackd}/../k8s" && terraform plan \
  -target data.vsphere_virtual_machine.template \
  -target vsphere_virtual_machine.master
