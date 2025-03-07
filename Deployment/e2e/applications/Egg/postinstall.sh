#!/usr/bin/env bash

TIMEOUT=${K8S_TIMEOUT:-"5m"}

# Wait until the cookbooks web server pod is ready to use
kubectl wait --for=condition=ready pod --timeout=${TIMEOUT} --selector=app=yolk-webserver -n egg
