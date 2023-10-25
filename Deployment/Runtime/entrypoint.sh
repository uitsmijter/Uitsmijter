#!/bin/bash

echo "Uitsmijter"
echo "------------------------------------------------------------"
echo "Run dirty version for testing purpose only"
echo ""

cd /app
exec ./Uitsmijter serve --env production --hostname 0.0.0.0 --port 8080
