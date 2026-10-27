# Pendientes, decisiones y errores conocidos

## Decisiones tomadas (no estaban definidas)

- **Archivos movidos**: `DISENO.md` → `docs/`, `worlds.json` → `data/`, `PROMPT_CLAUDE_CODE.md` → `docs/` (estaban en la raíz).
- **Tema generado desde código**: `resources/ui_theme.tres` se genera con `godot --headless --path . -s tools/gen_theme.gd` a partir de `scripts/core/theme_colors.gd`. Así los colores viven en un solo lugar. Si cambiás la paleta, volvé a correr ese comando.
- **Fuentes**: se usan las versiones variables oficiales de Google Fonts (`Fredoka`, `FiraCode`, `Nunito`) con `FontVariation` para elegir el peso. Licencias OFL junto a cada fuente.
- **Acciones de entrada** (`move_*`, `interact`, `pause`) se registran en código en `SceneManager._setup_inputs()` en vez de en `project.godot`, para no depender del editor.
- **Interfaz armada en código**: las escenas `.tscn` tienen solo el nodo raíz con su script; la interfaz se construye en `_ready()` con los helpers de `scripts/ui/ui.gd` y el tema central. Es más fácil de mantener sin el editor y garantiza que no haya colores sueltos en escenas.
- **Tests**: runner propio (`tests/run_tests.gd`) en vez de GUT, sin dependencias externas. `tools/check.sh` corre el import y los tests.
- **Paleta del pixel art**: además de los 8 colores fijos se usan los colores de mundo de `data/worlds.json` (verde, naranja, azul, marrón, gris) para naturaleza y detalles (pasto, árboles, agua, gato, libros). Dorado solo en recompensas (estrella, banda del sombrero, nodo completado), rojo solo en criaturas del Caos.
- **Sprites extra** además de los de CLAUDE.md: `candle_books_lit` (vela encendida para las pistas) y `star` (recompensa en la pantalla de resultado).
- **Filtro nearest** global en `project.godot` (`default_texture_filter=0`) para que todo el pixel art se vea nítido.
- **Pausa y resultado como overlays**: se agregan encima de la escena actual (CanvasLayer), así "Reintentar" después de un fallo cierra el resultado y deja el tablero como estaba (reintento inmediato).
- **Jugar con partida guardada**: pide confirmación antes de borrar el progreso. "Continuar" aparece solo si existe `user://save.json`.
- **Salir** no se muestra en la versión web (no se puede cerrar la pestaña desde el juego).
- **Esc en el mapa de sección** también abre la pausa (con "Mapa de mundos" y "Menú").
- **Pistas y XP**: cada pista baja la recompensa del nivel (50 − 10 por pista, mínimo 10); no se descuenta XP ya ganado. Máximo 3 pistas por nivel. El minijuego y el boss no tienen pistas y dan 100 y 200 XP.
- **Racha**: se actualiza al resolver cualquier casita (aunque sea repetida), comparando la fecha local `YYYY-MM-DD` con `last_played_day`.
- **Guardado ilegible** (JSON roto): se ignora con un aviso y se arranca con valores por defecto; el archivo se reescribe en el próximo guardado.
- **Mapa de sección**: grilla de 64 px generada con `SectionLayout` (determinista por mundo). El camino se calcula con BFS entre el inicio y la puerta de cada casita (la celda de abajo), y los árboles y el agua nunca se ponen pegados al camino, así todas las puertas son alcanzables. El mapa mide (x máx de casitas + 3) × 11 celdas y la cámara sigue al aprendiz.
- **Animación del aprendiz**: saltito de 2 frames al caminar y "respiración" (escala vertical) quieto, sin sprites extra.
- **Texturas en `_draw()`**: con el renderer de compatibilidad de Godot 4.7, una textura cargada dentro del primer `_draw()` se pinta blanca. Se cargan en `_ready()` y se redibuja un frame después.
