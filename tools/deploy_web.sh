#!/usr/bin/env bash
# Exporta la versión web y la publica en Vercel (proyecto "pythoria").
# Local: requiere las plantillas web de Godot 4.7 y `vercel login` hecho una vez.
# CI: usa VERCEL_TOKEN, VERCEL_ORG_ID y VERCEL_PROJECT_ID (secretos del repo).
# Uso: tools/deploy_web.sh               -> producción
#      tools/deploy_web.sh --preview     -> URL de prueba, sin tocar producción
#      tools/deploy_web.sh --build-only  -> solo exporta a build/web (para probar local)
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
rm -rf build/web && mkdir -p build/web
"$GODOT" --headless --path . --export-release "Web" build/web/index.html
# El juego se baja por código (fetch), y una recarga normal no siempre salta la caché del
# navegador: se renombra index.pck con un hash de su contenido para que cada publicación
# use un nombre nuevo que el navegador nunca tuvo guardado.
python3 - <<'PY'
import hashlib, pathlib, re, sys
web = pathlib.Path("build/web")
pck = web / "index.pck"
name = "index-%s.pck" % hashlib.sha1(pck.read_bytes()).hexdigest()[:10]
pck.rename(web / name)
html = (web / "index.html").read_text()
new, n1 = re.subn(r'"fileSizes":\{"index\.pck"', '"fileSizes":{"%s"' % name, html)
new, n2 = re.subn(r'"executable":"index"', '"executable":"index","mainPack":"%s"' % name, new)
if n1 != 1 or n2 != 1:
    sys.exit("No se pudo apuntar index.html a %s (cambió el formato del export de Godot)" % name)
(web / "index.html").write_text(new)
print("Paquete del juego:", name)
PY
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
if [ "${1:-}" = "--build-only" ]; then
  exit 0
fi
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
