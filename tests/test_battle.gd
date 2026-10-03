extends RefCounted
## Mario Kart 64 Battle mode: arenas, balloon rules, bomb karts, battle AI, items, HUD, menu.

const ArenaData := preload("res://scripts/arena_data.gd")
const Arena := preload("res://scripts/arena.gd")
const Battle := preload("res://scripts/battle.gd")
const BattleAi := preload("res://scripts/battle_ai.gd")
const Balloons := preload("res://scripts/balloons.gd")
const Items := preload("res://scripts/items.gd")
const ItemHolder := preload("res://scripts/item_holder.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")
const KartPhysics := preload("res://scripts/kart_physics.gd")
const Kart := preload("res://scripts/kart.gd")
const Menu := preload("res://scripts/menu.gd")
const Hud := preload("res://scripts/hud.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")
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
	m.sub_label = Label.new()
	m.bg = ColorRect.new()
	m.preview = load("res://scripts/minimap.gd").new()
	return m

func _free_menu(m) -> void:
	for n in [m.laps_label, m.difficulty_label, m.engine_label, m.weight_label, m.mode_label, m.name_label, m.blurb_label, m.index_label, m.sub_label, m.bg, m.preview, m]:
		n.free()

func test_mk64_arenas() -> void:
	runner.check(ArenaData.arena_count() == 3, "three arenas")
	var names: Array = []
	for i in ArenaData.arena_count():
		var a = ArenaData.make(i)
		names.append(a.name)
		runner.check(a.arena == true and a.count == 1 and a.nearest_index(Vector3(5, 0, 5)) == 0, "track stand-ins on %s" % a.name)
		runner.check(a.spawns.size() == 4, "four start pads on %s" % a.name)
		for s in a.spawns:
			runner.check(not a.in_pit(s.position) and not a.in_block(s.position) and not a.obstacle_at(s.position), "pad clear on %s" % a.name)
			# facing the centre
			var fwd := Vector3(-sin(s.heading), 0, -cos(s.heading))
			runner.check(fwd.dot(-Vector3(s.position.x, 0, s.position.z).normalized()) > 0.99, "pad faces the centre on %s" % a.name)
		runner.check(a.item_box_positions.size() >= 6, "%s has %d item boxes" % [a.name, a.item_box_positions.size()])
		for p in a.item_box_positions:
			runner.check(not a.in_pit(p) and not a.in_block(p) and absf(p.x) < a.half and absf(p.z) < a.half, "box inside and dry on %s" % a.name)
		runner.check(a.hazard_positions.is_empty(), "no pre-placed bananas")
		runner.check(a.outline().size() == 4, "outline is the square")
		runner.check(ArenaData.info(i).blurb != "" and ArenaData.info(i).has("sky_top"), "menu data")
	runner.check(names == ["Big Donut", "Block Fort", "Skyscraper"], str(names))
	runner.check(ArenaData.step(0, -1) == 2 and ArenaData.step(2, 1) == 0, "arena choice wraps")
	# heading helper: forward is (-sin h, 0, -cos h)
	var h := ArenaData.heading_for(Vector3(1, 0, 0))
	runner.check(Vector3(-sin(h), 0, -cos(h)).distance_to(Vector3(1, 0, 0)) < 0.001, "heading_for")

func test_big_donut_pit_and_rescue() -> void:
	var a = ArenaData.make(0)
	runner.check(a.pit_radius > 0.0 and a.walled and a.blocks.is_empty())
	runner.check(a.in_pit(Vector3(3, 0, 4)) and not a.in_pit(Vector3(a.pit_radius + 1.0, 0, 0)), "pit is the centre disc")
	runner.check(not a.in_pit(Vector3(a.half + 10.0, 0, 0)), "walled arena: no falling off the edge")
	runner.check(a.obstacle_at(Vector3(a.pit_radius + 1.0, 0, 0)) and not a.obstacle_at(Vector3(a.pit_radius + 4.0, 0, 0)), "AI keeps a margin from the rim")
	runner.check(a.obstacle_at(Vector3(a.half - 1.0, 0, 0)) and not a.obstacle_at(Vector3(a.half - 5.0, 0, 0)), "and from the walls")
	var fell := Vector3(-6, 0, 2)
	var r: Vector3 = a.respawn_point(fell)
	runner.check(not a.in_pit(r) and Vector2(r.x, r.z).length() > a.pit_radius + 1.0 and Vector2(r.x, r.z).length() < a.pit_radius + ArenaData.RESPAWN_GAP + 0.5, "set down just outside the rim: %s" % r)
	runner.check(Vector2(r.x, r.z).normalized().dot(Vector2(fell.x, fell.z).normalized()) > 0.99, "on the side it fell in")
	var hd: float = a.respawn_heading(fell)
	runner.check(Vector3(-sin(hd), 0, -cos(hd)).dot(Vector3(fell.x, 0, fell.z).normalized()) > 0.99, "facing away from the lava")
	runner.check(a.respawn_point(Vector3.ZERO).length() > a.pit_radius, "dead centre still gets out")

func test_block_fort_walls_and_blocks() -> void:
	var a = ArenaData.make(1)
	runner.check(a.blocks.size() == 4 and a.walled and a.pit_radius == 0.0)
	runner.check(a.in_block(Vector3(-22, 0, -22)) and not a.in_block(Vector3(0, 0, 0)), "forts in the quadrants")
	runner.check(a.collide_circle(Vector3(0, 0, 0), 0.8).is_empty(), "the middle is clear")
	# wall: pushed back inside with an outward normal
	var hit: Dictionary = a.collide_circle(Vector3(a.half + 0.5, 0, 3), 0.8)
	runner.check(not hit.is_empty() and is_equal_approx(hit.position.x, a.half - 0.8) and hit.normal == Vector3(-1, 0, 0) and is_equal_approx(hit.position.z, 3.0), "east wall: %s" % str(hit))
	hit = a.collide_circle(Vector3(2, 0, -a.half - 2.0), 0.8)
	runner.check(not hit.is_empty() and hit.normal == Vector3(0, 0, 1) and is_equal_approx(hit.position.z, -a.half + 0.8), "north wall")
	# block: leaves through the nearest face
	var b: Rect2 = a.blocks[0]   # x -30..-14, z -30..-14
	hit = a.collide_circle(Vector3(-15.0, 0, -22.0), 0.8)
	runner.check(not hit.is_empty() and hit.normal == Vector3(1, 0, 0) and is_equal_approx(hit.position.x, b.end.x + 0.8), "east face of the fort: %s" % str(hit))
	hit = a.collide_circle(Vector3(-22.0, 0, -14.5), 0.8)
	runner.check(not hit.is_empty() and hit.normal == Vector3(0, 0, 1) and is_equal_approx(hit.position.z, b.end.y + 0.8), "south face of the fort: %s" % str(hit))
	runner.check(a.respawn_point(Vector3(10, 0, 10)) == Vector3(10, 0.1, 10), "nothing to respawn from inside a walled arena")
	# the corridors between the forts stay open for the AI
	runner.check(not a.obstacle_at(Vector3(0, 0, -22)) and not a.obstacle_at(Vector3(-22, 0, 0)) and a.obstacle_at(Vector3(-13, 0, -22)), "corridors clear, fort edges not")

func test_skyscraper_open_edges() -> void:
	var a = ArenaData.make(2)
	runner.check(not a.walled and a.pit_radius == 0.0)
	runner.check(not a.in_pit(Vector3(a.half, 0, 0)) and a.in_pit(Vector3(a.half + ArenaData.EDGE_FALL + 0.1, 0, 0)), "past the edge = fallen")
	runner.check(a.in_pit(Vector3(0, 0, -a.half - 2.0)), "every edge")
	runner.check(a.collide_circle(Vector3(a.half + 5.0, 0, 0), 0.8).is_empty(), "no walls to bounce off")
	var r: Vector3 = a.respawn_point(Vector3(a.half + 2.0, 0, 7.0))
	runner.check(is_equal_approx(r.x, a.half - ArenaData.RESPAWN_GAP) and is_equal_approx(r.z, 7.0), "set back down inside the edge: %s" % r)
	var hd: float = a.respawn_heading(Vector3(a.half + 2.0, 0, 0))
	runner.check(Vector3(-sin(hd), 0, -cos(hd)).dot(Vector3(-1, 0, 0)) > 0.99, "facing back into the arena")
	runner.check(a.obstacle_at(Vector3(a.half - 1.0, 0, 0)), "the AI treats the edge like a wall")

func test_battle_rules_balloons_bombs_and_winner() -> void:
	var b := Battle.new(4)
	runner.check(b.count() == 4 and b.balloons == [3, 3, 3, 3] and b.survivors() == [0, 1, 2, 3] and not b.over)
	runner.check(Battle.BALLOONS == 3 and Battle.PLAYERS == 4, "MK64: four karts, three balloons")
	runner.check(not b.hit(1) and b.balloons[1] == 2 and b.pops[1] == 1, "a hit pops one balloon")
	runner.check(not b.hit(1) and b.hit(1), "the third hit makes it a bomb kart")
	runner.check(b.is_bomb(1) and not b.has_balloons(1) and not b.is_out(1) and b.lost_order == [1])
	runner.check(not b.hit(1) and b.balloons[1] == 0, "a bomb kart has nothing left to lose")
	runner.check(b.survivors() == [0, 2, 3] and not b.over)
	# bomb kart rams kart 2: kart 2 loses a balloon, the bomb is spent
	runner.check(b.bomb_hit(1, 2) and b.is_out(1) and b.balloons[2] == 2, "bomb kart explodes on contact")
	runner.check(not b.bomb_hit(1, 2) and b.balloons[2] == 2, "only once")
	runner.check(not b.bomb_hit(0, 2), "a balloon kart isn't a bomb")
	runner.check(b.rank_of(0) == 1 and b.rank_of(3) == 2 and b.rank_of(2) == 3 and b.rank_of(1) == 4, "standings: %s" % str(b.placings()))
	b.hit(3)
	b.hit(3)
	b.hit(3)
	runner.check(b.lost_order == [1, 3] and b.placings() == [0, 2, 3, 1], "later losers place higher")
	for i in 2:
		b.hit(2)
	runner.check(b.over and b.winner == 0 and b.survivors() == [0], "last kart with balloons wins")
	runner.check(not b.hit(0) and b.balloons[0] == 3, "nothing changes after the battle")
	runner.check(b.placings() == [0, 2, 3, 1] and b.rank_of(0) == 1)
	# the clock only runs during the battle
	b.update(1.5)
	runner.check(b.time == 0.0, "clock stops when it is over")
	var c := Battle.new(2)
	c.update(2.0)
	c.hit(0)
	c.hit(0)
	c.hit(0)
	runner.check(c.over and c.winner == 1 and c.time == 2.0)
	# pure text helpers
	runner.check(Battle.balloon_text(3) == "BALLOONS OOO" and Battle.balloon_text(1) == "BALLOONS O")
	runner.check(Battle.balloon_text(0) == "BOMB KART!" and Battle.balloon_text(0, true) == "OUT")
	runner.check(Battle.time_text(65.43) == "1:05.4")
	var txt := b.results_text(["YOU", "BLUE", "GREEN", "PURPLE"], "Block Fort", 0)
	runner.check(txt.begins_with("BATTLE - Block Fort\nYOU WIN!"), txt)
	runner.check("> 1st  YOU      3 balloons" in txt and "  2nd  GREEN    bomb kart" in txt and "  4th  BLUE     exploded" in txt, txt)
	runner.check("Press ENTER to battle again" in txt)
	var lose := Battle.new(2)
	lose.hit(0)
	lose.hit(0)
	lose.hit(0)
	runner.check("BLUE WINS" in lose.results_text(["YOU", "BLUE"], "Big Donut", 0), "rival wins")

func test_battle_items_leave_out_the_race_only_ones() -> void:
	for t in Items.BATTLE_EXCLUDED:
		runner.check(not Items.in_battle(t), Items.name_of(t))
	runner.check(Items.in_battle(Items.Type.SHELL) and Items.in_battle(Items.Type.STAR) and Items.in_battle(Items.Type.BOO) and Items.in_battle(Items.Type.BANANA_BUNCH) and Items.in_battle(Items.Type.FAKE_ITEM_BOX))
	runner.check(not Items.in_battle(Items.Type.NONE))
	var w := Items.weights_for(3, 4, true)
	runner.check(w[Items.Type.BLUE_SHELL] == 0.0 and w[Items.Type.LIGHTNING] == 0.0 and w[Items.Type.GOLDEN_MUSHROOM] == 0.0 and w[Items.Type.TRIPLE_MUSHROOM] == 0.0)
	runner.check(w[Items.Type.STAR] > 0.0 and w[Items.Type.RED_SHELL] > 0.0, "the rest is still rolled")
	runner.check(Items.weights_for(3, 4, false)[Items.Type.LIGHTNING] > 0.0, "race rolls unchanged")
	var seen := {}
	for i in 400:
		seen[Items.roll(float(i) / 400.0, 4, 4, true)] = true
	for t in Items.BATTLE_EXCLUDED:
		runner.check(not seen.has(t), "never rolled in a battle: " + Items.name_of(t))
	runner.check(seen.has(Items.Type.STAR) and seen.has(Items.Type.SHELL) and seen.has(Items.Type.BANANA), "battle items roll")
	# the holder carries the flag through the roulette
	var h := ItemHolder.new(5)
	h.battle = true
	var rolled := {}
	for i in 60:
		h.pickup(4, 4)
		h.update(2.0)
		rolled[h.held] = true
		h.clear()
	for t in Items.BATTLE_EXCLUDED:
		runner.check(not rolled.has(t), "holder: " + Items.name_of(t))
	runner.check(rolled.size() >= 3, "holder rolls a spread: %s" % str(rolled.keys()))

func test_shells_ricochet_off_arena_walls_and_forts() -> void:
	var a = ArenaData.make(1)
	var p = ItemProjectile.make_shell(Vector3(a.half - 3.0, 0.6, 0), ArenaData.heading_for(Vector3(1, 0, 0)))
	runner.check(p.velocity.x > 0.0)
	for i in 30:
		p.step(DT, a)
	runner.check(p.velocity.x < 0.0 and p.position.x <= a.half - p.radius + 0.001 and p.bounces == 1, "bounced off the east wall: %s" % p.position)
	# straight at a fort from the open middle: 20 frames = 18 m, the fort face is 14 m away
	var q = ItemProjectile.make_shell(Vector3(0, 0.6, -22), ArenaData.heading_for(Vector3(-1, 0, 0)))
	for i in 20:
		q.step(DT, a)
	runner.check(q.velocity.x > 0.0 and q.position.x >= -14.0 - q.radius - 0.001 and q.bounces == 1, "bounced off the fort: %s" % q.position)
	# red shell: homes straight at its target with no road to follow (Big Donut: nothing in the way)
	var donut = ArenaData.make(0)
	var r = ItemProjectile.make_red_shell(Vector3(0, 0.6, 0), ArenaData.heading_for(Vector3(0, 0, -1)))
	r.target_pos = Vector3(20, 0, 20)
	var closest := INF
	for i in 120:
		r.step(DT, donut)
		closest = minf(closest, Vector2(r.position.x - 20.0, r.position.z - 20.0).length())
	runner.check(closest < 3.0, "homing in the arena: closest %.1f m" % closest)
	# a red shell with no target just flies on
	var s = ItemProjectile.make_red_shell(Vector3(0, 0.6, 0), ArenaData.heading_for(Vector3(0, 0, -1)))
	s.step(DT, a)
	runner.check(s.velocity.normalized().dot(Vector3(0, 0, -1)) > 0.999 and s.position.z < 0.0)
	# no walls on the rooftop: a shell flies straight off the edge and nothing crashes
	var open = ArenaData.make(2)
	var t = ItemProjectile.make_shell(Vector3(0, 0.6, -15), 0.0)
	for i in 240:
		t.step(DT, open)
	runner.check(t.bounces == 0 and t.alive and t.position.z < -open.half, "no walls on the rooftop: %s" % t.position)

func test_battle_ai_hunts_boxes_then_karts_and_avoids_obstacles() -> void:
	var a = ArenaData.make(1)
	var ai := BattleAi.new(a, 0.5)
	# goal choice
	var boxes := [Vector3(10, 0, 0), Vector3(-30, 0, 0)]
	var targets := [Vector3(0, 0, 20), Vector3(40, 0, 40)]
	runner.check(BattleAi.pick_goal(Vector3.ZERO, Items.Type.NONE, boxes, targets) == Vector3(10, 0, 0), "empty-handed: nearest box")
	runner.check(BattleAi.pick_goal(Vector3.ZERO, Items.Type.SHELL, boxes, targets) == Vector3(0, 0, 20), "armed: nearest kart")
	runner.check(BattleAi.pick_goal(Vector3.ZERO, Items.Type.NONE, boxes, targets, false) == Vector3(0, 0, 20), "a bomb kart ignores boxes")
	runner.check(BattleAi.pick_goal(Vector3.ZERO, Items.Type.NONE, [], targets) == Vector3(0, 0, 20), "no boxes left: chase")
	runner.check(BattleAi.pick_goal(Vector3.ZERO, Items.Type.SHELL, boxes, []) == null, "nobody to chase")
	# steering towards the goal
	ai.goal = Vector3(0, 0, -30)
	var d: Dictionary = ai.decide(DT, Vector3.ZERO, 0.0, 10.0)
	runner.check(d.throttle == 1.0 and absf(d.steer) < 0.01 and ai.avoiding == 0.0, "straight at a goal dead ahead: %s" % str(d))
	ai.goal = Vector3(-30, 0, 0)   # to the left of a kart facing -Z (heading 0)
	d = ai.decide(DT, Vector3.ZERO, 0.0, 10.0)
	runner.check(d.steer < -0.5, "steers left: %f" % d.steer)
	# obstacle avoidance: the fort straight ahead
	ai.goal = Vector3(-22, 0, -40)
	d = ai.decide(DT, Vector3(-22, 0, -8), 0.0, 10.0)
	runner.check(ai.avoiding != 0.0 and d.steer == ai.avoiding, "feelers found the fort: %s" % str(d))
	# the wall ahead on the left feeler only -> steer right
	var av: float = ai.avoid_steer(Vector3(-a.half + 6.0, 0, 0), ArenaData.heading_for(Vector3(-0.5, 0, -1).normalized()))
	runner.check(av > 0.0, "wall on the left: steer right (%f)" % av)
	runner.check(ai.avoid_steer(Vector3.ZERO, 0.0) == 0.0, "open middle: nothing to avoid")
	# stuck recovery
	var e := BattleAi.new(a, 0.5)
	e.goal = Vector3(0, 0, -30)
	var reversed := false
	for i in 120:
		var r: Dictionary = e.decide(DT, Vector3.ZERO, 0.0, 0.0)
		if r.brake == 1.0 and r.throttle == 0.0:
			reversed = true
	runner.check(reversed, "backs out when stuck")
	# item policy
	var u := BattleAi.new(a, 0.5)
	runner.check(not u.wants_use(0.1, Items.Type.NONE, 5.0, INF))
	runner.check(not u.wants_use(0.1, Items.Type.SHELL, 5.0, INF), "holds for the delay")
	runner.check(u.wants_use(0.5, Items.Type.SHELL, 5.0, INF), "shell at a rival ahead")
	runner.check(not u.wants_use(0.6, Items.Type.SHELL, INF, INF), "no shell into thin air")
	runner.check(u.wants_use(0.6, Items.Type.BANANA, INF, 5.0) and not u.wants_use(0.6, Items.Type.BANANA, INF, INF), "banana for a tailgater")
	runner.check(u.wants_use(0.6, Items.Type.STAR, INF, INF) and u.wants_use(0.6, Items.Type.BOO, INF, INF), "star / Boo right away")
	runner.check(u.wants_use(0.6, Items.Type.MUSHROOM, 40.0, INF) and not u.wants_use(0.6, Items.Type.MUSHROOM, 5.0, INF), "mushroom to close a gap")

func test_battle_ai_drives_the_arena_without_getting_stuck() -> void:
	# pure sim on Block Fort: the AI chases a goal across the arena using the kart physics and the
	# arena collision; it must reach the far corner without sitting still for long
	var a = ArenaData.make(1)
	var ai := BattleAi.new(a, 1.0)
	var m := KartPhysics.new()
	var pos: Vector3 = a.spawns[0].position
	var heading: float = a.spawns[0].heading
	var goal: Vector3 = a.spawns[3].position
	ai.goal = goal
	var t := 0.0
	var worst_still := 0.0
	var still := 0.0
	var reached := false
	while t < 40.0 and not reached:
		var d: Dictionary = ai.decide(DT, pos, heading, m.speed)
		heading += m.step(DT, d.throttle, d.brake, d.steer, d.drift)
		var fwd := Vector3(-sin(heading), 0, -cos(heading))
		pos += fwd * m.speed * DT
		var hit: Dictionary = a.collide_circle(pos, 1.0)
		if not hit.is_empty():
			pos = hit.position
			m.speed = minf(m.speed, maxf((fwd * m.speed).dot(fwd - hit.normal * fwd.dot(hit.normal)), 0.0))
		still = still + DT if absf(m.speed) < 1.5 else 0.0
		worst_still = maxf(worst_still, still)
		t += DT
		if Vector2(pos.x - goal.x, pos.z - goal.z).length() < 6.0:
			reached = true
	runner.check(reached, "reached the far corner in %.1f s (at %s)" % [t, pos])
	runner.check(worst_still < 3.0, "never parked for long: %.1f s" % worst_still)
	runner.check(not a.in_block(pos), "not inside a fort")

func test_balloons_node_shows_the_count_and_the_bomb() -> void:
	var g := Balloons.new(Color(0.2, 0.4, 1.0), 3)
	runner.check(g.count == 3 and g.visible_balloons() == 3 and not g.bomb)
	g.set_count(1)
	runner.check(g.visible_balloons() == 1)
	g.set_count(0)
	runner.check(g.visible_balloons() == 0 and not g._bomb.visible)
	g.set_bomb(true)
	runner.check(g.bomb and g._bomb.visible and g.visible_balloons() == 0)
	g.set_count(2)
	runner.check(g.visible_balloons() == 0, "no balloons on a bomb kart")
	g.set_bomb(false)
	runner.check(g.visible_balloons() == 2 and not g._bomb.visible)
	g.set_count(9)
	runner.check(g.count == 3, "clamped")
	g.free()

func test_kart_bump_signal_and_hud_battle_line() -> void:
	var heavy = Kart.new()
	heavy.apply_weight_class(2)
	var light = Kart.new()
	light.apply_weight_class(0)
	var got: Array = []
	heavy.bumped.connect(func(other, closing): got.append([other, closing]))
	heavy.model.speed = 25.0
	heavy._bump(light, Vector3(1, 0, 0), Vector3(-1, 0, 0))
	runner.check(got.size() == 1 and got[0][0] == light and got[0][1] > 20.0, "bumped signal carries the other kart and the closing speed: %s" % str(got))
	heavy.free()
	light.free()
	var hud = Hud.new()
	hud._ready()
	hud.update_battle("BALLOONS OOO", 12.5, 20.0, false, 0, Items.Type.SHELL, "2nd / 4", false, false, 0, 0.0, false, "BOMB KART!")
	runner.check(hud.lap_label.text == "BALLOONS OOO" and hud.time_label.text == "TIME 0:12.500" and hud.place_label.text == "2nd / 4")
	runner.check(hud.item_label.text == "[ GREEN SHELL ]" and hud.banner_label.text == "BOMB KART!" and hud.speed_label.text == "72 km/h")
	hud.free()
	var lib := SoundSynth.effect_library()
	runner.check(lib.has("pop") and SoundSynth.peak(lib["pop"]) > 0.1, "balloon pop sound")

func test_menu_battle_mode() -> void:
	runner.check(Menu.MODE_COUNT == 4 and Menu.MODE_BATTLE == 3)
	runner.check(Menu.next_mode(Menu.MODE_TT) == Menu.MODE_BATTLE and Menu.next_mode(Menu.MODE_BATTLE) == Menu.MODE_SINGLE, "G cycles through Battle back to a single race")
	var txt := Menu.mode_text(Menu.MODE_BATTLE, 3)
	runner.check("BATTLE" in txt and "4 karts" in txt and "3 balloons" in txt, txt)
	var m = _menu()
	m.mode = Menu.MODE_TT
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_BATTLE and m.mode_label.text == txt)
	runner.check(m.sub_label.text == "SELECT ARENA" and m.name_label.text == "Big Donut" and m.index_label.text == "< 1 / 3 >", "arena picker: %s" % m.name_label.text)
	runner.check(m.laps_label.text == "3" and m.difficulty_label.text == Menu.difficulty_text(m.difficulty) and m.engine_label.text == Menu.engine_text(m.engine_class))
	runner.check(m.preview.map_points.size() == 5, "square preview (closed outline)")
	m.move(1)
	runner.check(m.arena_selected == 1 and m.name_label.text == "Block Fort" and m.selected == 0, "Left/Right pick the arena, the track choice is untouched")
	m.move(-1)
	m.move(-1)
	runner.check(m.arena_selected == 2 and m.name_label.text == "Skyscraper", "wraps")
	m.toggle_mode()
	runner.check(m.mode == Menu.MODE_SINGLE and m.sub_label.text == "Select a track" and m.name_label.text == "Green Hills", "back to tracks")
	# the choice is remembered through Battle.active / Battle.arena
	var old_active: bool = Battle.active
	var old_arena: int = Battle.arena
	Battle.active = true
	Battle.arena = 2
	var m2 = _menu()
	m2.mode = Menu.MODE_BATTLE if Battle.active else Menu.MODE_SINGLE
	m2.arena_selected = Battle.arena
	m2._refresh()
	runner.check(m2.mode == Menu.MODE_BATTLE and m2.name_label.text == "Skyscraper", "menu starts on the remembered arena")
	Battle.active = old_active
	Battle.arena = old_arena
	_free_menu(m)
	_free_menu(m2)

func test_arena_node_builds_walls_blocks_and_lava() -> void:
	for i in ArenaData.arena_count():
		var data = ArenaData.make(i)
		var node = Arena.new(data)
		node._ready()
		var colliders := 0
		var names: Array = []
		var blocks := 0
		var pads := 0
		for c in node.get_children():
			names.append(c.name)
			if c is StaticBody3D and c.get_child_count() == 3:   # collider + fort + roof
				blocks += 1
			if c is MeshInstance3D and c.mesh is CylinderMesh:
				pads += 1
			if c is StaticBody3D:
				for cc in c.get_children():
					if cc is CollisionShape3D:
						colliders += 1
		runner.check(names.has("Floor"), "%s floor" % data.name)
		runner.check(names.has("Walls") == data.walled and names.has("WallMesh") == data.walled, "%s walls" % data.name)
		runner.check(blocks == data.blocks.size() and node.block_count == blocks, "%s forts: %d" % [data.name, blocks])
		runner.check(names.has("Lava") == (data.pit_radius > 0.0), "%s lava" % data.name)
		runner.check(pads == 4 and names.has("StartPad"), "%s pads: %d" % [data.name, pads])
		runner.check(node.wall_count == (4 if data.walled else 0), "%s wall sides" % data.name)
		runner.check(colliders == (4 if data.walled else 0) + data.blocks.size(), "%s colliders: %d" % [data.name, colliders])
		node.free()
