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

## 9. Minijuegos del Mundo 1

- **Completa el hechizo**: un fragmento de código con huecos (`____ = 5`, `print(____)`); el jugador arrastra fichas a los huecos. 3 rondas.
- **Boss Gremlin Sintaxis**: 3 rondas de mecánica del Frasco con dificultad creciente (más frascos, más operadores, mezcla de tipos). El Gremlin tiene barra de vida que baja con cada ronda acertada. Se vence completando las 3.

Idea a futuro: preguntas y rondas del boss generadas por IA adaptadas al nivel del jugador.

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
