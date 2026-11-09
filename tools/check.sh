#!/usr/bin/env bash
# Importa el proyecto y corre los tests. Falla si hay errores de script o tests rotos.
# GODOT puede apuntar al ejecutable (por defecto "godot", en el CI otro camino).
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
# En un clon limpio la primera importación carga el tema antes que las fuentes y
# tira errores que no son reales: se hace una pasada previa sin mirar la salida.
if [ ! -d .godot/imported ]; then
  "$GODOT" --headless --path . --import >/dev/null 2>&1 || true
fi
log=$("$GODOT" --headless --path . --import 2>&1)
if echo "$log" | grep -E "SCRIPT ERROR|Parse Error|ERROR:" >/dev/null; then
  echo "$log" | grep -E -A2 "SCRIPT ERROR|Parse Error|ERROR:"
  echo "Import con errores"; exit 1
fi
echo "Import OK"
out=$("$GODOT" --headless --path . -s tests/run_tests.gd 2>&1)
code=$?
echo "$out" | grep -vE "^Godot Engine|^\s*$"
if echo "$out" | grep -E "SCRIPT ERROR|Parse Error" >/dev/null; then
  echo "Hubo errores de script durante los tests"; exit 1
fi
exit $code
