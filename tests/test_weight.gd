extends RefCounted
## Mario Kart 64 weight classes: light / medium / heavy tuning, bump maths, kart node, AI field, menu.

const KartWeight := preload("res://scripts/kart_weight.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const Kart := preload("res://scripts/kart.gd")
const Menu := preload("res://scripts/menu.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
var runner

const DT := 1.0 / 60.0

func _menu():
	var m = Menu.new()
	m.laps_label = Label.new()
	m.difficulty_label = Label.new()
	m.engine_label = Label.new()
	m.weight_label = Label.new()
	m.mode_label = Label.new()
	m.name_label = Label.new()
	m.blurb_label = Label.new()
	m.index_label = Label.new()
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	return m

func _free_menu(m) -> void:
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.bg, m.preview, m]:
		n.free()

func test_mk64_three_weight_classes() -> void:
	var W := KartWeight
	runner.check(W.count() == 3 and W.LIGHT == 0 and W.MEDIUM == 1 and W.HEAVY == 2)
	runner.check(W.info(W.LIGHT).name == "Light" and W.info(W.MEDIUM).name == "Medium" and W.info(W.HEAVY).name == "Heavy")
	runner.check(W.selected == W.MEDIUM, "Medium is the default")
	# light: best pick-up, lowest top speed, lightest; heavy: the opposite; medium is the base tuning
	runner.check(W.info(0).accel > W.info(1).accel and W.info(1).accel > W.info(2).accel, "light accelerates best")
	runner.check(W.info(0).speed < W.info(1).speed and W.info(1).speed < W.info(2).speed, "heavy is fastest")
	runner.check(W.info(0).mass < W.info(1).mass and W.info(1).mass < W.info(2).mass, "masses ordered")
	runner.check(W.info(0).size < W.info(1).size and W.info(1).size < W.info(2).size, "sizes ordered")
	runner.check(is_equal_approx(W.info(1).speed, 1.0) and is_equal_approx(W.info(1).accel, 1.0) and is_equal_approx(W.info(1).mass, 1.0) and is_equal_approx(W.info(1).size, 1.0), "medium is the base")
	# the spread is a nuance, not a different game
	for i in 3:
		runner.check(W.info(i).speed >= 0.95 and W.info(i).speed <= 1.05, "speed %d" % i)
		runner.check(W.info(i).accel >= 0.8 and W.info(i).accel <= 1.25, "accel %d" % i)
		runner.check(W.info(i).blurb != "", "blurb %d" % i)
	runner.check(W.step(0, -1) == 2 and W.step(2, 1) == 0 and W.step(1, 1) == 2)
	runner.check(W.info(-1).name == "Heavy" and W.info(3).name == "Light", "info wraps")

func test_weight_class_scales_the_physics() -> void:
	var W := KartWeight
	var light := KartPhysics.new()
	light.apply_weight_class(W.info(W.LIGHT).speed, W.info(W.LIGHT).accel)
	var heavy := KartPhysics.new()
	heavy.apply_weight_class(W.info(W.HEAVY).speed, W.info(W.HEAVY).accel)
	var medium := KartPhysics.new()
	runner.check(light.max_speed < medium.max_speed and medium.max_speed < heavy.max_speed, "top speeds")
	runner.check(light.acceleration > medium.acceleration and medium.acceleration > heavy.acceleration, "accelerations")
	for i in 40:
		light.step(DT, 1.0, 0.0, 0.0, false)
		heavy.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(light.speed > heavy.speed, "light is quicker off the line: %f vs %f" % [light.speed, heavy.speed])
	for i in 600:
		light.step(DT, 1.0, 0.0, 0.0, false)
		heavy.step(DT, 1.0, 0.0, 0.0, false)
	runner.check(heavy.speed > light.speed, "heavy wins the long straight: %f vs %f" % [heavy.speed, light.speed])
	# stacks on top of the engine class
	var k := KartPhysics.new()
	k.apply_engine_class(0.75, 0.8)
	k.apply_weight_class(W.info(W.HEAVY).speed, W.info(W.HEAVY).accel)
	runner.check(is_equal_approx(k.max_speed, 30.0 * 0.75 * W.info(W.HEAVY).speed), "50cc heavy top speed %f" % k.max_speed)

func test_bump_maths_favour_the_heavier_kart() -> void:
	var W := KartWeight
	var light: float = W.info(W.LIGHT).mass
	var heavy: float = W.info(W.HEAVY).mass
	# the light kart is thrown much further than the heavy one in the same contact
	var light_shove: float = W.shove(light, heavy, 10.0)
	var heavy_shove: float = W.shove(heavy, light, 10.0)
	runner.check(light_shove > heavy_shove * 2.0, "light %f vs heavy %f" % [light_shove, heavy_shove])
	runner.check(heavy_shove > 0.0, "the heavy kart still feels it")
	var equal: float = W.shove(1.0, 1.0, 10.0)
	runner.check(equal > heavy_shove and equal < light_shove, "equal masses sit in between")
	runner.check(W.shove(1.0, 1.0, 20.0) > W.shove(1.0, 1.0, 0.0), "harder hits throw further")
	runner.check(is_equal_approx(W.shove(1.0, 1.0, 0.0), W.BUMP_BASE), "a nudge is the base shove")
	runner.check(is_equal_approx(W.shove(1.0, 1.0, -5.0), W.BUMP_BASE), "negative closing speed counts as zero")
	runner.check(W.shove(0.1, 5.0, 100.0) <= W.BUMP_MAX, "capped")
	# only the lighter kart loses forward speed
	runner.check(is_equal_approx(W.speed_keep(heavy, light), 1.0), "heavy keeps its speed")
	runner.check(is_equal_approx(W.speed_keep(1.0, 1.0), 0.85), "equal karts lose a little")
	runner.check(W.speed_keep(W.info(W.MEDIUM).mass, light) >= 1.0 and W.speed_keep(W.info(W.MEDIUM).mass, heavy) < 0.85, "medium sits in between")
	var keep: float = W.speed_keep(light, heavy)
	runner.check(keep < 1.0 and keep >= 0.6, "light is slowed: %f" % keep)
	runner.check(is_equal_approx(W.speed_keep(0.1, 10.0), 0.6), "floored at 60%%")
	runner.check(W.BUMP_COOLDOWN > 0.0 and W.PUSH_DECAY > 0.0)

func test_kart_node_applies_its_weight_class() -> void:
	var W := KartWeight
	var k = Kart.new()
	runner.check(k.weight_class == W.MEDIUM and is_equal_approx(k.mass, 1.0) and is_equal_approx(k.size_scale, 1.0), "medium by default")
	k.apply_weight_class(W.HEAVY)
	runner.check(k.weight_class == W.HEAVY and is_equal_approx(k.mass, W.info(W.HEAVY).mass) and is_equal_approx(k.size_scale, W.info(W.HEAVY).size))
	runner.check(is_equal_approx(k.model.max_speed, 30.0 * W.info(W.HEAVY).speed), "heavy top speed on the model")
	runner.check(k.push == Vector3.ZERO and k.bump_cooldown == 0.0 and k.bumps == 0)
	var light = Kart.new()
	light.apply_weight_class(W.LIGHT)
	runner.check(light.mass < k.mass and light.size_scale < k.size_scale)
	# a bump between the two (normal pointing from the heavy kart to the light one)
	light.model.speed = 20.0
	k.model.speed = 20.0
	light._bump(k, Vector3(1, 0, 0), Vector3(0, 0, -1))
	runner.check(light.bumps == 1 and k.bumps == 1, "both karts count the bump")
	runner.check(light.push.x > 0.0 and k.push.x < 0.0, "thrown apart along the normal: %s / %s" % [light.push, k.push])
	runner.check(light.push.length() > k.push.length() * 2.0, "the light kart flies: %f vs %f" % [light.push.length(), k.push.length()])
	runner.check(light.model.speed < 20.0 and is_equal_approx(k.model.speed, 20.0), "only the light kart is slowed")
	runner.check(light.bump_cooldown > 0.0 and k.bump_cooldown > 0.0, "cooldown on both")
	var before: Vector3 = light.push
	light._bump(k, Vector3(1, 0, 0), Vector3(0, 0, -1))
	runner.check(light.bumps == 1 and light.push == before, "no second shove during the cooldown")
	# wrapping index
	k.apply_weight_class(4)
	runner.check(k.weight_class == W.MEDIUM)
	k.free()
	light.free()

func test_ai_field_mixes_the_weight_classes() -> void:
	var Main := load("res://scripts/main.gd")
	var counts := [0, 0, 0]
	for spec in Main.AI_SPECS:
		runner.check(spec.size() == 3 and spec[2] >= 0 and spec[2] < KartWeight.count(), "spec has a weight class")
		counts[spec[2]] += 1
	runner.check(counts[0] >= 2 and counts[1] >= 2 and counts[2] >= 2, "every class is on the grid: %s" % str(counts))

func test_menu_steps_the_weight_class() -> void:
	runner.check(Menu.weight_direction_for_key(KEY_X) == -1 and Menu.weight_direction_for_key(KEY_V) == 1)
	runner.check(Menu.weight_direction_for_key(KEY_Z) == 0 and Menu.weight_direction_for_key(KEY_ENTER) == 0)
	runner.check(Menu.weight_text(KartWeight.HEAVY) == "Heavy - top speed, shoves others aside")
	runner.check(Menu.weight_text(KartWeight.LIGHT).begins_with("Light"))
	var m = _menu()
	m.weight_class = KartWeight.MEDIUM
	m.move_weight(1)
	runner.check(m.weight_class == KartWeight.HEAVY and m.weight_label.text == Menu.weight_text(KartWeight.HEAVY))
	m.move_weight(1)
	runner.check(m.weight_class == KartWeight.LIGHT and m.weight_label.text.contains("Light"), "wraps to Light")
	m.move_weight(-1)
	runner.check(m.weight_class == KartWeight.HEAVY, "wraps back to Heavy")
	# the menu's choice reaches the race through KartWeight.selected
	var old := KartWeight.selected
	KartWeight.selected = KartWeight.LIGHT
	var m2 = _menu()
	m2.weight_class = KartWeight.selected
	runner.check(m2.weight_class == KartWeight.LIGHT, "menu starts on the remembered class")
	KartWeight.selected = old
	_free_menu(m)
	_free_menu(m2)
