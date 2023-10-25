#!/usr/bin/env bash

set -e

OUTPUT_DIR=${1}
if [  -z ${OUTPUT_DIR} ]; then
	echo "ERROR: No OUTPUT_DIR is given."
	exit 1
fi

## TEST CASE: There should some be generated files in the output directory
IFS=$'\n'
FILES=($(find "${OUTPUT_DIR}" -name "*.yaml"))
unset IFS

if [ ${#FILES} -eq "0" ]; then
  echo "ERROR: No file found in ${OUTPUT_DIR}."
  exit 1
fi

exit 0
