#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

COMMAND="${1}"

if [ ! "${COMMAND}" = "deploy" ] && \
   [ ! "${COMMAND}" = "destroy" ]; then \
   echo "usage: ${0} deploy|destroy"
   exit 1
fi

# Use an environment variable file to prevent the process list
# from echoing sensitive credential information.
ENVS_FILE=$(mktemp)

# echo_env_var writes an environment variable and its value to
# ENVS_FILE as long as the value is not empty
echo_env_var() {
  if [ -n "$(echo "${1}" | sed 's/^[^=]*=//g')" ]; then 
    echo "${1}" >> "${ENVS_FILE}"
  fi
}

echo_env_var VSPHERE_SERVER="${VSPHERE_SERVER}"
echo_env_var VSPHERE_USER="${VSPHERE_USER}"
echo_env_var VSPHERE_PASSWORD="${VSPHERE_PASSWORD}"
echo_env_var AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
echo_env_var AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
echo_env_var AWS_REGION="${AWS_REGION}"

# Find all of the environment variables prefixed with TF_VAR_
for e in $(env | grep TF_VAR_); do 
  echo_env_var "${e}"
done

#if [ "${COMMAND}" = "deploy" ]; then echo "${ENVS_FILE}" && exit 1; fi

# Launch the container.
docker run \
  --rm \
  --name "${CONTAINER_NAME:-cnx-cicd}" \
  --env-file "${ENVS_FILE}" \
  -v "$(pwd)/data":/tf/data \
  cnx-cicd \
  "${COMMAND}" \
  "${NAME}"

# Save the docker command's exit code.
exit_code=$?

# Remove the environment variable file.
rm -f "${ENVS_FILE}"

# Exit the script using the docker command's exit code.
exit $exit_code