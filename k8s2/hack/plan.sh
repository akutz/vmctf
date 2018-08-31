#!/bin/sh

hackd=$(python -c "import os; print(os.path.realpath('$(dirname "${0}")'))")
cd "${hackd}/.." && terraform plan
