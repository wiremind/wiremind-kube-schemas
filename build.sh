#!/bin/bash -xe

# This script uses openapi2jsonschema to generate a set of JSON schemas for
# the specified Kubernetes versions in three different flavours:
#
#   X.Y.Z - URL referenced based on the specified GitHub repository
#   X.Y.Z-standalone - de-referenced schemas, more useful as standalone documents
#   X.Y.Z-standalone-strict - de-referenced schemas, more useful as standalone documents, additionalProperties disallowed
#   X.Y.Z-local - relative references, useful to avoid the network dependency


# All k8s versions, starting from 1.14 to 1.22
K8S_VERSIONS=$(git ls-remote --refs --tags https://github.com/kubernetes/kubernetes.git | cut -d/ -f3 | grep -e '^v1\.[0-9]\{2\}\.[0-9]\{1,2\}$' | grep -v -e  '^v1\.1[0-3]\{1\}' | grep -v -e  '^v1\.[0-9][0-9].[1-9]\{1\}' )
YQBIN="docker run --rm -v "${PWD}":/workdir mikefarah/yq"

if [ -n "${K8S_VERSION_PREFIX}" ]; then
  export K8S_VERSIONS=$(git ls-remote --refs --tags https://github.com/kubernetes/kubernetes.git | cut -d/ -f3 | grep -e '^'${K8S_VERSION_PREFIX} | grep -e '^v1\.[0-9]\{2\}\.[0-9]\{1,2\}$')
fi

if [ -z "$1" ]; then
  echo "Provide a valid crds path as first argument"
  exit 84
fi

directory_name=`readlink -f $1`
directory_name=`realpath --relative-to=${PWD} ${directory_name}`
extension='yaml'

for filename in $directory_name/*.yaml; do
  # Format output name
  output_name=`$YQBIN '.spec.names.kind' "${filename}"`
  output_name="${output_name}-`$YQBIN '.spec.group' "${filename}" | cut -d . -f 1`"
  output_name="${output_name}-`$YQBIN '.spec.versions[0].name' "${filename}"`"
  output_name="${output_name}.json"
  output_name=`echo ${output_name} | tr '[:upper:]' '[:lower:]'`

  for K8S_VERSION in $K8S_VERSIONS master; do
    if [ -d "${K8S_VERSION}-standalone" ]; then
      # Convert yaml to json
      $YQBIN -o=json '.' "${filename}" > "${K8S_VERSION}-standalone/${output_name}"
    fi
  done
done
