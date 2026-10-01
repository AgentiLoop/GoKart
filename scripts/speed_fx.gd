extends CanvasLayer
## Screen-space speed lines / boost blur driven by kart speed and boost state.

const SHADER := preload("res://shaders/speed_fx.gdshader")
var rect: ColorRect
var mat: ShaderMaterial
var speed_amount := 0.0
var boost_amount := 0.0
var _time := 0.0

func _init() -> void:
	layer = 5
	rect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	add_child(rect)

## Smoothly approaches the targets. Pure-ish so it can be tested without rendering.
func update_fx(delta: float, speed_ratio: float, boosting: bool) -> void:
	speed_amount = lerpf(speed_amount, clampf(speed_ratio, 0.0, 1.0), clampf(5.0 * delta, 0.0, 1.0))
	boost_amount = move_toward(boost_amount, 1.0 if boosting else 0.0, delta * (6.0 if boosting else 2.5))
	_time += delta
	if mat:
		mat.set_shader_parameter("speed_amount", speed_amount)
		mat.set_shader_parameter("boost_amount", boost_amount)
		mat.set_shader_parameter("time_s", _time)
