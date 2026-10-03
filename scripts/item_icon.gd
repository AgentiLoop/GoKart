extends Control
## Mario Kart 64 style item icon for the HUD's item window: every item is drawn from a few
## primitives (circles, polygons, strokes, a glyph) in a unit space (-1..1, y down) so the
## icon scales with the window. `glyph(type)` is pure data and unit tested; `_draw` renders it.

const Items := preload("res://scripts/items.gd")

const CAP_RED := Color(0.9, 0.12, 0.1)
const CAP_GOLD := Color(1.0, 0.78, 0.15)
const CREAM := Color(0.98, 0.95, 0.85)
const SHELL_GREEN := Color(0.15, 0.68, 0.2)
const SHELL_RED := Color(0.88, 0.14, 0.1)
const SHELL_BLUE := Color(0.18, 0.4, 0.95)
const SHELL_RIM := Color(0.96, 0.96, 0.92)
const BANANA := Color(1.0, 0.86, 0.15)
const BANANA_TIP := Color(0.45, 0.28, 0.08)
const STAR := Color(1.0, 0.9, 0.2)
const BOLT := Color(1.0, 0.92, 0.3)
const BOLT_SHADE := Color(0.95, 0.6, 0.1)
const BOX_RED := Color(0.75, 0.1, 0.12, 0.9)
const BOO := Color(0.97, 0.97, 1.0)
const INK := Color(0.08, 0.06, 0.1)
const TONGUE := Color(0.95, 0.4, 0.55)

var item := Items.Type.NONE: set = set_item
var font: Font

func set_item(t: int) -> void:
	if t != item:
		item = t
		queue_redraw()

## Points of a circle arc (angles in radians, y down) — used to build domes and crescents.
static func arc(c: Vector2, r: float, a0: float, a1: float, n := 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

## Half disc standing on its flat side (a cap or a shell dome).
static func dome(c: Vector2, r: float) -> PackedVector2Array:
	return arc(c, r, PI, TAU)

static func star_points(c: Vector2, r: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else inner))
	return pts

## A crescent: outer arc one way, inner arc back.
static func crescent(c: Vector2, r: float, inner_shift: Vector2, inner_r: float) -> PackedVector2Array:
	var pts := arc(c, r, PI * 0.1, PI * 0.9)
	var back := arc(c + inner_shift, inner_r, PI * 0.9, PI * 0.1)
	pts.append_array(back)
	return pts

static func poly(points: PackedVector2Array, col: Color) -> Dictionary:
	return {"poly": points, "col": col}

static func circle(c: Vector2, r: float, col: Color) -> Dictionary:
	return {"circle": c, "r": r, "col": col}

## Shift and scale a glyph (for the triple items: three small copies).
static func place(prims: Array, offset: Vector2, s: float) -> Array:
	var out: Array = []
	for p in prims:
		var q: Dictionary = p.duplicate()
		if q.has("poly"):
			var pts := PackedVector2Array()
			for v in q.poly:
				pts.append(offset + v * s)
			q.poly = pts
		if q.has("circle"):
			q.circle = offset + q.circle * s
			q.r = q.r * s
		if q.has("text"):
			q.at = offset + q.at * s
			q.size = q.size * s
		out.append(q)
	return out

static func mushroom(cap: Color) -> Array:
	return [
		poly(PackedVector2Array([Vector2(-0.3, 0.05), Vector2(0.3, 0.05), Vector2(0.32, 0.72), Vector2(-0.32, 0.72)]), CREAM),
		poly(dome(Vector2(0, 0.08), 0.74), cap),
		circle(Vector2(-0.3, -0.22), 0.14, Color.WHITE),
		circle(Vector2(0.22, -0.4), 0.13, Color.WHITE),
		circle(Vector2(0.42, -0.02), 0.1, Color.WHITE),
		circle(Vector2(-0.12, 0.42), 0.05, INK),
		circle(Vector2(0.12, 0.42), 0.05, INK),
	]

static func shell(col: Color) -> Array:
	return [
		poly(PackedVector2Array([Vector2(-0.82, 0.12), Vector2(0.82, 0.12), Vector2(0.74, 0.42), Vector2(-0.74, 0.42)]), SHELL_RIM),
		poly(dome(Vector2(0, 0.14), 0.68), col),
		circle(Vector2(0, -0.2), 0.16, col.lightened(0.35)),
		circle(Vector2(-0.34, 0.0), 0.11, col.lightened(0.35)),
		circle(Vector2(0.34, 0.0), 0.11, col.lightened(0.35)),
	]

static func banana() -> Array:
	return [
		poly(crescent(Vector2(0, -0.2), 0.78, Vector2(0, -0.3), 0.6), BANANA),
		circle(Vector2(-0.68, 0.08), 0.09, BANANA_TIP),
		circle(Vector2(0.68, 0.08), 0.09, BANANA_TIP),
	]

static func triple(one: Array) -> Array:
	var out: Array = []
	out.append_array(place(one, Vector2(0, -0.42), 0.5))
	out.append_array(place(one, Vector2(-0.48, 0.42), 0.5))
	out.append_array(place(one, Vector2(0.48, 0.42), 0.5))
	return out

## Drawing primitives for an item type (empty for NONE).
static func glyph(t: int) -> Array:
	match t:
		Items.Type.MUSHROOM:
			return mushroom(CAP_RED)
		Items.Type.GOLDEN_MUSHROOM:
			return mushroom(CAP_GOLD)
		Items.Type.TRIPLE_MUSHROOM:
			return triple(mushroom(CAP_RED))
		Items.Type.BANANA:
			return banana()
		Items.Type.BANANA_BUNCH:
			return triple(banana())
		Items.Type.SHELL:
			return shell(SHELL_GREEN)
		Items.Type.RED_SHELL:
			return shell(SHELL_RED)
		Items.Type.TRIPLE_SHELL:
			return triple(shell(SHELL_GREEN))
		Items.Type.TRIPLE_RED_SHELL:
			return triple(shell(SHELL_RED))
		Items.Type.BLUE_SHELL:
			var out := shell(SHELL_BLUE)
			for a in [PI * 1.15, PI * 1.4, PI * 1.6, PI * 1.85]:
				var d := Vector2(cos(a), sin(a))
				var c := Vector2(0, 0.14)
				out.append(poly(PackedVector2Array([c + d * 0.6 + d.orthogonal() * 0.12, c + d * 0.6 - d.orthogonal() * 0.12, c + d * 0.9]), SHELL_RIM))
			return out
		Items.Type.STAR:
			return [
				poly(star_points(Vector2(0, 0.05), 0.9, 0.42), STAR),
				circle(Vector2(-0.14, 0.0), 0.07, INK),
				circle(Vector2(0.14, 0.0), 0.07, INK),
			]
		Items.Type.LIGHTNING:
			var bolt := PackedVector2Array([Vector2(0.1, -0.9), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.25, 0.9), Vector2(0.55, -0.2), Vector2(0.05, -0.2)])
			return [place([poly(bolt, BOLT_SHADE)], Vector2(0.08, 0.08), 1.0)[0], poly(bolt, BOLT)]
		Items.Type.FAKE_ITEM_BOX:
			return [
				poly(PackedVector2Array([Vector2(0, -0.9), Vector2(0.9, 0), Vector2(0, 0.9), Vector2(-0.9, 0)]), BOX_RED),
				poly(PackedVector2Array([Vector2(0, -0.72), Vector2(0.72, 0), Vector2(0, 0.72), Vector2(-0.72, 0)]), Color(1, 0.3, 0.3, 0.35)),
				{"text": "¿", "at": Vector2(0, 0), "size": 1.1, "col": Color.WHITE},
			]
		Items.Type.BOO:
			return [
				circle(Vector2(0, 0), 0.78, BOO),
				circle(Vector2(-0.82, 0.1), 0.2, BOO),
				circle(Vector2(0.82, 0.1), 0.2, BOO),
				poly(PackedVector2Array([Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.3, 0.9), Vector2(0.0, 0.6), Vector2(-0.3, 0.9)]), BOO),
				circle(Vector2(-0.26, -0.18), 0.1, INK),
				circle(Vector2(0.26, -0.18), 0.1, INK),
				poly(PackedVector2Array([Vector2(-0.3, 0.2), Vector2(0.3, 0.2), Vector2(0.0, 0.45)]), INK),
				circle(Vector2(0.0, 0.42), 0.12, TONGUE),
			]
	return []

func _draw() -> void:
	var half := minf(size.x, size.y) * 0.5
	var c := size * 0.5
	for p in glyph(item):
		var col: Color = p.col
		if p.has("poly"):
			var pts := PackedVector2Array()
			for v in p.poly:
				pts.append(c + v * half)
			draw_colored_polygon(pts, col)
		elif p.has("circle"):
			draw_circle(c + p.circle * half, p.r * half, col)
		elif p.has("text") and font != null:
			var px := int(p.size * half)
			var w := font.get_string_size(p.text, HORIZONTAL_ALIGNMENT_CENTER, -1, px).x
			var at: Vector2 = c + p.at * half
			draw_string(font, Vector2(at.x - w * 0.5, at.y + px * 0.36), p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
