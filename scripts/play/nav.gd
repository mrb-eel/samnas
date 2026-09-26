class_name Nav
extends RefCounted
## Where a person can walk in a set: a grid over the floor rects, with
## furniture cut out, searched with A*, and the path pulled tight so people
## walk in straight lines where they can.

const CELL := 0.15
const RADIUS := 0.22  # half a body; the grid keeps this far from things

var grid := AStarGrid2D.new()
var origin := Vector2.ZERO  # world XZ of cell (0, 0)'s corner
var cols := 0
var rows := 0
var y := 0.0
var _ok := false

func build(s: SetBase) -> void:
	_ok = false
	if not s.can_walk():
		return
	y = s.floor_y
	var bounds: Rect2 = s.floors[0]
	for r in s.floors:
		bounds = bounds.merge(r)
	origin = bounds.position
	cols = int(ceil(bounds.size.x / CELL))
	rows = int(ceil(bounds.size.y / CELL))
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, cols, rows)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for cx in cols:
		for cz in rows:
			var p := _center(Vector2i(cx, cz))
			grid.set_point_solid(Vector2i(cx, cz), not _free(s, p))
	_ok = true

func _free(s: SetBase, p: Vector2) -> bool:
	var on_floor := false
	for r in s.floors:
		if r.grow(-RADIUS).has_point(p):
			on_floor = true
			break
	if not on_floor:
		return false
	for b in s.blocks:
		if b.grow(RADIUS).has_point(p):
			return false
	return true

func _center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * CELL

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL), floori((p.z - origin.y) / CELL))

func _in(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows

func walkable(p: Vector3) -> bool:
	if not _ok:
		return false
	var c := _cell(p)
	return _in(c) and not grid.is_point_solid(c)

## The nearest cell anyone could stand in, searching outwards in rings.
func nearest(p: Vector3) -> Vector3:
	if not _ok:
		return p
	var c := _cell(p)
	c.x = clampi(c.x, 0, cols - 1)
	c.y = clampi(c.y, 0, rows - 1)
	if not grid.is_point_solid(c):
		return Vector3(p.x, y, p.z) if walkable(p) else _w(c)
	for ring in range(1, maxi(cols, rows)):
		var best := Vector2i(-1, -1)
		var bd := INF
		for dx in range(-ring, ring + 1):
			for dz in [-ring, ring]:
				for k in 2:
					var q := c + (Vector2i(dx, dz) if k == 0 else Vector2i(dz, dx))
					if _in(q) and not grid.is_point_solid(q):
						var d := _center(q).distance_squared_to(Vector2(p.x, p.z))
						if d < bd:
							bd = d
							best = q
		if best.x >= 0:
			return _w(best)
	return p

func _w(c: Vector2i) -> Vector3:
	var v := _center(c)
	return Vector3(v.x, y, v.y)

func path(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	if not _ok:
		return out
	var sa := nearest(a)
	var sb := nearest(b)
	var ids := grid.get_id_path(_cell(sa), _cell(sb))
	if ids.is_empty():
		return out
	var raw: Array = [Vector3(a.x, y, a.z)]
	for i in range(1, ids.size() - 1):
		raw.append(_w(ids[i]))
	raw.append(sb)
	# string-pulling: skip every point we can see past
	var i := 0
	out.append(raw[0])
	while i < raw.size() - 1:
		var j := raw.size() - 1
		while j > i + 1 and not clear(raw[i], raw[j]):
			j -= 1
		out.append(raw[j])
		i = j
	return out

func clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := int(ceil(d.length() / (CELL * 0.5)))
	for k in range(1, n):
		var p := a.lerp(b, float(k) / n)
		if not walkable(p):
			return false
	return true
