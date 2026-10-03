extends Node3D
## Mario Kart 64 Battle scene: four karts with three balloons each in a walled arena. Items pop
## balloons, so does the lava / the edge, a star's touch and a heavy kart's hard shove. A kart
## with no balloons becomes a Mini Bomb Kart that blows up on the first balloon kart it rams.
## Last kart with balloons wins. Esc returns to the menu, Enter after the results battles again.

const Kart := preload("res://scripts/kart.gd")
const SpeedFx := preload("res://scripts/speed_fx.gd")
const KartEffects := preload("res://scripts/kart_effects.gd")
const Arena := preload("res://scripts/arena.gd")
const ArenaData := preload("res://scripts/arena_data.gd")
const Battle := preload("res://scripts/battle.gd")
const BattleAi := preload("res://scripts/battle_ai.gd")
const Balloons := preload("res://scripts/balloons.gd")
const Hud := preload("res://scripts/hud.gd")
const ItemManager := preload("res://scripts/item_manager.gd")
const RaceStart := preload("res://scripts/race_start.gd")
const GameAudio := preload("res://scripts/game_audio.gd")
const AiEngineAudio := preload("res://scripts/ai_engine_audio.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const KartWeight := preload("res://scripts/kart_weight.gd")
const Lakitu := preload("res://scripts/lakitu.gd")
const BlueBlast := preload("res://scripts/blue_blast.gd")
const Items := preload("res://scripts/items.gd")
const RaceMain := preload("res://scripts/main.gd")

const BOMB_BLAST_RADIUS := 4.0
## The three AI opponents: body colour, weight class (the player is kart 0).
const AI_SPECS := [
	[Color(0.15, 0.3, 0.95), KartWeight.HEAVY],    # BLUE
	[Color(0.15, 0.75, 0.25), KartWeight.LIGHT],   # GREEN
	[Color(0.65, 0.2, 0.85), KartWeight.MEDIUM],   # PURPLE
]

var kart: CharacterBody3D
var cam: Camera3D
var speed_fx
var arena
var data
var battle
var hud
var items
var karts: Array = []
var gear: Array = []        # Balloons node per kart
var race_start := RaceStart.new()
var audio
var lakitu
var results_shown := false
var result_timer := 0.0
var blasts: Array = []
var player_out_time := -1.0   # seconds since the player's bomb kart went off (-1 = still in)

func _ready() -> void:
	var spec: Dictionary = ArenaData.info(Battle.arena)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = spec.sky_top
	sky_mat.sky_horizon_color = spec.sky_horizon
	sky_mat.ground_horizon_color = spec.sky_horizon
	e.sky.sky_material = sky_mat
	e.glow_enabled = true
	e.glow_hdr_threshold = 1.0
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)

	data = ArenaData.make(Battle.arena)
	# the floor is only as big as the arena: off a rooftop there is nothing to drive on
	var ground := StaticBody3D.new()
	var gcol := CollisionShape3D.new()
	var gshape := BoxShape3D.new()
	var side: float = data.half * 2.0 + (ArenaData.EDGE_FALL * 2.0 if not data.walled else 400.0)
	gshape.size = Vector3(side, 1, side)
	gcol.shape = gshape
	ground.add_child(gcol)
	var gmesh := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(side, 1, side)
	gmesh.mesh = plane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = spec.ground
	gmesh.material_override = gmat
	ground.add_child(gmesh)
	ground.position = Vector3(0, -0.5, 0)
	add_child(ground)
	arena = Arena.new(data)
	add_child(arena)
	battle = Battle.new(Battle.PLAYERS)

	var engine: Dictionary = TrackLibrary.engine_info(TrackLibrary.engine_class)
	for i in Battle.PLAYERS:
		var k := Kart.new()
		var s: Dictionary = data.spawns[i]
		k.position = s.position
		k.heading = s.heading
		k.kart_id = i
		if i == 0:
			kart = k
			k.apply_weight_class(KartWeight.selected)
		else:
			k.body_color = AI_SPECS[i - 1][0]
			k.driver = BattleAi.new(data, 1.0 + 0.6 * i)
			k.apply_weight_class(AI_SPECS[i - 1][1])
		add_child(k)
		k.model.apply_engine_class(engine.speed, engine.accel)
		if i > 0:
			k.model.max_speed *= TrackLibrary.difficulty_info(TrackLibrary.difficulty).speed
			var engine_sfx := AiEngineAudio.new()
			engine_sfx.kart = k
			k.add_child(engine_sfx)
		var g := Balloons.new(k.body_color, Battle.BALLOONS)
		k.add_child(g)
		gear.append(g)
		k.bumped.connect(_on_bump.bind(i))
		karts.append(k)

	items = ItemManager.new()
	add_child(items)
	items.setup(data, karts, 0, true, true)
	items.kart_hit.connect(_on_kart_hit)

	cam = Camera3D.new()
	cam.current = true
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = kart.position + _back() * 6.0 + Vector3(0, 3.0, 0)
	speed_fx = SpeedFx.new()
	add_child(speed_fx)
	hud = Hud.new()
	add_child(hud)
	hud.setup_minimap(data.outline())
	hud.show_cup("BATTLE - %s" % data.name)
	audio = GameAudio.new()
	add_child(audio)
	audio.setup(kart, items)
	lakitu = Lakitu.new()
	add_child(lakitu)
	lakitu.setup(kart, data)
	for k in karts:
		k.frozen = true
	race_start.go.connect(_on_go)
	kart.model.boost_started.connect(_on_player_boost)

func _on_player_boost(level: int) -> void:
	if kart.model.boost_from_drift:
		speed_fx.trigger_flash(KartEffects.spark_color(level))

func _on_go() -> void:
	for k in karts:
		k.frozen = false
	var b := race_start.start_boost()
	if race_start.false_start():
		kart.model.stall(RaceStart.STALL_TIME)
	elif b > 0.0:
		kart.model.apply_boost(b, 1)

## An item (or a star kart) got kart `id`: one balloon gone.
func _on_kart_hit(_kind: int, id: int) -> void:
	_pop(id)

## Hard shove by a heavier kart pops a balloon of the lighter one (MK64: Bowser rams Toad).
func _on_bump(other, closing: float, id: int) -> void:
	if closing >= Battle.SHOVE_POP_SPEED and karts[id].mass > other.mass and battle.has_balloons(other.kart_id):
		if other.model.spin_out():
			_pop(other.kart_id)

func _pop(id: int) -> void:
	if not battle.has_balloons(id):
		return
	var now_bomb: bool = battle.hit(id)
	gear[id].set_count(battle.balloons[id])
	audio.play("pop", 0.0 if id == 0 else -6.0)
	if now_bomb:
		_become_bomb(id)

func _become_bomb(id: int) -> void:
	gear[id].set_bomb(true)
	karts[id].body_mesh.set_opacity(0.0)
	items.holders[id].clear()
	items.holders[id].locked = true   # bomb karts can't pick up items
	if id == 0:
		speed_fx.trigger_flash(Color(1.0, 0.3, 0.1))

## Bomb kart `bomb` rammed balloon kart `victim`: explosion, balloon gone, bomb kart out.
func _explode(bomb: int, victim: int) -> void:
	if not battle.bomb_hit(bomb, victim):
		return
	var at: Vector3 = karts[bomb].global_position
	var blast := BlueBlast.new()
	add_child(blast)
	blast.build(at, BOMB_BLAST_RADIUS)
	blasts.append(blast)
	audio.play("explosion", 0.0 if (bomb == 0 or victim == 0) else -6.0)
	audio.play("pop", 0.0 if victim == 0 else -6.0)
	karts[victim].model.spin_out()
	gear[victim].set_count(battle.balloons[victim])
	if battle.balloons[victim] == 0:
		_become_bomb(victim)
	# the spent bomb kart is parked out of the way
	var k = karts[bomb]
	k.frozen = true
	k.model.stop()
	k.visible = false
	k.set_physics_process(false)
	k.position = Vector3(data.half * 3.0, -50, data.half * 3.0)
	if bomb == 0:
		player_out_time = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		return
	if results_shown and event is InputEventKey and event.pressed and not event.echo \
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER):
		get_tree().reload_current_scene()

func _back() -> Vector3:
	return Vector3(sin(kart.heading), 0, cos(kart.heading))

## Standings 1..n per kart for the item roll (the kart with the fewest balloons gets the best items).
func _ranks() -> Array:
	var out: Array = []
	out.resize(karts.size())
	for i in karts.size():
		out[i] = battle.rank_of(i)
	return out

func _physics_process(delta: float) -> void:
	race_start.update(delta, Input.is_action_pressed("accelerate"))
	if race_start.started:
		battle.update(delta)
	items.ranks_override = _ranks()
	var positions: Array = []
	for k in karts:
		positions.append(k.global_position)
	var boxes: Array = []
	for b in items.boxes:
		if b.is_available():
			boxes.append(b.position)
	for i in karts.size():
		var k = karts[i]
		if battle.is_out(i):
			continue
		var kp: Vector3 = k.global_position
		# fell in the lava / off the roof: Lakitu fishes the kart out and it loses a balloon
		if not k.is_rescued() and data.in_pit(kp):
			k.start_rescue(data.respawn_point(kp), data.respawn_heading(kp))
			if k == kart:
				audio.play("splash")
			_pop(i)
		# AI goals: a box when empty-handed, else the nearest balloon kart
		if k.driver != null:
			var targets: Array = []
			for j in karts.size():
				if j != i and battle.has_balloons(j) and not battle.is_out(j):
					targets.append(positions[j])
			k.driver.goal = BattleAi.pick_goal(kp, items.holders[i].held, boxes, targets, not battle.is_bomb(i))
		# bomb karts go off on contact with a balloon kart
		if battle.is_bomb(i) and race_start.started:
			for j in karts.size():
				if j != i and battle.has_balloons(j) and not karts[j].is_rescued() and kp.distance_to(positions[j]) <= Battle.BOMB_RADIUS:
					_explode(i, j)
					break
	for b in blasts.duplicate():
		if not b.tick(delta):
			blasts.erase(b)
			b.queue_free()
	audio.update_audio(delta, race_start)
	lakitu.update_lakitu(delta, race_start.remaining, race_start.started, race_start.since_go)
	if player_out_time >= 0.0:
		player_out_time += delta
	var decided: bool = battle.over or (player_out_time >= 0.0)
	if decided:
		result_timer += delta
		if not results_shown and result_timer >= Battle.RESULTS_DELAY:
			results_shown = true
			if battle.winner == 0:
				audio.play_finish()
			hud.show_results(battle.results_text(RaceMain.RACER_NAMES, data.name, 0))
	var banner := ""
	if battle.over:
		banner = "YOU WIN!" if battle.winner == 0 else "BATTLE OVER"
	elif battle.is_out(0):
		banner = "OUT"
	elif battle.is_bomb(0):
		banner = "BOMB KART!"
	hud.update_battle(Battle.balloon_text(battle.balloons[0], battle.is_out(0)), battle.time, kart.model.speed, kart.model.is_boosting(), kart.model.drift_level, items.holder.display_item(items.time), Hud.place_text(battle.rank_of(0), karts.size()), kart.model.is_star(), kart.model.is_shrunk(), items.holder.charges, items.holder.golden_time, kart.model.is_ghost(), banner)
	hud.show_countdown(race_start.label())
	var marker_pos: Array = []
	var marker_col: Array = []
	for i in karts.size():
		if battle.is_out(i):
			continue
		marker_pos.append(positions[i])
		marker_col.append(karts[i].body_color)
	hud.update_minimap(marker_pos, marker_col)

func _process(delta: float) -> void:
	var target := kart.global_position + _back() * 6.0 + Vector3(0, 3.0, 0)
	cam.global_position = cam.global_position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(kart.global_position + Vector3(0, 1.0, 0))
	var ratio: float = absf(kart.model.speed) / kart.model.max_speed
	speed_fx.update_fx(delta, ratio, kart.model.is_boosting())
	cam.fov = lerpf(cam.fov, 70.0 + 10.0 * speed_fx.speed_amount + 12.0 * speed_fx.boost_amount, clampf(5.0 * delta, 0.0, 1.0))
