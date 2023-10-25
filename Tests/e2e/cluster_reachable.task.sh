#!/usr/bin/env bash

set -e
set -o pipefail

curl -sk https://uitsmijter.localhost/ \
   | grep uitsmijter >/dev/null \
   || (echo 'Error: Uitsmijter not reachable' && exit 1)
