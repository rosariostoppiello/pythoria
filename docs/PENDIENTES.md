# Pendientes, decisiones y errores conocidos

## Decisiones tomadas (no estaban definidas)

- **Archivos movidos**: `DISENO.md` → `docs/`, `worlds.json` → `data/`, `PROMPT_CLAUDE_CODE.md` → `docs/` (estaban en la raíz).
- **Tema generado desde código**: `resources/ui_theme.tres` se genera con `godot --headless --path . -s tools/gen_theme.gd` a partir de `scripts/core/theme_colors.gd`. Así los colores viven en un solo lugar. Si cambiás la paleta, volvé a correr ese comando.
- **Fuentes**: se usan las versiones variables oficiales de Google Fonts (`Fredoka`, `FiraCode`, `Nunito`) con `FontVariation` para elegir el peso. Licencias OFL junto a cada fuente.
- **Acciones de entrada** (`move_*`, `interact`, `pause`) se registran en código en `SceneManager._setup_inputs()` en vez de en `project.godot`, para no depender del editor.
- **Interfaz armada en código**: las escenas `.tscn` tienen solo el nodo raíz con su script; la interfaz se construye en `_ready()` con los helpers de `scripts/ui/ui.gd` y el tema central. Es más fácil de mantener sin el editor y garantiza que no haya colores sueltos en escenas.
- **Tests**: runner propio (`tests/run_tests.gd`) en vez de GUT, sin dependencias externas. `tools/check.sh` corre el import y los tests.
