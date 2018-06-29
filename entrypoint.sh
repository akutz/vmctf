#!/bin/sh

if [ "$1" = "shell" ]; then exec /bin/sh; fi

if [ -z "$2" ]; then
  echo "usage: deploy|destroy NAME"
  exit 1
fi

# Create a data directory for the system being deployed
mkdir -p "/tf/data/${2}"

# Set the working directory to the system being deployed.
cd "${2}"

# Do not proceed if the init phase fails.
if ! time terraform init \
          -backend-config "path=/tf/data/${2}/terraform.tfstate"; then
  exit $?
fi

case $1 in
deploy)
  if [ -e "deploy.sh" ]; then exec "./deploy.sh"; fi
  if ! time terraform apply -auto-approve "/tf/${2}"; then exit $?; fi
  ;;
destroy)
  if [ -e "destroy.sh" ]; then exec "./destroy.sh"; fi
  if ! time terraform destroy -auto-approve "/tf/${2}"; then exit $?; fi
  ;;
*)
  echo "invalid command: ${*}"
  exit 1
  ;;
esac