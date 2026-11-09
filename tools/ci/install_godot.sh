#!/usr/bin/env bash
# Instala Godot (Linux, para GitHub Actions) y, si se pide, las plantillas de exportación web.
# Uso: tools/ci/install_godot.sh [--web-templates]
# Deja el ejecutable en $GODOT_HOME/godot (por defecto ~/godot). Si ya está, no descarga nada
# (el workflow guarda ~/godot y las plantillas en la caché de Actions).
set -euo pipefail
VERSION="${GODOT_VERSION:-4.7.2}"
HOME_DIR="${GODOT_HOME:-$HOME/godot}"
BASE="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"
mkdir -p "$HOME_DIR"
if [ ! -x "$HOME_DIR/godot" ]; then
  curl -sSfL -o /tmp/godot.zip "$BASE/Godot_v${VERSION}-stable_linux.x86_64.zip"
  unzip -q -o /tmp/godot.zip -d /tmp/godot
  mv "/tmp/godot/Godot_v${VERSION}-stable_linux.x86_64" "$HOME_DIR/godot"
  chmod +x "$HOME_DIR/godot"
fi
"$HOME_DIR/godot" --version
if [ "${1:-}" = "--web-templates" ]; then
  TPL="$HOME/.local/share/godot/export_templates/${VERSION}.stable"
  if [ ! -f "$TPL/web_nothreads_release.zip" ]; then
    mkdir -p "$TPL"
    # El paquete completo pesa ~1.2 GB; solo se extraen las plantillas web sin threads.
    curl -sSfL -o /tmp/templates.tpz "$BASE/Godot_v${VERSION}-stable_export_templates.tpz"
    unzip -q -o -j /tmp/templates.tpz templates/version.txt templates/web_nothreads_release.zip templates/web_nothreads_debug.zip -d "$TPL"
    rm /tmp/templates.tpz
  fi
  ls "$TPL"
fi
