# Prueba manual

Pasos para probar cada pantalla a mano. Todo lo automático se corre con `tools/check.sh` (import + 99 tests). También corre solo en GitHub Actions en cada push.

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

**Salir de una actividad**: en cualquier nivel, boss o minijuego, el botón **‹ Volver al mapa** de arriba a la izquierda vuelve al mapa del mundo, frente a la casita. También se puede con **Esc** → **Volver al mapa**.

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

## 7b. Mundo 3: Torre de los Rituales

Se abre al vencer al Guardián. Para llegar rápido, agregá `"w2_boss"` (y `"w1_boss"`) a `completed` en `save.json`.

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – La suma de la escalera (Frasco) | `sum(range(1, 5))`, después `range(1, 6)` | `range(1, 5)` da 10: el final no se incluye. `range(1, 6)` o `range(0, 6)` dan 15. La ficha `'6'` despierta a la Quimera. |
| 2 – Pasos de a saltos (Frasco) | `range(10, 0, 3)` y un paso `0` | Hacia atrás con paso positivo da 0 vueltas. El paso 0 es `ValueError`. Sirven `range(0, 10, 3)`, `range(3, 10, 2)` o `range(10, 2, -2)`. |
| 3 – Cuenta regresiva (código) | Un `while n > 0:` que nunca achica `n` | Aparece el **Ouroboros**: "el bucle nunca termina". Con `for i in range(n, 0, -1)` y el `print('¡Despegue!')` afuera del bucle → éxito. |
| 4 – La tabla del aprendiz (código) | Diez `print` a mano | El búho pide usar un `for`. |
| 5 – Suma de dígitos (código) | Convertir el número a texto | La consigna pide `while` y `% 10`. Con `while n > 0: suma += n % 10; n //= 10` → éxito. |
| Minijuego – Duelo de Bugs (4 rondas) | Elegí arreglos | Se ven el código numerado, lo que debería imprimir y lo que imprime (un bucle infinito dice "se repite para siempre"). Los `·` marcan espacios de sangría: en la ronda 2 el arreglo es indentar `n -= 3`. |
| Boss – Ouroboros | Ronda 1: `sum(range(1, 6, 2))`. Ronda 2: agregá `pasos += 1` adentro del while. Ronda 3: contraseña con `break` | Sin `break`, el búho lo pide. `for ... else:` también vale. Al ganar, +200 XP y el aprendiz camina al mundo 4, que se ve como "Próximamente". |

## 7c. Mundos 4 a 8

Para llegar rápido usá el **modo revisor** (Opciones, o `?revisor=1` en la web): abre todos los mundos y todas las casitas. También podés agregar los `wN_boss` anteriores a `completed` en `save.json`. Al vencer al boss del mundo 3, el aprendiz camina al mundo 4 (ya no dice "Próximamente").

### Mundo 4: Biblioteca de los Pergaminos (textos, listas, tuplas, slicing)

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – El pergamino cortado (Frasco) | `palabra[4:8]` y la ficha `'4'` | El código en vivo muestra `palabra = 'pergamino'` arriba. `[4:8]` da `'amin'` (el fin no se incluye); `'4'` trae a la Quimera. `[4:9]` o `[-5:9]` → éxito. |
| 2 – Saltos hacia atrás (Frasco) | `tomos[1:4:-2]` | El caldero pide `[50, 30]` (list). Hacia atrás desde la izquierda da `[]`. `[4:1:-2]` o `[-1:0:-2]` → éxito. |
| 3 – El inventario de la estantería (código) | Sin `split()` | El búho lo pide. Con split, `int()` y `append` → éxito. |
| 4 – El palíndromo del espejo (código) | Comparar sin `lower()` | Falla "Anita lava la tina". Con `[::-1]` y `replace(' ', '')` → éxito. |
| 5 – El pergamino más antiguo (código) | Usar `<=` al buscar el mínimo | Falla el caso del empate (gana el primero). |
| Minijuego – Ordena el conjuro (4 rondas) | Tocá las líneas sueltas en orden | Pasan a "Tu conjuro"; tocando una del conjuro vuelve. En la ronda 2 sobra un `print` con sangría: si lo usás, imprime de más. |
| Boss – Espectro del Índice | Ronda 1: ficha `4` en `a`. Ronda 2: arreglá el `range(len(...) + 1)`. Ronda 3: rotación con `k % len(palabras)` | El índice 4 trae al **Espectro del Índice** (IndexError). Sin `%`, el búho lo pide. |

### Mundo 5: Salón de las Runas (diccionarios, sets, anidados)

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – La runa justa (Frasco) | La ficha `'Pluma'` | Aparece el **Archivista del Caos** con `KeyError: 'Pluma'`. `'pocion'` + `'pluma'` → éxito. |
| 2 – Nombres sin repetir (Frasco) | `'Linus'` y `'Hedy'` | Da 4. Con `'Ada'` y un nombre nuevo → 3. |
| 3 – El contador de runas (código) | `conteo[p] += 1` sin inicializar | Archivista con la sugerencia de usar `.get()`. Usar `.count()` está prohibido (el búho avisa). |
| 4 – Aprendices en común (código) | Imprimir el set sin `sorted` | Falla el orden. Con `&`, `-`, `sorted` y `(nadie)` → éxito. |
| 5 – El libro de calificaciones (código) | `notas[nombre].append(...)` sin crear la lista | KeyError. Con `if nombre not in notas: notas[nombre] = []` → éxito. |
| Minijuego – Trivia del aula (5 preguntas) | Elegí una respuesta equivocada | Sale el búho con una pista (sin revelar la respuesta). Acertar las 5 da el minijuego. |
| Boss – Archivista del Caos | Ronda 1: `biblioteca['pociones'][2]`. Ronda 2: arreglá el contador con `.get()`. Ronda 3: inventario y receta | |

### Mundo 6: Taller de Embrujos (funciones)

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – El escudo con valor por defecto (Frasco) | Cualquier par que sume 7 | La función `escudo` se ve en el código en vivo. Hay varias respuestas. |
| 2 – La x de adentro y la de afuera (Frasco) | La ficha `8` | Da 23: la `x` de afuera sigue en 10. Con 3 → éxito. |
| 3 – Primos del taller (código) | Imprimir adentro de `es_primo` | El búho pide `return`. |
| 4 – El hechizo que devuelve tres cosas (código) | `return min, max, promedio` y desarmarlo | Éxito con `{prom:.2f}`. |
| 5 – print no es return (código) | Probar el código inicial | Imprime el número suelto y `nombre: None`. Cambiando `print` por `return` → éxito. |
| Minijuego – Ordena el conjuro | Poner la llamada antes del `def` | Aparece el Fantasma (NameError: la función todavía no existe). |
| Boss – Hechicero Espagueti | Ronda 1: argumentos por nombre. Ronda 2: reescribir con `def total(...)`. Ronda 3: `aplicar_n` | El código inicial de la ronda 2 tiene un error de copiar y pegar en la tercera cuenta. |

Probá también un `contador += 1` adentro de una función sin `global`: aparece el Fantasma con `UnboundLocalError` y la explicación.

### Mundo 7: Catacumbas de los Errores (try/except, archivos)

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – El conversor prudente (Frasco) | `'7'` y `'tres'` | `'tres'` se convierte en 0 sin explotar → 7. |
| 2 – ¿Quién atrapa el error? (Frasco) | `y = '1'` (texto) | Da `'c-tipo'`: entra el `except TypeError`. |
| 3 – Pedí hasta que sea un número (código) | Usar `isdigit()` | Prohibido (el búho avisa). Con `try`/`except ValueError`/`else` + `break` → éxito. |
| 4 – Las notas grabadas en piedra (código) | Sin `try` | Los casos muestran el contenido de `notas.txt`; el caso 3 dice "(no hay ningún archivo)" y trae al **Hechizo Rebotado** (FileNotFoundError). |
| 5 – El registro de la expedición (código) | Escribir sin pasar a mayúsculas | "El archivo no quedó bien": se revisa cómo queda `registro.txt`. |
| Minijuego – Duelo de Bugs | Ronda 2: modo `'w'` contra `'a'` | Con `'w'` se borra lo que había. |
| Boss – Hechizo Rebotado | Ronda 1: `'-3'` y `'-2'` | Dan -1 cada uno (el `raise` los rechaza) → 1. Ronda 2: calculadora que nunca explota. Ronda 3: leer `hechizos.log` salteando líneas inválidas. |

### Mundo 8: Cámara de los Espejos (recursión)

| Casita | Probá | Debería pasar |
|---|---|---|
| 1 – La escalera de espejos (Frasco) | La ficha `-1` | Nunca llega al caso base: aparece el **Espejo Infinito** (RecursionError). Con 5 → éxito. |
| 2 – El reflejo al revés (Frasco) | `'hola'` y `'!'` | Éxito. |
| 3 – El factorial reflejado (código) | Resolverlo con un `for` | Prohibido. `factorial(20)` tiene que dar 2432902008176640000. |
| 4 – Binario de espejo (código) | Sin caso base para 0 y 1 | RecursionError. |
| 5 – Las torres de Hanoi (código) | n = 4 | 15 movimientos. |
| Minijuego – Bola de cristal | Ronda 3 (sin caso base) | La respuesta correcta es `RecursionError`. |
| Boss – Espejo Infinito | Ronda 2: el caso base `n == 10` | RecursionError hasta cambiarlo por `n < 10`. Ronda 3: la variable `carpeta` aparece en cada caso. Al ganar: "¡Dominaste el Grimorio!". |

## 8. Guardado

1. Completá un par de niveles y cerrá el juego.
2. Volvé a abrir con F5 → **Continuar** → el progreso, el XP y la racha siguen ahí.
3. El archivo está en `user://save.json`. En Mac: `~/Library/Application Support/Godot/app_userdata/Pythoria/save.json`. Si lo editás y borrás claves o lo rompés, el juego arranca igual con valores por defecto.

## 9. Versión web

**Publicada en Vercel:** <https://pythoria-eta.vercel.app> (pública, sin login). El progreso queda guardado en el navegador de quien juega (IndexedDB), así que cada persona arranca de cero.

**Modo revisor:** <https://pythoria-eta.vercel.app/?revisor=1> abre todos los mundos con contenido y todas sus casitas, para revisar sin jugar en orden. La barra de arriba dice "Modo revisor". No cambia el progreso guardado. En el juego de escritorio se activa en **Opciones** o lanzando Godot con `-- --revisor`.

**Publicación automática:** cada push a `main` corre los tests en GitHub Actions y, si pasan, publica en la misma URL (ver `.github/workflows/ci.yml`). Necesita los secretos de Vercel cargados en GitHub.

Para publicar a mano:

```bash
tools/deploy_web.sh            # exporta y publica en producción (misma URL)
tools/deploy_web.sh --preview  # URL de prueba aparte, sin tocar producción
```

Para probarla local sin publicar:

```bash
godot --headless --path . --export-release "Web" build/web/index.html
cd build/web && python3 -m http.server 8000
```

Abrí <http://localhost:8000> en Chrome o Firefox. Debería verse el splash con el grimorio y después el menú (sin el botón **Salir**).
