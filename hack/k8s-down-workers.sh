#!/bin/sh

hackd=$(python -c "import os; print(os.path.realpath('$(dirname "${0}")'))")
cd "${hackd}/../k8s" && terraform destroy -auto-approve -target vsphere_virtual_machine.worker_virtual_machine
