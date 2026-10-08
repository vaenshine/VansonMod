#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d)"
xcrun clang++ -fobjc-arc -framework Foundation -I"$ROOT" \
  -fsanitize=address,undefined -fno-omit-frame-pointer \
  "$ROOT/tests/StringMemorySessionTests.mm" \
  "$ROOT/src/ui/memory/VMStringMemorySession.mm" \
  -o "$TEST_DIR/string-memory-tests"
"$TEST_DIR/string-memory-tests"
