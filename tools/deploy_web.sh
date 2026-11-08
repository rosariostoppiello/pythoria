#!/usr/bin/env bash
# Exporta la versión web y la publica en Vercel (proyecto "pythoria").
# Requiere: plantillas web de Godot 4.7 instaladas y `vercel login` hecho una vez.
# Uso: tools/deploy_web.sh            -> producción
#      tools/deploy_web.sh --preview  -> URL de prueba, sin tocar producción
set -euo pipefail
cd "$(dirname "$0")/.."
rm -rf build/web && mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
# Sin threads no hacen falta cabeceras especiales; solo cache razonable para el .wasm y el .pck.
cat > build/web/vercel.json <<'JSON'
{
  "headers": [
    {"source": "/(.*)\\.(wasm|pck)", "headers": [{"key": "Cache-Control", "value": "public, max-age=3600"}]}
  ]
}
JSON
if [ "${1:-}" = "--preview" ]; then
  vercel deploy build/web --yes --project pythoria --create-if-missing
else
  vercel deploy build/web --prod --yes --project pythoria --create-if-missing
fi
