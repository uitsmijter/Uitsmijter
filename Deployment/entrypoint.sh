#!/bin/bash

echo "Uitsmijter"
echo "------------------------------------------------------------"

# If no command is given, use the default
if [ $# -eq 0 ]; then
    exec /app/Uitsmijter serve --env production --hostname 0.0.0.0 --port 8080
else
    exec "$@"
fi