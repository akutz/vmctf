#!/bin/sh

# posix complaint
# verified by https://www.shellcheck.net

if [ -z "${COMMAND}" ]; then COMMAND="${1:-shell}"; fi
if [ -z "${NAME}" ]; then NAME="${2:-openldap}"; fi

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

# Find all of the environment variables prefixed with VMCTF_
for e in $(env | grep VMCTF_); do 
  n=$(echo "${e}" | sed 's/VMCTF_//g')
  k=$(echo "${n}" | awk -F= '{print $1}')
  v=$(echo "${n}" | sed 's/^[^=]*=//g')
  echo_env_var "${k}=${v}"
  echo_env_var "TF_VAR_$(echo "${k}" | awk '{print tolower($0)}')=${v}"
done

#if [ "${COMMAND}" = "deploy" ]; then echo "${ENVS_FILE}" && exit 1; fi

# Launch the container.
docker run \
  --rm \
  --name ${CONTAINER_NAME:-vmctf} \
  --env-file "${ENVS_FILE}" \
  -v "$(pwd)/data":/tf/data \
  vmctf \
  "${COMMAND}" \
  "${NAME}"

# Save the docker command's exit code.
exit_code=$?

# Remove the environment variable file.
rm -f "${ENVS_FILE}"

# Exit the script using the docker command's exit code.
exit $exit_code