# Prueba manual

Pasos para probar cada pantalla a mano. Todo lo automático se corre con `tools/check.sh` (import + 59 tests).

## 0. Abrir el proyecto

1. Abrí Godot 4.7 (`/Applications/Godot.app`).
2. En el gestor de proyectos: **Importar** → elegí `pythoria/project.godot` → **Importar y editar**.
3. La primera vez tarda unos segundos en importar los sprites y las fuentes. No debería aparecer ningún error rojo en el panel **Salida**.
4. Apretá **F5** (o el botón ▶ arriba a la derecha). Arranca en el menú principal.

Para empezar de cero en cualquier momento: en el menú, **Jugar** → **Sí, empezar** (borra `user://save.json`).

## 1. Menú principal

| Hacé | Debería pasar |
|---|---|
| Mirá la pantalla | Cielo nocturno con estrellas que titilan, el aprendiz respirando a la izquierda, Byte (gato naranja con sombrerito) durmiendo sobre libros con una vela a la derecha. |
| Primera vez (sin guardado) | Botones **Jugar**, **Opciones**, **Salir**. No aparece **Continuar**. |
| **Opciones** | Panel con un deslizador de volumen (todavía no hay sonidos) y **Cerrar**. |
| **Jugar** | Fundido al mapa de mundos. |
| Volvé al menú (botón **‹ Menú**) | Ahora aparece **Continuar** arriba de todo. |
| **Jugar** con guardado | Pregunta "¿Empezar de cero?". **Cancelar** no borra nada. |
| **Salir** | Cierra el juego (en la versión web este botón no está). |

## 2. Mapa de mundos

| Hacé | Debería pasar |
|---|---|
| Mirá la pantalla | 8 nodos de colores unidos por una línea punteada. El mundo 1 pulsa (actual) y tiene al aprendiz encima. Del 2 al 8 se ven grises con candado. |
| Pasá el mouse por un nodo | El panel de pergamino de arriba a la izquierda muestra nombre, historia, temas y estado. |
| Clic en un nodo bloqueado | No pasa nada; **Entrar** queda deshabilitado. |
| Clic en el mundo 1, o **Entrar**, o **Enter** | Abre el mapa de sección del mundo 1. |

## 3. Mapa de sección (prototipo "hola mundo")

| Hacé | Debería pasar |
|---|---|
| Mirá la pantalla | Pasto, camino de tierra, árboles, estanques y 7 casitas numeradas (1–5, Minijuego, Boss). La 1 tiene la puerta con luz y brilla; las demás tienen candado. |
| Flechas o **WASD** | El aprendiz camina con saltitos; quieto, "respira". La cámara lo sigue. |
| Caminá contra un árbol, el agua o una casita | Te frena: no se puede atravesar. |
| Acercate a la puerta de la casita 1 | Aparece "Espacio: entrar" arriba de la casita. |
| **Espacio** o **Enter** | Entra al nivel 1. |
| Acercate a una casita con candado y apretá Espacio | Dice "Bloqueada" y abajo explica que tenés que completar la anterior. |
| **Esc** | Pausa con **Continuar**, **Mapa de mundos** y **Menú**. **Esc** otra vez continúa. |
| **‹ Mundos** (arriba a la izquierda) | Vuelve al mapa de mundos. |

## 4. Niveles del Frasco (Mundo 1)

Pantalla: a la izquierda la misión ("El caldero pide: 8") y Ada con el búho y la vela; a la derecha los frascos, el operador, el caldero, las fichas y el código Python en vivo.

**Nivel 1 – Tu primer frasco** (pide 8)

1. Arrastrá la ficha **5** al frasco **poder**. La ficha desaparece de la bandeja, el frasco muestra `5` y el código muestra `poder = 5` y `# bonus está vacío`.
2. Apretá **Lanzar** con un solo frasco lleno → aparece el **Fantasma Sin Nombre** con `NameError: name 'bonus' is not defined`. **Reintentar** cierra el cartel y el tablero queda igual.
3. Poné **9** en **bonus** y **Lanzar** → el caldero se pone rojo: "Obtuviste 14, pero el caldero pedía 8."
4. Tocá el frasco **bonus** (lo vacía; el 9 vuelve a la bandeja). Tocá la ficha **3** (va al primer frasco vacío).
5. **Lanzar** → caldero turquesa, estrella, "¡Hechizo logrado!" y **+50 XP**. La barra de XP de arriba sube y la racha pasa a "1 día".
6. **Continuar** → volvés al mapa frente a la casita 1, que ahora tiene estrella dorada; la casita 2 se abre.
7. Entrá de nuevo a la casita 1 y resolvela: el resultado dice que no suma XP de nuevo.

**Nivel 2 – Esencias de texto** (pide `'Hola Ada'`)

- Poné `'Hola '` en **saludo** y `7` en **nombre** → **Lanzar** → aparece la **Quimera Tipos** con `TypeError: no se puede sumar str y int`.
- Con `'Hola '` + `'Ada'` → éxito.

**Pistas de Ada** (probalo en el nivel 3)

- **Pedir pista (-10 XP)**: aparece la pista 1, se enciende la vela y la recompensa baja a 40 XP.
- Pedí las 3: la última es la solución parcial y el botón dice "No hay más pistas". Recompensa: 20 XP.
- Si salís y volvés al nivel, las pistas ya pedidas siguen visibles sin cobrar de nuevo.

**Nivel 3 – El poder de multiplicar** (pide 12): elegí el operador con los botones `+ - *`. Sirven tanto `3 * 4` como `8 + 4`. Sin operador elegido, **Lanzar** muestra al Gremlin Sintaxis.

**Nivel 4 – Verdadero o falso** (pide `True`): `7 == 7` da éxito; `7 + 7` dice "Obtuviste 14, pero el caldero pedía True."

**Nivel 5 – Bienvenido, aprendiz** (f-string): poné `'Ada'` en **nombre**. El caldero muestra `f"Bienvenido, {nombre}"`.

**Pausa en un nivel**: **Esc** → **Continuar**, **Reintentar** (recarga el nivel), **Volver al mapa**, **Menú**.

## 5. Minijuego "Completa el hechizo"

Se abre después del nivel 5. Hay 3 rondas; cada una muestra código con huecos `____`.

1. Ronda 1 (`____ = 5` / `print(poder)`): poné `5` en el hueco y **Lanzar** → Gremlin Sintaxis (`5 = 5` no es válido). Con `poder` → "Ronda 2 de 3".
2. Ronda 2: `Ada` sin comillas → Fantasma Sin Nombre. Con `'Ada'` → sigue.
3. Ronda 3: `+` → "imprimió 7, pero tenía que imprimir 12". Con `*` → "¡Hechizo completo!" y +100 XP.
4. Al volver al mapa, la casita **Boss** se abre.

## 6. Boss: Gremlin Sintaxis

- A la izquierda, el Gremlin balanceándose con su barra de vida roja y "Ronda 1 de 3".
- Ronda 1 (pide 10): probá `6 + '6'` → Quimera Tipos. Con `6 + 4` → el Gremlin se sacude y pierde un tercio de vida.
- Ronda 2 (`'Hola Byte'`) y ronda 3 (`3 == 3` → `True`).
- Al ganar: "¡Venciste al Gremlin Sintaxis!" y +200 XP. **Continuar** lleva al **mapa de mundos**: el aprendiz camina por la línea punteada hasta el mundo 2, que aparece con un "pop" y queda desbloqueado. El nodo 1 queda dorado con estrella.

## 7. Mundos 2 y 3 (placeholder)

- Entrá al mundo 2: mapa con otra distribución de árboles y agua.
- Cualquier casita abre **Próximamente** con los temas del mundo.
- En el editor (build de debug) aparece **Completar (debug)**: marca la casita y abre la siguiente. Completando el boss del mundo 2 se desbloquea el 3, y así sucesivamente.
- Los mundos 4 a 8 no tienen casitas: si llegás con el botón debug, se ven como "Próximamente" y no se puede entrar.

## 8. Guardado

1. Completá un par de niveles y cerrá el juego.
2. Volvé a abrir con F5 → **Continuar** → el progreso, el XP y la racha siguen ahí.
3. El archivo está en `user://save.json`. En Mac: `~/Library/Application Support/Godot/app_userdata/Pythoria/save.json`. Si lo editás y borrás claves o lo rompés, el juego arranca igual con valores por defecto.

## 9. Versión web

```bash
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8000
```

Abrí <http://localhost:8000> en Chrome o Firefox. Debería verse el splash con el grimorio y después el menú (sin el botón **Salir**). En web el guardado queda en el almacenamiento del navegador (IndexedDB).
