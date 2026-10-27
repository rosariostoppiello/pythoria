# Prompt para Claude Code (pegar completo)

Sos el desarrollador del proyecto **Pythoria** (PyMancer), un juego educativo en Godot 4.7 para aprender Python como un aprendiz de magia, con objetivo de exportar a web. Trabajás en esta carpeta, que ya es un repo git con remoto `https://github.com/rosariostoppiello/pythoria.git` (rama `main`).

## Antes de empezar

1. Leé `CLAUDE.md`, `docs/DISENO.md` y `data/worlds.json`. Si esos archivos están en la raíz en vez de en `docs/` y `data/`, movelos a su lugar. Son la fuente de verdad: no cambies decisiones de diseño sin anotarlo en `docs/PENDIENTES.md`.
2. Confirmá `godot --version` (debe ser 4.7.x) y que Python 3 con Pillow esté disponible (`pip3 install pillow` si falta).
3. Creá una lista de tareas con las fases de abajo y andá marcándolas.

## Cómo trabajar

- Hacé todo de corrido, fase por fase, sin pedirme confirmación entre fases. Si una decisión menor no está definida, elegí lo más simple, aplicalo y anotalo en `docs/PENDIENTES.md`.
- Un commit por fase. Hacé `git push origin main` al terminar cada fase; si el push falla por credenciales, seguí con commits locales y avisame al final.
- Antes de cada commit: `godot --headless --path . --import` sin errores y los tests pasando.
- No puedo ver lo que hacés mientras trabajás. Al final tiene que quedar algo que yo pueda abrir en Godot y jugar con F5.

## Fases

**A. Esqueleto.** Crear `project.godot` (1280x720, stretch `canvas_items`, renderer `gl_compatibility`, escena principal = menú), la estructura de carpetas de `CLAUDE.md`, `.gitignore` para Godot (`.godot/`, `build/`, etc.), autoloads (`GameState`, `SaveSystem`, `SceneManager`, `ContentDB`), `scripts/core/theme_colors.gd` con la paleta y un `resources/ui_theme.tres` con paneles de pergamino, botones violeta y las fuentes. Descargá Fredoka, Fira Code y Nunito (Google Fonts) a `assets/fonts/`; si no podés descargarlas, usá la fuente por defecto y anotalo.

**B. Arte placeholder.** Escribí `tools/gen_sprites.py` (Pillow) que genere en `assets/sprites/` los PNG con fondo transparente listados en `CLAUDE.md`, en pixel art con la paleta fija, escalados a tamaños razonables (personajes 32x32 o 48x48, casitas 48x48, tiles 32x32). Que se lean como lo que son: aprendiz con sombrero violeta y capa, Ada con anteojos y capa celeste, búho violeta, gato naranja, Gremlin rojo, fantasma, quimera, Ouroboros, frasco, caldero, grimorio, taza, vela con libros, casitas (bloqueada, abierta, completada), pasto, camino, agua, árbol, nodos del mapa. Ejecutalo y commiteá los PNG. Configurá los sprites con filtro `nearest` (sin suavizado).

**C. Escenas y estados.** Menú principal (Jugar, Continuar si hay guardado, Opciones placeholder, Salir), mapa de mundos, mapa de sección, nivel, pausa (Esc) y resultado. `SceneManager` maneja las transiciones y el estado (`MENU`, `WORLD_MAP`, `SECTION_MAP`, `LEVEL`, `PAUSED`, `RESULT`). Todo con el tema centralizado, sin hex en escenas. Barra superior en nivel: "Mundo N · Nivel M", barra de XP y racha.

**D. Guardado.** `SaveSystem` escribe y lee `user://save.json` con el formato de `docs/DISENO.md`, tolerante a claves faltantes y con `version`. `GameState` lleva XP, nivel (`floor(sqrt(xp/50))+1`), racha por fecha, niveles completados y pistas usadas. XP no se da dos veces por el mismo nivel.

**E. Prototipo "hola mundo" jugable.** En el mapa de sección, el aprendiz (CharacterBody2D) se mueve con flechas/WASD, con animación simple de caminar o respirar (2 o 3 frames o un tween), y colisiona contra árboles, agua y casitas. Al acercarse a una casita disponible y apretar Espacio/Enter, entra al nivel. Probalo con un script headless que verifique que la colisión bloquea el paso.

**F. Mapa de mundos.** Dibujá los 8 nodos de `data/worlds.json` unidos por una línea punteada (se puede hacer con `_draw()` o `Line2D` con textura punteada). Estados: completado, actual, bloqueado. El aprendiz aparece en el nodo actual. Al completar el boss de un mundo, el aprendiz se mueve con un tween por la línea al siguiente y este se desbloquea. Seleccionar un nodo desbloqueado abre su mapa de sección.

**G. Mapas de sección y desbloqueo.** Generar cada mapa de sección desde `data/worlds.json` (posiciones de casitas en grilla de 64 px, árboles y agua de decoración). Las casitas se desbloquean en orden; el boss requiere los 5 niveles y el minijuego. Estados visuales: candado, puerta con luz, estrella dorada. En mundos `placeholder`, las casitas abren una pantalla "Próximamente" con botón "Completar (debug)" que solo aparece si `OS.is_debug_build()`.

**H. Mecánica del Frasco y Mundo 1.** Implementá la mecánica descrita en `docs/DISENO.md` sección 4: frascos con nombre y tipo, fichas arrastrables (drag and drop de Control), selector de operador, caldero, código Python equivalente en vivo con Fira Code, botón Lanzar, evaluador propio con semántica de Python (int + str es TypeError, `==` da bool, `*` e `+` entre ints, `+` entre strs, f-string con `{nombre}`). Errores: Quimera Tipos para TypeError, Fantasma Sin Nombre para frasco vacío, mensaje de "obtuviste X, el caldero pedía Y" para resultado distinto. Pistas de Ada en 3 niveles con la vela que se enciende, costando XP. Reintento inmediato sin penalización. Los 5 niveles, el minijuego "Completa el hechizo" y el boss Gremlin Sintaxis salen de `data/worlds.json`. Pantalla de resultado con XP ganado y criatura según éxito o fallo. Lo que cumpla `solution` o `solution_any` o simplemente dé el valor objetivo cuenta como correcto (evaluá el resultado, no compares contra una única solución).

**I. Testing.** Escribí tests (GUT si lo podés instalar sin complicaciones; si no, `tests/run_tests.gd` ejecutable con `godot --headless --path . -s tests/run_tests.gd` que salga con código distinto de cero si algo falla). Cubrir: evaluador (suma int, concatenación str, TypeError int+str, igualdad, f-string), carga de `worlds.json` (todos los niveles válidos y resolubles con sus soluciones), guardado (guardar, cargar, claves faltantes, XP sin duplicar), desbloqueo en orden, fórmula de nivel, colisión del jugador. Corré todo y arreglá lo que falle.

**J. Exportación web e intentos finales.** Intentá instalar las plantillas de exportación de Godot 4.7 (descarga del `.tpz` oficial y extracción en el directorio de templates) y crear `export_presets.cfg` para Web (sin threads si la opción existe, así no hacen falta cabeceras especiales). Exportá a `build/web/` y probalo con un servidor estático local (`python3 -m http.server`). Si no se puede, dejalo documentado en `docs/PENDIENTES.md` con los pasos para hacerlo a mano desde el editor, y seguí.

## Entregables finales

- Código, escenas y datos commiteados y pusheados.
- `docs/PRUEBA_MANUAL.md`: pasos exactos para que yo pruebe cada pantalla en Godot (cómo abrir, qué apretar, qué debería pasar).
- `docs/PENDIENTES.md`: decisiones que tomaste, cosas que no pudiste hacer y por qué, y errores conocidos.
- Un resumen corto final: qué funciona, qué no, y qué tengo que probar yo a mano.

No agregues editor Monaco, Pyodide, login, backend, IA ni ranking: están fuera del alcance de hoy.
