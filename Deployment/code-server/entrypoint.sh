#!/usr/bin/env bash

echo "Uitsmijter Code Server"
echo "-----------------------------------------------------------------------------------"
echo ""
echo "Starting Code-Server"
code-server \
  --disable-telemetry \
  --extensions-dir /extensions

echo "-----------------------------------------------------------------------------------"
echo "Ready."
echo ""

