#!/usr/bin/env bash
# Importa el proyecto y corre los tests. Falla si hay errores de script o tests rotos.
set -u
cd "$(dirname "$0")/.."
log=$(godot --headless --path . --import 2>&1)
if echo "$log" | grep -E "SCRIPT ERROR|Parse Error|ERROR:" >/dev/null; then
  echo "$log" | grep -E -A2 "SCRIPT ERROR|Parse Error|ERROR:"
  echo "Import con errores"; exit 1
fi
echo "Import OK"
godot --headless --path . -s tests/run_tests.gd 2>&1 | grep -vE "^Godot Engine|^\s*$"
exit "${PIPESTATUS[0]}"
