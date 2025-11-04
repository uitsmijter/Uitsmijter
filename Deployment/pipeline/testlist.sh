#!/usr/bin/env bash

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
cd "${PROJECT_DIR}"

CPU_COUNT=$(grep --count ^processor /proc/cpuinfo || echo 2)
echo "Listing tests with ${CPU_COUNT} workers."

INCLUDES=$(pkg-config --cflags-only-I javascriptcoregtk-4.1 2>/dev/null | sed 's/-I/ -Xcc -I/g' || echo " -Xcc -I/usr/include/webkitgtk-4.1 -Xcc -I/usr/include/webkitgtk-4.1/JavaScriptCore")
LIBS=$(pkg-config --libs javascriptcoregtk-4.1 2>/dev/null | sed 's/-l/ -Xlinker -l/g' || echo "")

# Debug: Show filter if set
if [ -n "${FILTER_TEST}" ]; then
  echo "Test filter: ${FILTER_TEST}"
else
  echo "No test filter set - listing all tests"
fi

# Configure output filtering based on SUPPRESS_PACKAGE_WARNINGS environment variable
if [ "${SUPPRESS_PACKAGE_WARNINGS:-false}" = "true" ]; then
  # Filter out package manifest warnings from dependencies, then remove trailing ()
  swift test list ${FILTER_TEST} ${INCLUDES} ${LIBS} 2>&1 | \
    grep -v "warning:.*found .* file(s) which are unhandled" | \
    grep -v "^\s*/.*/.build/checkouts/.*/.*\.swift" | \
    sed 's/()$//'
else
  # Show all output including package warnings, then remove trailing ()
  swift test list ${FILTER_TEST} ${INCLUDES} ${LIBS} | \
    sed 's/()$//'
fi
