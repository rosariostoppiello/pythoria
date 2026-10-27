# Prueba manual

Pasos para probar cada pantalla a mano. Todo lo automático se corre con `tools/check.sh` (import + 81 tests).

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

## 4. Mundo 1: Valle de los Frascos

La dificultad apunta a primer año de facultad. Cada mundo mezcla desafíos de **arrastrar** (Frasco, Encrucijada) con desafíos de **escribir código** (más o menos la mitad).

### Frasco (arrastrar fichas)

**Nivel 1 – El orden de los hechizos** (pide 14 con `a + b * c`)

1. Arrastrá **2** a `a`, **3** a `b` y la ficha de texto **'4'** a `c`. El código de abajo muestra `c = '4'`.
2. **Lanzar** → **Quimera Tipos**: `3 * '4'` da `'444'` y después `2 + '444'` es `TypeError`. **Reintentar** deja el tablero como estaba.
3. Con solo `a` lleno → **Fantasma Sin Nombre** (`NameError`).
4. Con `2`, `3`, `4` → éxito y +50 XP. También sirven otras combinaciones (`4 + 5 * 2`): se evalúa el resultado, no una respuesta fija.

**Nivel 2 – Repartir caramelos** (pide el int 3)

- `6 / 2` → "Obtuviste 3.0 (float), pero el caldero pedía 3 (int): mismo valor, distinto tipo."
- `17 % 5` → "Obtuviste 2…". `17 // 5` o `6 // 2` → éxito.

**Pistas de Ada**: en cualquier nivel, **Pedir pista (-10 XP)** enciende la vela y baja la recompensa. Se ve la última pista; tocando el globo se repasan las anteriores. Volviendo al nivel, las pistas pagadas siguen ahí gratis.

### Escribí el hechizo (código)

Pantalla: a la izquierda la consigna ("Tu tarea"); a la derecha un editor de código (Fira Code, números de línea, colores, sangría automática con 4 espacios), la lista de **casos de prueba** y la **Salida**.

- **Probar (caso 1)**: corre tu programa con la entrada del caso 1 y muestra lo que imprime (o el error). No juzga.
- **Lanzar**: corre todos los casos. Cada caso queda con `✓` o `x`. Si falla uno, dice cuál, qué esperaba y qué imprimiste.
- **Restaurar código**: vuelve al código inicial.

**Nivel 3 – Tu primer programa** (80 XP): leé nombre y edad, imprimí `Ada cumple 21 el año que viene`.

1. Escribí `print(f"{nombre} cumple {edad + 1} el año que viene")` sin convertir la edad → **Quimera Tipos** con la explicación "input() siempre devuelve texto".
2. Usá `print(nombre, "cumple", ...)` sin f-string → el búho avisa que la consigna pide un f-string.
3. Escribí la respuesta fija `print(f"Ada cumple 21 el año que viene")` → pasa el caso 1 pero falla el 2 (Linus): no se puede hardcodear.
4. Con `edad = int(input())` y el f-string → éxito.

**Nivel 4 – El reloj de arena**: segundos → `1h 2m 5s` con `//` y `%`. Si lanzás el código inicial sin completar, aparece el Fantasma (`horas` no existe).

**Nivel 5 – El promedio de Ada**: tres notas con decimales → `Promedio: 8.33`. Con `int(input())` el caso `5.5` da `ValueError` (Quimera); sin paréntesis el promedio da mal.

### Minijuego "Completa el hechizo" (4 rondas)

Arrastrá (o tocá) fichas de código a los huecos `____` y **Lanzar**:

1. `edad = ____(input())` con entrada `21`: `str` imprime `2121`, `float` imprime `42.0`; `int` → `42`.
2. `f"Total: ${precio ____ cantidad:____}"` → `*` y `,.2f` dan `Total: $3,751.50`. Con `d` aparece la Quimera (`d` es solo para int).
3. `minutos ____ 60` dos veces → `//` y `%` en ese orden dan `2h15m`.
4. `nombre.____().____()` → `strip` y `title` dan `Ada Lovelace`.

### Boss: Gremlin Sintaxis (3 rondas)

- Ronda 1 (Frasco): `(a + b) * c` = 20. La ficha `'5'` da `'5555'` (texto repetido), no un error: "Obtuviste '5555', pero el caldero pedía 20".
- Ronda 2 (código): arreglá el hechizo roto `"..." + edad + 10`. Lanzarlo sin tocar despierta a la Quimera.
- Ronda 3 (código): precio con descuento, `Pagás 53.91`.
- Cada ronda acertada baja un tercio de la vida; un fallo no. Al ganar: +200 XP y el aprendiz camina al mundo 2.

## 7. Mundo 2: Bosque de las Encrucijadas

Para llegar rápido sin jugar el mundo 1, agregá `"w1_boss"` a `completed` en `save.json` (ver la sección 8).

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – El rango del portón (Frasco) | `x = 7`, `10`, `'4'` y `4` con `0 <= x < 10 and x % 2 == 0` | 7 es impar y 10 queda afuera (False). `'4'` (texto) despierta a la Quimera al compararlo con 0. `4` → éxito. |
| 2 – El hongo sabio (Frasco) | `5 or 'Ada'`, después `'' or 'Ada'` | `and`/`or` devuelven uno de sus valores: `5 or 'Ada'` da `5`. `'' or 'Ada'` (o `5 and 'Ada'`) da `'Ada'`: éxito. |
| 3 – La mesa de examen (Encrucijada) | `nota = 8`, `asistencia = 80`; después `nota = 5` | 8 va a "aprobado" (rojo, aparece el Guardián). 5 con 80 va a "examen final" (turquesa). Con asistencia 60, "recursa". |
| 4 – Clasificador de notas (código) | Escribí los `elif` en orden equivocado (`>= 6` antes que `>= 8`) | Falla el caso 1 (nota 9 imprime Aprobado). Sin `elif`, el búho avisa que la consigna lo pide. En orden correcto → éxito. |
| 5 – Año bisiesto (código) | `anio % 4 == 0` solo | Falla con 1900. La condición completa `(anio % 4 == 0 and anio % 100 != 0) or anio % 400 == 0` pasa los 5 casos. |
| Minijuego – Bola de cristal (4 rondas) | Predecí qué pasa | Las opciones pueden ser un error (`NameError`, `TypeError`). Trampas: cortocircuito de `or`, `'Ana' < 'ana'`, comparar `input()` con un número, y el orden de los `elif` en FizzBuzz. |
| Boss – Guardián de la Puerta | Ronda 1: Encrucijada de 4 caminos (`temp = 15`, `lluvia = True` → refugio). Ronda 2: escribí la regla de entrada al bosque. Ronda 3: arreglá un `if` con tres errores (sangría, `=` en vez de `==` y falta un `:`) | Cada acierto baja la vida; al ganar, +200 XP y el camino al mundo 3. |

## 7b. Mundo 3 (placeholder)

- Entrá al mundo 3: mapa con otra distribución de árboles y agua.
- Cualquier casita abre **Próximamente** con los temas del mundo.
- En el editor (build de debug) aparece **Completar (debug)**: marca la casita y abre la siguiente. Completando el boss del mundo 3 se "desbloquea" el 4, que se ve como Próximamente.
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
