extends Node
## Keeps the 3D render at about 2560×1440 pixels at most: a bigger window (5K fullscreen) draws the
## 3D scene at a lower resolution and FSR upscales it, so the GPU keeps up. The HUD stays sharp.

const MAX_PIXELS := 2560.0 * 1440.0

func _ready() -> void:
	get_tree().root.size_changed.connect(_update)
	_update()

func _update() -> void:
	var root := get_tree().root
	var pixels := float(root.size.x * root.size.y)
	root.scaling_3d_scale = clampf(sqrt(MAX_PIXELS / maxf(pixels, 1.0)), 0.5, 1.0)
