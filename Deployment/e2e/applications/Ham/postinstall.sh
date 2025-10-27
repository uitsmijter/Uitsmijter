#!/usr/bin/env bash

set -e
set -o pipefail

TIMEOUT=${K8S_TIMEOUT:-"5m"}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Setup S3 data FIRST, before applying the tenant
s3cmd="s3cmd --access_key=admin --secret_key=adminSecretKey --no-ssl --host=localhost:8333 --host-bucket=%\(bucket\).localhost"
files=$(find "${SCRIPT_DIR}" -name *.leaf)
numFiles=$(echo "$files" | wc -l)

# Forward S3 server port
kubectl -n uitsmijter-s3 port-forward svc/s3server "8333:8333" >/dev/null&
sleep 1

# Setup bucket
$s3cmd mb s3://bucketname || true

# Upload templates to bucket
for file in $files; do
    $s3cmd put --no-preserve "${file}" s3://bucketname/test/
done

# Get files in bucket
filesInS3=$($s3cmd ls --recursive s3://bucketname/test/ | wc -l)

# End port forward
kill %%

# Check that all files got uploaded successfully
if [[ "${filesInS3}" -lt "${numFiles}" ]]; then
    echo "Expected files not present in s3"
    exit 1
fi

# Now apply the tenant so it can load templates from S3
kubectl apply --server-side -f "${SCRIPT_DIR}/tenant.yaml"

# Wait until the ham web server pod is ready to use
kubectl -n ham wait --for=condition=ready pod --selector=app=ham-webserver --timeout=${TIMEOUT}
