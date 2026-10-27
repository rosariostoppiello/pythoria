# Pythoria / PyMancer: documento de diseño del prototipo

Título de trabajo: **PyMancer: La Academia del Grimorio**. El mundo se llama **Pythoria**.

## 1. Idea

Pythoria es un reino mágico donde programar es lanzar hechizos. El jugador es un aprendiz de la Academia Arcana. El Caos (los bugs) corrompe los hechizos del reino. Para detenerlo hay que dominar el Grimorio (Python) y recorrer ocho mundos hasta la Cámara de los Espejos. Cada mundo es un capítulo y un tema de Python, y termina con un boss.

Plataforma: web (Godot exportado a HTML5). Python cubierto: desde cero hasta antes de POO.

## 2. Alcance de hoy

Dentro: solo el juego en Godot.
- Estructura y escenas/estados: menú, mapa de mundos, mapa de sección, nivel, pausa, resultado.
- Guardado de progreso local.
- Mapa de mundos (línea punteada) y mapas de sección con casitas.
- Prototipo "hola mundo" jugable: el aprendiz camina por el mapa y choca con las casitas.
- Mundo 1 completo y jugable (5 niveles, 1 minijuego, 1 boss) con la mecánica del Frasco.
- Mundos 2 a 8 existen como datos; 2 y 3 tienen casitas placeholder; el resto se ve bloqueado.
- Arte placeholder en pixel art, tests básicos.

Fuera (etapas posteriores): editor Monaco, Pyodide, login, backend, IA de pistas, ranking, POO, 1v1, tienda.

## 3. Estructura de pantallas

1. **Menú principal**: Jugar / Continuar, Opciones (volumen placeholder), Salir. Botón Continuar solo si hay guardado. Fondo nocturno con Byte durmiendo sobre libros.
2. **Mapa de mundos**: los 8 mundos como nodos unidos por una línea punteada. Estados: completado (dorado/color del mundo), actual (pulsa), bloqueado (gris). El aprendiz se ve sobre el nodo actual. Al completar todas las casitas de un mundo, el aprendiz se desplaza por la línea punteada hasta el siguiente nodo y este se desbloquea.
3. **Mapa de sección** (uno por mundo): mini-mapa top-down con 7 casitas: 5 niveles, 1 minijuego, 1 boss. El aprendiz se mueve con flechas/WASD y colisiona con árboles, agua y casitas. Al acercarse a una casita desbloqueada y apretar Espacio/Enter, entra. Casitas: bloqueada (candado), disponible (puerta con luz), completada (estrella dorada). Se desbloquean en orden. Boss se desbloquea al completar los 5 niveles y el minijuego.
4. **Nivel**: la escena de juego (mecánica del Frasco, ver abajo).
5. **Pausa**: Continuar, Reintentar, Volver al mapa, Menú. Con Esc.
6. **Resultado**: éxito (turquesa, XP ganado, estrella) o fallo (criatura roja, explicación). Siempre ofrece reintentar al instante. Un nivel fallido nunca bloquea.

Estados del juego (SceneManager): `MENU`, `WORLD_MAP`, `SECTION_MAP`, `LEVEL`, `PAUSED`, `RESULT`.

## 4. Mecánica del Frasco (asignar y calcular valores)

Cada nivel muestra una misión ("el caldero necesita un poder de 8").
- Hay **frascos** con nombre (`poder`, `bonus`). Cada frasco acepta un tipo de esencia.
- Hay **fichas** de valores (número, texto, verdadero/falso) que se arrastran a los frascos. Eso es **asignar** (`poder = 5`).
- Hay **operadores** (`+`, `-`, `*`, `==`) que se eligen para combinar los frascos en el caldero. Eso es **calcular**.
- Se muestra el código Python equivalente en vivo abajo, en Fira Code (por ejemplo `poder = 5`, `bonus = 3`, `poder + bonus`), para que el jugador vea el vínculo con Python real.
- Botón **Lanzar**: se evalúa la expresión con reglas de tipos de Python y se compara con el objetivo.
  - Coincide: hechizo logrado (efecto turquesa, XP).
  - Resultado distinto: el caldero muestra el valor obtenido y el objetivo. Mensaje: "Obtuviste 7, pero el caldero pedía 8".
  - Error de tipos (ej. número + texto): aparece la **Quimera Tipos** con mensaje estilo `TypeError: no se puede sumar int y str`.
  - Frasco vacío usado: aparece el **Fantasma Sin Nombre** (`NameError`).
- Pista de Ada (3 niveles: concepto, estructura, solución parcial). Cada pista cuesta XP, nunca bloquea. Se enciende la vela sobre los libros.
- Colores de esencia: número = lavanda, texto = pergamino, verdadero/falso = turquesa. (No usar dorado ni rojo para tipos.)
- Evaluador propio en GDScript con semántica de Python (int + str es error; `==` devuelve bool; `+` entre str concatena; `*` entre int multiplica). No usar la semántica de GDScript.

### 4a. Dificultad y público

El público es gente de ~18 años en primer año de facultad. Los desafíos parten de una base exigente: precedencia de operadores, `/` contra `//` (float contra int), conversiones con `input()`, cortocircuito de `and`/`or`, orden de los `elif`. En cada mundo, más o menos **la mitad de los desafíos es escribir código** (ver 4c); el resto usa las mecánicas de arrastrar, que sirven para concentrarse en un concepto puntual.

### 4b. Mecánica de la Encrucijada (if / elif / else, mundo 2)

Usa los mismos frascos y fichas, pero en lugar del caldero hay un camino que se divide en una rama por cada `if`, `elif` y `else` (`branches` en el JSON).
- El jugador llena los frascos y aprieta Lanzar. Python prueba las condiciones de arriba hacia abajo y el aprendiz toma la primera rama verdadera, que asigna `camino = '<destino>'`.
- Se gana si `camino` termina igual a `goal`. Se ilumina en turquesa el camino correcto, o en rojo el equivocado ("El Guardián te mandó a puente, pero tenías que llegar a cueva").
- Los errores son los mismos que en el Frasco: frasco vacío (Fantasma Sin Nombre) o comparar número con texto (Quimera Tipos).
- El código Python en vivo muestra el bloque if/elif/else completo con sangría.

### 4c. Escribí el hechizo (código)

El jugador escribe un programa en un editor de código dentro del juego (resaltado de sintaxis, números de línea, sangría automática de 4 espacios). El programa se corre con el evaluador propio contra **varios casos de prueba**, como un corrector automático de facultad: cada caso trae las entradas que devuelve `input()` y la salida exacta esperada (se ignoran los espacios al final de cada línea). Así no se puede "hardcodear" la respuesta.
- **Probar** corre el caso 1 y muestra la salida o el error, sin juzgar. **Lanzar** corre todos los casos y marca cada uno con ✓ o x.
- Si falla, se dice qué caso, qué esperaba y qué imprimió; los errores de Python traen la criatura de siempre y una explicación del error típico (por ejemplo "input() siempre devuelve texto").
- Una consigna puede exigir usar algo (`require`: un f-string, un `elif`); si falta, avisa el búho.
- Algunos desafíos son "arreglá el hechizo": el código inicial tiene errores que hay que corregir.
- Valen 80 XP (campo `xp` del nivel) y tienen las mismas 3 pistas de Ada.

## 5. Valores de juego (propuesta, ajustables en `data/worlds.json`)

| Elemento | Valor |
|---|---|
| XP por nivel resuelto | 50 |
| Costo por pista usada | -10 XP por pista (mínimo 10 XP por nivel) |
| XP minijuego | 100 |
| XP boss | 200 |
| Nivel de jugador | `nivel = floor(sqrt(xp / 50)) + 1` |
| Racha | días consecutivos con al menos un nivel resuelto (se guarda fecha de último día) |
| Intentos | ilimitados, reintento inmediato |

El XP nunca se resetea. Rejugar un nivel ya completado no da XP de nuevo.

## 6. Estilo visual

Objetivo: ilustración cozy. Hoy: pixel art placeholder (formas redondeadas, contorno oscuro, luz cálida) para poder tener todo funcionando; se reemplaza por arte final PNG con fondo transparente sin cambiar código.

### Paleta (fija)

| Rol | Nombre | Hex | Uso |
|---|---|---|---|
| Fondo | Noche arcana | #1E1B3A | Fondo general |
| Primario | Violeta mágico | #6C4AB6 | Botones, marcos |
| Secundario | Lavanda | #A98BE8 | Hover, brillos, esencia número |
| Acento / XP | Dorado runa | #F2B84B | Solo XP, medallas, recompensas |
| Éxito | Turquesa hechizo | #3FD1C0 | Hechizo logrado, tests aprobados |
| Error / enemigos | Rojo bug | #E5484D | Solo errores y criaturas del Caos |
| Panel claro | Pergamino | #F4E9D2 | Enunciados, diálogos, tarjetas |
| Texto | Tinta | #2B2440 | Texto sobre pergamino |

### Tipografías (Google Fonts, gratuitas)

- **Fredoka**: títulos, números de nivel, botones.
- **Fira Code**: código y salidas.
- **Nunito**: enunciados, diálogos, texto corrido.

### UI

Paneles de pergamino con esquinas redondeadas y borde violeta. Barra superior con "Mundo N · Nivel M", barra de XP y racha. Botones "Lanzar" (primario) y "Pedir pista" (contorno violeta). Estados de casita con candado / luz / estrella.

## 7. Personajes y objetos

- **El aprendiz** (protagonista): sombrero violeta con banda dorada, capa violeta, grimorio turquesa con estrella. Personalizable más adelante con XP.
- **Archimaga Ada** (mentor): bibliotecaria con anteojos, capa celeste con estrellas, bastón con luz. Le acompaña un **búho** violeta que da las pistas. Nunca da la solución completa.
- **Byte** (mascota): gato naranja con sombrerito que duerme sobre libros. Aparece en menú, carga y racha.
- **Enemigos**: Gremlin Sintaxis (SyntaxError, boss mundo 1), Fantasma Sin Nombre (NameError), Quimera Tipos (TypeError), Guardián de la Puerta (boss mundo 2), Ouroboros (bucle infinito, boss mundo 3), Espectro del Índice (mundo 4), Archivista del Caos (mundo 5), Hechicero Espagueti (mundo 6), Hechizo Rebotado (mundo 7), Espejo Infinito (mundo 8).
- **Objetos**: Frasco rúnico (variables), Caldero (bucles / calcular), Grimorio (editor), Taza de té (racha), Vela y libros (pista de Ada).

## 8. Mundos

| # | Mundo | Temas | Minijuego | Boss | Color dominante (propuesto) |
|---|---|---|---|---|---|
| 1 | Valle de los Frascos | print, input, variables, tipos, operadores, f-strings | Completa el hechizo | Gremlin Sintaxis | #4E7D4B |
| 2 | Bosque de las Encrucijadas | booleanos, comparaciones, if/elif/else | Bola de cristal | Guardián de la Puerta | #B5702A |
| 3 | Torre de los Rituales | while, for, range, break, continue | Duelo de Bugs | Ouroboros | #3F6FB5 |
| 4 | Biblioteca de los Pergaminos | strings, listas, tuplas, slicing | Ordena el conjuro | Espectro del Índice | #8A3F7A |
| 5 | Salón de las Runas | diccionarios, sets, anidados | Trivia del aula | Archivista del Caos | #7A4A3A |
| 6 | Taller de Embrujos | funciones, parámetros, return, scope | Ordena el conjuro | Hechicero Espagueti | #B5547A |
| 7 | Catacumbas de los Errores | try/except, archivos | Duelo de Bugs | Hechizo Rebotado | #5A6270 |
| 8 | Cámara de los Espejos | recursión | Bola de cristal | Espejo Infinito | #3A8A9A |

Cada mundo: historia corta, 5 niveles, 1 minijuego, 1 boss. Derrotar al boss abre el mundo siguiente.

## 9. Mundo 1: Valle de los Frascos

- **Niveles 1 y 2 (Frasco):** precedencia (`a + b * c` con una ficha trampa de texto) y división (`/` da float, `//` y `%`).
- **Niveles 3 a 5 (código):** leer con `input()` y convertir, armar mensajes con f-strings, `//` y `%` para pasar segundos a horas, promedio con `float()` y `{x:.2f}`.
- **Minijuego "Completa el hechizo":** fragmentos de código con huecos `____` (conversiones, formato de f-strings, `//` y `%`, métodos de texto); el código completado se ejecuta y se compara lo impreso. 4 rondas.
- **Boss Gremlin Sintaxis:** 3 rondas (Frasco con trampa `'5' * 4`, arreglar un hechizo roto, y un programa de descuentos), con barra de vida.

Idea a futuro: preguntas y rondas del boss generadas por IA adaptadas al nivel del jugador.

## 9b. Mundo 2: Bosque de las Encrucijadas

- **Niveles 1 y 2 (Frasco):** comparaciones encadenadas con `%` (`0 <= x < 10 and x % 2 == 0`) y `and`/`or` que devuelven uno de sus valores (verdad de `0` y `''`).
- **Nivel 3 (Encrucijada):** if/elif/else con dos condiciones (nota y asistencia).
- **Niveles 4 y 5 (código):** clasificador de notas con `elif` en el orden correcto y año bisiesto.
- **Minijuego "Bola de cristal":** se muestra un código y se elige qué va a pasar: qué imprime, o qué error da. 4 rondas con trampas (cortocircuito, orden de textos, `input()` comparado con un número, orden de los `elif`).
- **Boss Guardián de la Puerta:** Encrucijada de 4 caminos, un programa con `and`/`or`, y arreglar un `if` con tres errores.

## 10. Progresión y guardado

`user://save.json`:

```json
{
  "version": 1,
  "xp": 0,
  "streak": 0,
  "last_played_day": "",
  "completed": ["w1_l1"],
  "hints_used": {"w1_l2": 1},
  "current_world": 1
}
```

Un nivel completado queda en `completed`. Una casita se desbloquea si la anterior está completada. Un mundo se desbloquea si el boss del anterior está completado.
