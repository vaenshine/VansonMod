#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
xcrun clang++ -std=c++17 -fblocks -g -O1 \
  -fsanitize=address,undefined -fno-sanitize-recover=all \
  "$ROOT/tests/IntegerScanTests.cpp" \
  "$ROOT/src/memory/core/MemoryCore.cpp" \
  -o "$TEST_DIR/integer-scan-tests"
"$TEST_DIR/integer-scan-tests" "$TEST_DIR"
