extends Node3D
## Shader warm-up during the course intro: the GPU builds a material's pipeline the first time
## it is drawn, which made the race hitch when the camera cut to the grid, at the rocket start
## and on the first drift, boost, Star, Boo, shell or lightning. For WARM_FRAMES drawn frames at
## the start of the intro, two small off-screen viewports (sharing the race world) draw the grid
## from the race camera's spot and a staging area far below the ground holding one of every kart
## effect and item visual; then it all goes away. The player never sees any of it.

const KartModel := preload("res://scripts/kart_model.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const LightningBolt := preload("res://scripts/lightning_bolt.gd")
const BlueBlast := preload("res://scripts/blue_blast.gd")
const Items := preload("res://scripts/items.gd")

const WARM_FRAMES := 20
const STAGE_DEPTH := 200.0   # metres below the grid: under the ground, out of sight and light range
const VIEW_SIZE := Vector2i(256, 144)

var frames_left := WARM_FRAMES
var effects
var trails_at := 0.0
var hud_parts: Array[CanvasItem] = []

## `cam_from` / `cam_to`: the race camera's pose behind the player at the start of the countdown.
func setup(cam_from: Vector3, cam_to: Vector3, item_manager, hud) -> void:
	hud_parts.assign(hud.race_controls)
	if hud.minimap != null:
		hud_parts.append(hud.minimap)
	for c in hud_parts:
		c.visible = true
		c.modulate.a = 0.0
	_add_view(cam_from, cam_to)
	var stage := cam_to - Vector3(0, STAGE_DEPTH, 0)
	position = stage
	var body := KartModel.new()
	add_child(body)
	body.build(Color(0.9, 0.1, 0.1))
	body.set_opacity(0.5)   # Boo: the see-through kart
	var star := KartModel.new()
	add_child(star)
	star.position = Vector3(2.5, 0, 0)
	star.build(Color(0.1, 0.3, 0.9))
	effects = KartEffects.new()
	add_child(effects)
	effects.setup(KartPhysics.new(), [Vector3(-0.8, 0, -0.8), Vector3(0.8, 0, -0.8), Vector3(-0.8, 0, 0.8), Vector3(0.8, 0, 0.8)])
	effects.setup_star(star)
	effects._on_star_started()
	for p in effects.sparks + effects.flames + effects.pops + effects.smoke + effects.wind + effects.dust:
		p.emitting = true
	effects.flash_light.visible = true
	effects.flash_light.light_energy = 8.0
	var props: Array[Node3D] = [item_manager._make_banana_node(), item_manager._make_boo_node(),
		item_manager._make_fake_box_node()]
	for kind in [Items.Type.SHELL, Items.Type.RED_SHELL, Items.Type.BLUE_SHELL]:
		props.append(item_manager._make_shell_mesh(kind, 0.55))
	for i in props.size():
		add_child(props[i])
		props[i].position = Vector3(-3.0 + 1.2 * i, 0.5, -2.0)
	var bolt := LightningBolt.new()
	add_child(bolt)
	bolt.build(Vector3(-2.5, 0, 0))
	bolt.scale = Vector3.ONE * 0.05
	var blast := BlueBlast.new()
	add_child(blast)
	blast.build(Vector3(0, 0.5, 2.5), 1.0)
	_add_view(stage + Vector3(0, 3.0, 7.0), stage + Vector3(0, 0.5, 0))

## A small viewport drawing the race world from `from`, looking at `to`, with the main
## window's 3D settings (the pipelines it builds must be the ones the race camera uses).
func _add_view(from: Vector3, to: Vector3) -> void:
	var root := get_tree().root
	var view := SubViewport.new()
	view.size = VIEW_SIZE
	view.msaa_3d = root.msaa_3d
	view.screen_space_aa = root.screen_space_aa
	view.use_debanding = root.use_debanding
	view.scaling_3d_mode = root.scaling_3d_mode
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var cam := Camera3D.new()
	cam.fov = 70.0
	view.add_child(cam)
	cam.look_at_from_position(from, to)

func _process(delta: float) -> void:
	# the tire trails are ribbons built from the wheel positions they are fed
	trails_at += delta
	for t in effects.trails:
		t.emitting = true
		t.color = KartEffects.spark_color(1)
		t.track(delta, global_position + Vector3(trails_at * 4.0, 0.02, 1.0 + t.get_index() * 0.1))
	frames_left -= 1
	if frames_left <= 0:
		for c in hud_parts:
			c.visible = false
			c.modulate.a = 1.0
		queue_free()
