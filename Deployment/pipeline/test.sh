#!/usr/bin/env bash

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
cd "${PROJECT_DIR}"

mkdir -p .build/testresults

BUILD_DB=$(find .build/"$(uname -m)"-* -name build.db | head -n 1) || true
if [ -f "${BUILD_DB}" ]; then
  echo "Build info:"
  sqlite3 -cmd ".timeout 500" "${BUILD_DB}" "SELECT * FROM info"
fi

CPU_COUNT=$(grep --count ^processor /proc/cpuinfo || echo 2)
echo "Running tests with ${CPU_COUNT} workers."
swift test --scratch-path .build --num-workers ${CPU_COUNT} --parallel \
  --enable-code-coverage \
  --xunit-output .build/testresults/xunit.xml \
  ${FILTER_TEST} \
  -Xcc -I/usr/include/webkitgtk-4.0 \
  -Xcc -I/usr/include/webkitgtk-4.0/JavaScriptCore

sleep 1

cat "$(swift test --show-codecov-path)" | jq "del(.data[].files[].segments[])" >.build/testresults/coverage.json
java -jar Deployment/Coverify-1.0-SNAPSHOT.jar .build/testresults/coverage.json >.build/testresults/coverage.xml

echo "Checking Project Requirements..."
TEST_FAILS=$(cat .build/testresults/xunit.xml | grep "failure" | grep -v 'failures="0"' | wc -l)
if [ "${TEST_FAILS}" -gt "0" ]; then
  cat .build/testresults/xunit.xml
  echo "!!! Test failed !!!"
  exit 1
fi

echo "Tests: OK"
