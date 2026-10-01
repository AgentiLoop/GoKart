extends Node3D
## Floating "?" box on the track. Touching it starts the item roulette; it
## disappears for `cooldown` seconds and then respawns.

var radius := 1.6
var cooldown := 3.0
var respawn_left := 0.0
var cube: MeshInstance3D

func is_available() -> bool:
	return respawn_left <= 0.0

## Returns true (and hides the box) if a kart at pos picks it up.
func try_take(pos: Vector3) -> bool:
	if not is_available():
		return false
	var d := Vector2(pos.x - position.x, pos.z - position.z).length()
	if d > radius:
		return false
	respawn_left = cooldown
	_refresh()
	return true

func tick(delta: float) -> void:
	if respawn_left > 0.0:
		respawn_left = maxf(respawn_left - delta, 0.0)
		if respawn_left == 0.0:
			_refresh()

func _refresh() -> void:
	if cube != null:
		cube.visible = is_available()

func _ready() -> void:
	cube = MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(1.4, 1.4, 1.4)
	cube.mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/item_box.gdshader") as Shader
	cube.material_override = mat
	cube.position.y = 1.4
	add_child(cube)
	_refresh()

func _process(delta: float) -> void:
	if cube != null:
		cube.rotation.y += 1.6 * delta
		cube.rotation.x += 0.9 * delta
		cube.position.y = 1.4 + 0.15 * sin(Time.get_ticks_msec() * 0.003)
