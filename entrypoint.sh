#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

if [ "$1" = "shell" ]; then exec /bin/sh; fi

# Set the working directory to the system being deployed.
cd "/tf" || true

# Do not proceed if the init phase fails.
if ! time terraform init \
          -backend-config "path=/tf/data/terraform.tfstate"; then
  exit $?
fi

case $1 in
deploy)
  if ! time terraform apply -auto-approve; then exit $?; fi
  ;;
destroy)
  if ! time terraform destroy -auto-approve; then exit $?; fi
  ;;
*)
  echo "invalid command: ${*}"
  exit 1
  ;;
esac