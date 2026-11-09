#!/usr/bin/env bash
# Exporta la versión web y la publica en Vercel (proyecto "pythoria").
# Local: requiere las plantillas web de Godot 4.7 y `vercel login` hecho una vez.
# CI: usa VERCEL_TOKEN, VERCEL_ORG_ID y VERCEL_PROJECT_ID (secretos del repo).
# Uso: tools/deploy_web.sh            -> producción
#      tools/deploy_web.sh --preview  -> URL de prueba, sin tocar producción
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
# Sin threads no hacen falta cabeceras especiales. Los archivos se llaman igual en cada
# publicación (index.pck, index.wasm...), así que el navegador tiene que revisar siempre si
# hay una versión nueva; con el etag, si no cambió, no la vuelve a descargar.
cat > build/web/vercel.json <<'JSON'
{
  "headers": [
    {"source": "/(.*)", "headers": [{"key": "Cache-Control", "value": "public, max-age=0, must-revalidate"}]}
  ]
}
JSON
args=(deploy build/web --yes)
if [ "${1:-}" != "--preview" ]; then
  args+=(--prod)
fi
if [ -n "${VERCEL_TOKEN:-}" ]; then
  # En el CI el proyecto sale de VERCEL_ORG_ID y VERCEL_PROJECT_ID.
  args+=(--token "$VERCEL_TOKEN")
else
  args+=(--project pythoria --create-if-missing)
fi
vercel "${args[@]}"
