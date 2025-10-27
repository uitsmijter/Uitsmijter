#!/bin/bash

echo "Uitsmijter"
echo "------------------------------------------------------------"
echo "Running dirty version for testing purposes only"
echo ""

cd /app
exec ./Uitsmijter serve --env production --hostname 0.0.0.0 --port 8080
#exec ./Uitsmijter
