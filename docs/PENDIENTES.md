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
- **Mapa de mundos**: la línea punteada se dibuja con `_draw()` (puntos cada 18 px), en lavanda hasta donde llegaste y gris después. `current_world` del guardado es donde está parado el aprendiz; si es menor que el último mundo desbloqueado (porque venciste un boss), al abrir el mapa camina por la línea hasta el nuevo nodo, que aparece con un "pop", y se guarda.
- **Mundos 4 a 8**: si se llegaran a desbloquear (solo posible con el botón debug), se muestran como "Próximamente" y no se puede entrar porque no tienen casitas en el JSON.
- **Casitas de boss**: el techo se tiñe rojizo cuando están disponibles, para distinguirlas (sin sprite extra).
- **Casitas de mundos placeholder** (2 y 3): abren "Próximamente" con los temas del mundo; el botón "Completar (debug)" solo existe si `OS.is_debug_build()` (en el editor sí, en un export release no).
- **Frascos sin restricción de tipo**: cada frasco muestra qué esencia espera ("esencia: int (número)"), pero acepta cualquier ficha, como una variable de Python. Si se mezclan tipos, el error aparece al Lanzar (Quimera Tipos). Si el frasco rechazara la ficha, la Quimera nunca podría aparecer.
- **Fichas de un solo uso**: cada ficha va a un frasco a la vez (por eso w1_l4 trae dos 7). Tocar una ficha la pone en el primer frasco vacío; tocar un frasco lo vacía; también se arrastra de un frasco a otro o de vuelta a la bandeja.
- **Correcto = valor y tipo**: se evalúa la expresión y se compara con `goal` (mismo valor y mismo tipo de Python: `True` no cuenta como `1`). No se compara contra `solution`; esas soluciones se usan solo en los tests para comprobar que cada nivel se puede resolver.
- **Sin operador elegido** en niveles con `OP`: se trata como SyntaxError (aparece el Gremlin Sintaxis).
- **Resultado distinto** (sin error): la "criatura" de la pantalla de fallo es el caldero, con "Obtuviste X, pero el caldero pedía Y".
- **Mensajes de error**: en español con el nombre de error de Python (`TypeError: no se puede sumar str y int`, `NameError: name 'bonus' is not defined`).
- **Evaluador** (`scripts/level/py_eval.gd`): además de lo pedido soporta `/ // % !=`, paréntesis, menos unario, `True/False/None` y `print/str/int/len`, para poder reutilizarlo en mundos siguientes.
- **Minijuego "Completa el hechizo"**: el código completado se ejecuta con el evaluador y se compara lo impreso con `output`. Así `5 = 5` da SyntaxError (Gremlin), `nombre = Ada` da NameError (Fantasma) y `4 + 3` da "imprimió 7, tenía que imprimir 12". Las fichas del minijuego se pueden reusar.
- **Boss**: cada ronda acertada baja un tercio de la barra de vida; un fallo muestra la criatura y permite reintentar la misma ronda. "Continuar" después de vencerlo va al mapa de mundos, donde el aprendiz camina al mundo 2.
- **Pistas ya pagadas**: si salís y volvés a un nivel, las pistas que ya pediste se muestran gratis.
- **Exportación web**: preset "Web" en `export_presets.cfg` sin threads (`variant/thread_support=false`), así no hacen falta las cabeceras COOP/COEP y alcanza con cualquier servidor estático. `include_filter="data/*.json"` mete el contenido en el `.pck`; `tests/` y `tools/` quedan afuera. Se exporta en modo release, así que el botón "Completar (debug)" no aparece en web.
- **Plantillas**: se instalaron solo las plantillas web de Godot 4.7.2 (`web_*.zip` y `version.txt`) en `~/Library/Application Support/Godot/export_templates/4.7.2.stable/`. Para exportar a otras plataformas, instalá el paquete completo desde el editor (Editor → Administrar plantillas de exportación).
- **Fuentes en web**: el navegador no tiene fuentes de respaldo, así que cualquier carácter que no esté en Fredoka/Nunito/Fira Code se ve como un cuadradito. Se reemplazaron `◂` y `−` y la flecha `→` usa Fira Code. Si agregás textos con símbolos nuevos, revisá que la fuente los tenga.
- **Splash de arranque** con el fondo noche y el grimorio, en vez del logo de Godot.

## Herramientas que quedaron en el repo

- `tools/check.sh`: import headless + todos los tests. Falla si hay errores de script.
- `tools/gen_sprites.py`: regenera el pixel art (`python3 tools/gen_sprites.py`).
- `tools/gen_theme.gd`: regenera `resources/ui_theme.tres` desde la paleta.
- `tools/screenshot.gd`: captura una escena con ventana (`godot --path . -s tools/screenshot.gd -- <escena> <salida.png> [mundo] [casita]`). Acepta `PY_COMPLETED`, `PY_XP`, `PY_EXPR` y `PY_SECONDS` como variables de entorno para preparar el estado.

## Lo que no se pudo hacer

- **Push al remoto**: el primer push (fase A) funcionó, pero desde la fase B `git push` se queda colgado en `git credential-osxkeychain`, probablemente esperando un permiso del llavero de macOS en pantalla. Los commits están todos en local, en `main`. Para subirlos: `git push origin main` desde tu terminal (y aceptá el diálogo del llavero si aparece).
- **GUT** no se instaló: se usó un runner propio sin dependencias (`tests/run_tests.gd`).

## Errores conocidos y limitaciones

- **Tablero del Frasco solo con mouse/táctil**: para poner fichas hay que arrastrar o tocar; todavía no hay forma de hacerlo solo con teclado. Los mapas sí funcionan con teclado.
- **Opciones**: el volumen es un placeholder (no hay audio todavía) y no se guarda entre sesiones.
- **Arte placeholder**: los sprites son pixel art generado; reemplazar cada `assets/sprites/<id>.png` por el arte final no requiere tocar código (mismo nombre; tamaños parecidos para que la escala cuadre).
- **Mapas de sección** del mundo 2 y 3 usan la misma disposición de casitas que el 1 (así está en `worlds.json`); solo cambia la decoración.
- **Tamaño del build web**: el `.wasm` del motor pesa ~40 MB (sin comprimir). Un servidor con gzip/brotli lo baja mucho.
- **Avisos al cerrar los tests**: Godot imprime algunos avisos de recursos "leaked" al salir del modo headless; son del cierre del proceso, no fallas de los tests.
