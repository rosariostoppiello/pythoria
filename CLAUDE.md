# Pythoria (PyMancer: La Academia del Grimorio)

Juego educativo para aprender Python como un aprendiz de magia. Hecho en **Godot 4.7 (GDScript)**, objetivo final: **exportar a Web (HTML5)**. Este repo es solo la parte del juego; editor de código (Monaco), Pyodide, login, backend, IA y ranking son de una etapa posterior y NO se tocan hoy.

Documentos de referencia (leerlos antes de trabajar):
- `docs/DISENO.md`: historia, estilo, paleta, personajes, mecánica, mapa de mundos, valores de XP.
- `data/worlds.json`: mundos, secciones, casitas y niveles. Todo el contenido vive acá, no en el código.

## Reglas técnicas

- Godot 4.7, comando `godot` disponible en la terminal. Renderer: **gl_compatibility** (necesario para web y para el Mac Intel del usuario).
- Resolución base 1280x720, stretch mode `canvas_items`, aspect `keep`.
- GDScript tipado (`var x: int`, `func f() -> void`). Sin plugins pesados. Sin C#.
- Nada de rutas absolutas. Todo con `res://` y `user://`.
- El contenido (niveles, textos, mundos) sale de JSON. Agregar un nivel no debe requerir tocar scripts.
- Los colores y fuentes se definen UNA vez en `scripts/core/theme_colors.gd` y `resources/ui_theme.tres`. Prohibido hardcodear hex en escenas.
- Autoloads: `GameState` (progreso y XP), `SaveSystem` (guardado), `SceneManager` (cambio de escenas y estados), `ContentDB` (carga de JSON).
- El guardado es `user://save.json`, con campo `version`. Debe sobrevivir a que falten claves (valores por defecto).

## Estructura de carpetas

```
res://
  project.godot
  CLAUDE.md
  docs/            documentos de diseño
  data/            worlds.json y otros datos
  assets/
    sprites/       PNG con fondo transparente (nombre = id, ver abajo)
    fonts/         Fredoka, Fira Code, Nunito
    audio/         (vacío por ahora)
  scenes/
    main_menu/  world_map/  section_map/  level/  pause/  result/  ui/
  scripts/
    core/          autoloads y utilidades
    ui/  world_map/  section_map/  level/  player/
  resources/       temas y recursos .tres
  tools/           gen_sprites.py y scripts auxiliares
  tests/           pruebas
```

## Arte

- Estilo objetivo: ilustración cozy. Hoy el arte es **pixel art placeholder** generado por `tools/gen_sprites.py` (Python + Pillow). Se puede reemplazar por arte final sin tocar código: cada sprite es `assets/sprites/<id>.png` y las escenas los cargan por ese nombre.
- Ids de sprite: `player`, `ada`, `owl`, `byte_cat`, `gremlin_sintaxis`, `fantasma_sin_nombre`, `quimera_tipos`, `ouroboros`, `jar`, `cauldron`, `grimoire`, `teacup`, `candle_books`, `house_locked`, `house_open`, `house_done`, `tile_grass`, `tile_path`, `tile_water`, `tree`, `map_node`, `map_node_done`, `map_node_locked`, `guardian_puerta`, `crystal_ball` (más `candle_books_lit` y `star`).
- Paleta fija: ver `docs/DISENO.md`. El dorado es solo para recompensas, el rojo solo para errores y enemigos, el turquesa es éxito.

## Flujo de trabajo

- Trabajar por fases, un commit por fase con mensaje claro (`feat: ...`, `test: ...`, `chore: ...`). Remoto: `https://github.com/rosariostoppiello/pythoria.git`, rama `main`.
- Antes de cada commit: `godot --headless --import` y correr los tests. Si algo falla, arreglarlo antes de commitear.
- No commitear `.godot/`, `*.import` cachés, `build/` ni `user://`. Sí commitear los `.import` de assets si Godot los exige para que el proyecto abra limpio.
- Si algo no se puede hacer en esta máquina (plantillas de exportación, push sin credenciales), dejarlo anotado en `docs/PENDIENTES.md` y seguir con lo demás. No frenar el trabajo.

## Cómo se prueba

- Automático: `godot --headless --path . -s tests/run_tests.gd` (o GUT si se instala) más `godot --headless --import`.
- Manual (lo hace el usuario): abrir el proyecto en Godot, F5, jugar. Mantener `docs/PRUEBA_MANUAL.md` con los pasos exactos para probar cada pantalla.
