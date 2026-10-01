extends MeshInstance3D
## Ribbon trail left behind a wheel/exhaust. Points age out; mesh is rebuilt each frame.

var width := 0.25
var lifetime := 1.2
var min_dist := 0.15
var max_points := 120
var emitting := false
var color := Color(0.05, 0.05, 0.05, 0.7)
var points: Array[Vector3] = []
var ages: Array[float] = []
var _im := ImmediateMesh.new()

func _init() -> void:
	top_level = true
	mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Feed the current world position of the emitter (call every physics frame).
func track(delta: float, world_pos: Vector3) -> void:
	for i in ages.size():
		ages[i] += delta
	while ages.size() > 0 and ages[0] > lifetime:
		ages.pop_front()
		points.pop_front()
	if emitting and (points.is_empty() or points[-1].distance_to(world_pos) >= min_dist):
		points.append(world_pos)
		ages.append(0.0)
		if points.size() > max_points:
			points.pop_front()
			ages.pop_front()
	_rebuild()

func clear_trail() -> void:
	points.clear()
	ages.clear()
	_im.clear_surfaces()

## Break the ribbon (e.g. wheel left the ground / drift ended) by inserting a gap.
func break_trail() -> void:
	if points.size() > 0 and points[-1] != Vector3.INF:
		points.append(Vector3.INF)
		ages.append(ages[-1])

func _rebuild() -> void:
	_im.clear_surfaces()
	var strip: Array = []
	for i in points.size():
		if points[i] == Vector3.INF:
			_flush(strip)
			strip = []
		else:
			strip.append(i)
	_flush(strip)

func _flush(strip: Array) -> void:
	if strip.size() < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in strip.size():
		var i: int = strip[k]
		var p := points[i]
		var a: Vector3 = points[strip[k + 1]] - p if k + 1 < strip.size() else p - points[strip[k - 1]]
		var side := a.cross(Vector3.UP).normalized() * width * 0.5
		var c := color
		c.a *= clampf(1.0 - ages[i] / lifetime, 0.0, 1.0)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side + Vector3(0, 0.02, 0))
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side + Vector3(0, 0.02, 0))
	_im.surface_end()
