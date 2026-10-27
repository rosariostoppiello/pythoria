class_name SectionLayout
extends RefCounted
## Arma la grilla de un mapa de sección a partir de data/worlds.json.
## Es determinista (misma semilla por mundo) y garantiza un camino libre
## desde el inicio hasta la puerta de cada casita.

const TILE := 64
const ROWS := 11

var cols: int = 0
var rows: int = ROWS
var start: Vector2i
var houses: Array[Dictionary] = []      # {id, kind, tile: Vector2i, door: Vector2i}
var path: Dictionary = {}               # Vector2i -> true
var water: Dictionary = {}
var trees: Dictionary = {}


static func build(world: Dictionary) -> SectionLayout:
	var l := SectionLayout.new()
	var sm: Dictionary = world.get("section_map", {})
	var max_x := 0
	for h: Dictionary in sm.get("houses", []):
		var t := Vector2i(int(h["pos"][0]), int(h["pos"][1]))
		max_x = maxi(max_x, t.x)
		l.houses.append({"id": str(h["id"]), "kind": str(h.get("kind", "level")), "tile": t, "door": t + Vector2i(0, 1)})
	var ps: Array = sm.get("player_start", [2, ROWS - 3])
	l.start = Vector2i(int(ps[0]), int(ps[1]))
	l.cols = maxi(max_x + 3, 20)
	l._make_path()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * int(world.get("id", 1))
	l._make_water(rng)
	l._make_trees(rng)
	return l


func size_px() -> Vector2:
	return Vector2(cols * TILE, rows * TILE)


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2.0, t.y * TILE + TILE / 2.0)


func is_house(t: Vector2i) -> bool:
	for h: Dictionary in houses:
		if h["tile"] == t:
			return true
	return false


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < cols and t.y < rows


func is_border(t: Vector2i) -> bool:
	return t.x == 0 or t.y == 0 or t.x == cols - 1 or t.y == rows - 1


## Se puede caminar por la celda (sin árbol, agua ni casita).
func is_walkable(t: Vector2i) -> bool:
	return in_bounds(t) and not is_border(t) and not is_house(t) and not water.has(t) and not trees.has(t)


func _make_path() -> void:
	var cur := start
	path[cur] = true
	for h: Dictionary in houses:
		for t: Vector2i in _bfs(cur, h["door"]):
			path[t] = true
		cur = h["door"]


## Camino más corto en la grilla esquivando casitas y bordes.
func _bfs(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var dirs := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if in_bounds(n) and not is_border(n) and not is_house(n) and not prev.has(n):
				prev[n] = c
				queue.append(n)
	var out: Array[Vector2i] = []
	if not prev.has(to):
		return out
	var c2 := to
	while c2 != from:
		out.push_front(c2)
		c2 = prev[c2]
	return out


## Celda libre y lejos (1 celda) del camino, las casitas y el inicio.
func _is_clear(t: Vector2i) -> bool:
	if not in_bounds(t) or is_border(t):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := t + Vector2i(dx, dy)
			if path.has(n) or is_house(n) or n == start:
				return false
	return true


func _make_water(rng: RandomNumberGenerator) -> void:
	var ponds := 0
	for attempt in 60:
		if ponds >= 2:
			break
		var w := rng.randi_range(2, 4)
		var h := rng.randi_range(2, 3)
		var origin := Vector2i(rng.randi_range(1, cols - w - 1), rng.randi_range(1, rows - h - 1))
		var cells: Array[Vector2i] = []
		var ok := true
		for y in h:
			for x in w:
				var t := origin + Vector2i(x, y)
				if not _is_clear(t) or water.has(t):
					ok = false
				cells.append(t)
		if ok:
			for t: Vector2i in cells:
				water[t] = true
			ponds += 1


func _make_trees(rng: RandomNumberGenerator) -> void:
	for y in rows:
		for x in cols:
			var t := Vector2i(x, y)
			if is_border(t):
				trees[t] = true
			elif not water.has(t) and _is_clear(t) and rng.randf() < 0.22:
				trees[t] = true


## Celdas alcanzables caminando desde el inicio (para tests).
func reachable_from_start() -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT]:
			var n: Vector2i = c + d
			if is_walkable(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen
