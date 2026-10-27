class_name ThemeColors
extends RefCounted
## Paleta y fuentes de Pythoria. Único lugar donde se definen colores (ver docs/DISENO.md §6).
## resources/ui_theme.tres se genera a partir de este archivo con tools/gen_theme.gd.

const NOCHE := Color("#1E1B3A")      # Fondo general
const VIOLETA := Color("#6C4AB6")    # Botones, marcos
const LAVANDA := Color("#A98BE8")    # Hover, brillos, esencia número
const DORADO := Color("#F2B84B")     # Solo XP, medallas, recompensas
const TURQUESA := Color("#3FD1C0")   # Éxito
const ROJO := Color("#E5484D")       # Solo errores y criaturas del Caos
const PERGAMINO := Color("#F4E9D2")  # Paneles claros
const TINTA := Color("#2B2440")      # Texto sobre pergamino

const GRIS_BLOQUEADO := Color("#5A5670")
const NOCHE_CLARA := Color("#2A2650")
const SOMBRA := Color(0.0, 0.0, 0.0, 0.35)

const FONT_TITLE := "res://assets/fonts/Fredoka.ttf"
const FONT_CODE := "res://assets/fonts/FiraCode.ttf"
const FONT_BODY := "res://assets/fonts/Nunito.ttf"

## Color de esencia según tipo de Python (sin dorado ni rojo).
static func essence(type_name: String) -> Color:
	match type_name:
		"int":
			return LAVANDA
		"str":
			return PERGAMINO
		"bool":
			return TURQUESA
	return GRIS_BLOQUEADO

static func world_color(world: Dictionary) -> Color:
	return Color(str(world.get("color", "#6C4AB6")))
