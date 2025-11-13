#!/usr/bin/env bash

#set -e
#set -o pipefail

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
EXTRA=""
if [  -n "${DEBUG}" ]; then
  EXTRA=" -v"
fi
INCLUDES=$(pkg-config --cflags-only-I javascriptcoregtk-4.1 2>/dev/null | sed 's/-I/ -Xcc -I/g' || echo " -Xcc -I/usr/include/webkitgtk-4.1 -Xcc -I/usr/include/webkitgtk-4.1/JavaScriptCore")
LIBS=$(pkg-config --libs javascriptcoregtk-4.1 2>/dev/null | sed 's/-l/ -Xlinker -l/g' || echo "")

# Debug: Show filter if set
if [ -n "${FILTER_TEST}" ]; then
  echo "Test filter: ${FILTER_TEST}"
fi

# Configure output filtering based on SUPPRESS_PACKAGE_WARNINGS environment variable
if [ "${SUPPRESS_PACKAGE_WARNINGS:-false}" = "true" ]; then
  # Filter out package manifest warnings from dependencies
  echo "with suppressed package warnings."
  DISABLE_FILE_MONITORING=true swift test --scratch-path .build --num-workers ${CPU_COUNT} --parallel ${EXTRA} \
    --enable-code-coverage \
    --xunit-output .build/testresults/xunit.xml \
    ${FILTER_TEST} \
    ${INCLUDES} ${LIBS} 2>&1 | \
    grep -v "warning:.*found .* file(s) which are unhandled" | \
    grep -v "^\s*/.*/.build/checkouts/.*/.*\.swift"
else
  # Show all output including package warnings
  DISABLE_FILE_MONITORING=true swift test --scratch-path .build --num-workers ${CPU_COUNT} --parallel ${EXTRA} \
    --enable-code-coverage \
    --xunit-output .build/testresults/xunit.xml \
    ${FILTER_TEST} \
    ${INCLUDES} ${LIBS}
fi

sleep 1

if [ -f "$(swift test --show-codecov-path)" ]; then
    cat "$(swift test --show-codecov-path)" | jq "del(.data[].files[].segments[])" >.build/testresults/coverage.json
    java -jar Deployment/Coverify-1.0-SNAPSHOT.jar .build/testresults/coverage.json >.build/testresults/coverage.xml
fi

echo "Checking Project Requirements..."
TEST_FAILS=$(cat .build/testresults/xunit.xml | grep "failure" | grep -v 'failures="0"' | wc -l)
if [ "${TEST_FAILS}" -gt "0" ]; then
  cat .build/testresults/xunit.xml
  echo "!!! Test failed !!!"
  exit 1
fi

echo "Tests: OK"
