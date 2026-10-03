extends Node3D
## Owns everything item related for a race: item boxes, the kart's item holder,
## thrown/dropped projectiles (with their visuals) and hit resolution.

const Items := preload("res://scripts/items.gd")
const ItemHolder := preload("res://scripts/item_holder.gd")
const ItemProjectile := preload("res://scripts/item_projectile.gd")
const ItemBox := preload("res://scripts/item_box.gd")
const LightningBolt := preload("res://scripts/lightning_bolt.gd")
const BlueBlast := preload("res://scripts/blue_blast.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")

const MUSHROOM_BOOST_TIME := 1.5
const KART_RADIUS := 1.1
const STAR_HIT_RADIUS := 2.2
const BUNCH_GAP := 1.0   # metres between the bananas trailing a banana-bunch holder
const BOO_FLIGHT := 0.7  # seconds the Boo takes to reach its victim (and as long again to come back)
const BOO_HOVER := Vector3(0, 2.2, 0)   # where the Boo floats relative to a kart

signal kart_hit(kind: int, id: int)
signal lightning_struck(user: int, victims: Array)
## A Boo came back: victim is -1 and item NONE when nobody had anything to take.
signal item_stolen(thief: int, victim: int, item: int)

var track
var karts: Array = []     # index in this array == kart_id; karts[0] is the player
var holders: Array = []   # one ItemHolder per kart
var kart               # the player kart (karts[0])
var holder             # the player's holder (holders[0])
var boxes: Array = []
var projectiles: Array = []
var nodes := {}   # projectile -> Node3D
var orbits := {}   # kart id -> Node3D holding the orbiting triple-shell visuals
var trails := {}   # kart id -> [item kind, Node3D] for the banana(s) / shell / fake box dangling behind the kart
var bolts: Array = []   # live lightning bolt visuals
var blasts: Array = []   # live blue shell explosion visuals
var boos: Array = []   # live Boo flights: {thief, victim, t, item, charges, node}
var time := 0.0
## Battle mode: places per kart (1 = best) used for the item roll instead of race progress.
var ranks_override: Array = []

## `course_items` false (time trials) leaves out the item boxes and the pre-placed hazards.
## `battle` true rolls only the Mario Kart 64 battle items.
func setup(track_data, all_karts, seed_value := 0, course_items := true, battle := false) -> void:
	track = track_data
	karts = all_karts if all_karts is Array else [all_karts]
	kart = karts[0]
	for i in karts.size():
		var h := ItemHolder.new(seed_value + i if seed_value != 0 else 0)
		h.battle = battle
		holders.append(h)
	holder = holders[0]
	if not course_items:
		return
	for p in track.item_box_positions:
		var b := ItemBox.new()
		b.position = p
		add_child(b)
		boxes.append(b)
	for p in track.hazard_positions:
		_add_projectile(ItemProjectile.make_banana(p + Vector3(0, 0.3, 0)))

## Distances (ahead, behind) from racer i to the nearest rival roughly in its lane.
## positions/headings are per racer. INF when nobody qualifies.
static func rival_gaps(i: int, positions: Array, headings: Array) -> Vector2:
	var ahead := INF
	var behind := INF
	var h: float = headings[i]
	var fwd := Vector3(-sin(h), 0, -cos(h))
	var right := Vector3(-fwd.z, 0, fwd.x)
	for j in positions.size():
		if j == i:
			continue
		var d: Vector3 = positions[j] - positions[i]
		var f := d.dot(fwd)
		var l := absf(d.dot(right))
		if f > 0.0 and l < 6.0:
			ahead = minf(ahead, f)
		elif f < 0.0 and l < 4.0:
			behind = minf(behind, -f)
	return Vector2(ahead, behind)

func use_item(id := 0) -> int:
	var k = karts[id]
	if k.model.is_spinning():
		return Items.Type.NONE
	var t: int = holders[id].use()
	var pos: Vector3 = k.global_position
	var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
	match t:
		Items.Type.MUSHROOM, Items.Type.TRIPLE_MUSHROOM, Items.Type.GOLDEN_MUSHROOM:
			k.model.apply_boost(MUSHROOM_BOOST_TIME, 2)
		Items.Type.BANANA, Items.Type.BANANA_BUNCH:
			_add_projectile(ItemProjectile.make_banana(pos - fwd * 2.4 + Vector3(0, 0.3, 0), id))
		Items.Type.FAKE_ITEM_BOX:
			_add_projectile(ItemProjectile.make_fake_box(pos - fwd * 2.6, id))
		Items.Type.SHELL, Items.Type.TRIPLE_SHELL:
			_add_projectile(ItemProjectile.make_shell(pos + fwd * 2.4 + Vector3(0, 0.6, 0), k.heading, id))
		Items.Type.RED_SHELL:
			_add_projectile(ItemProjectile.make_red_shell(pos + fwd * 2.4 + Vector3(0, 0.6, 0), k.heading, id))
		Items.Type.BLUE_SHELL:
			var lead := ItemProjectile.pick_leader(_progresses(), id)
			_add_projectile(ItemProjectile.make_blue_shell(pos + fwd * 2.4 + Vector3(0, ItemProjectile.BLUE_HEIGHT, 0), k.heading, id, lead))
		Items.Type.STAR:
			k.model.apply_star()
		Items.Type.LIGHTNING:
			_strike(id)
		Items.Type.BOO:
			_send_boo(id)
	return t

func _no_finish_times() -> Array:
	var out: Array = []
	out.resize(karts.size())
	out.fill(-1.0)
	return out

## Race progress of every kart (laps, track sample, fraction), as used for the standings.
func _progresses() -> Array:
	var out: Array = []
	for k in karts:
		var idx: int = track.nearest_index(k.global_position)
		var lap: int = k.tracker.lap if k.get("tracker") != null else 0
		var frac: float = (k.global_position - track.points[idx]).dot(track.tangents[idx]) / track.spacing
		out.append(RaceRanking.progress(lap, idx, track.count, frac))
	return out

## Place of kart `id` for the item roll: the battle standings when set, else the race standings.
func _rank(id: int) -> int:
	if not ranks_override.is_empty():
		return ranks_override[id]
	return RaceRanking.rank_of(id, _progresses(), _no_finish_times())

## 

## Blue shell impact: spins out every kart (except stars) within the blast radius.
func _explode(p) -> void:
	for j in karts.size():
		if karts[j].global_position.distance_to(p.position) <= ItemProjectile.BLUE_BLAST_RADIUS and karts[j].model.spin_out():
			kart_hit.emit(Items.Type.BLUE_SHELL, j)
	var blast := BlueBlast.new()
	add_child(blast)
	blast.build(p.position, ItemProjectile.BLUE_BLAST_RADIUS)
	blasts.append(blast)

## Boo (Mario Kart 64): the user turns into a see-through, untouchable ghost while a Boo flies
## off to a rival that holds an item, takes it and brings it back. Victim: a random rival with
## something in its slot (drawn from the user's own rng so races stay seeded); none → the Boo
## just hovers over the user and vanishes empty-handed.
func _send_boo(user: int) -> void:
	karts[user].model.apply_ghost()
	var candidates: Array = []
	for j in karts.size():
		if j != user and holders[j].held != Items.Type.NONE and not holders[j].is_rolling() and not karts[j].model.is_ghost():
			candidates.append(j)
	var victim := -1
	if not candidates.is_empty():
		victim = candidates[holders[user].rng.randi_range(0, candidates.size() - 1)]
		holders[user].locked = true
	var node := _make_boo_node()
	add_child(node)
	node.position = karts[user].global_position + BOO_HOVER
	boos.append({"thief": user, "victim": victim, "t": 0.0, "item": Items.Type.NONE, "charges": 0, "node": node})

## Advance every Boo flight: out to the victim (grab its item on arrival), back to the thief.
func _update_boos(delta: float) -> void:
	for b in boos.duplicate():
		var was: float = b.t
		b.t += delta
		var node: Node3D = b.node
		var home: Vector3 = karts[b.thief].global_position + BOO_HOVER
		var bob := Vector3(0, 0.25 * sin(time * 5.0), 0)
		if b.victim < 0:
			node.position = home + bob
			node.scale = Vector3.ONE * clampf(2.0 - b.t / BOO_FLIGHT, 0.0, 1.0)
			if b.t >= BOO_FLIGHT * 2.0:
				_finish_boo(b)
			continue
		var there: Vector3 = karts[b.victim].global_position + BOO_HOVER
		if was < BOO_FLIGHT and b.t >= BOO_FLIGHT:
			var got: Array = holders[b.victim].steal()
			b.item = got[0]
			b.charges = got[1]
		if b.t < BOO_FLIGHT:
			node.position = home.lerp(there, b.t / BOO_FLIGHT) + bob
		elif b.t < BOO_FLIGHT * 2.0:
			node.position = there.lerp(home, b.t / BOO_FLIGHT - 1.0) + bob
		else:
			_finish_boo(b)

func _finish_boo(b: Dictionary) -> void:
	boos.erase(b)
	b.node.queue_free()
	if b.victim < 0:
		item_stolen.emit(b.thief, -1, Items.Type.NONE)
		return
	holders[b.thief].receive(b.item, b.charges)
	item_stolen.emit(b.thief, b.victim, b.item)

## Lightning: every rival that is not a star or ghost kart shrinks, spins out and drops its item.
func _strike(user: int) -> void:
	var victims: Array = []
	for j in karts.size():
		if j == user or karts[j].model.is_star() or karts[j].model.is_ghost():
			continue
		karts[j].model.apply_shrink()
		karts[j].model.spin_out()
		holders[j].clear()
		victims.append(j)
		kart_hit.emit(Items.Type.LIGHTNING, j)
		var bolt := LightningBolt.new()
		add_child(bolt)
		bolt.build(karts[j].global_position)
		bolts.append(bolt)
	lightning_struck.emit(user, victims)

func _make_shell_mesh(kind: int, radius: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.45
	mi.mesh = sm
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/shell.gdshader") as Shader
	if kind == Items.Type.RED_SHELL:
		mat.set_shader_parameter("shell_color", Color(0.95, 0.1, 0.1))
		mat.set_shader_parameter("rim_color", Color(1.0, 0.9, 0.85))
	elif kind == Items.Type.BLUE_SHELL:
		mat.set_shader_parameter("shell_color", Color(0.1, 0.3, 1.0))
		mat.set_shader_parameter("rim_color", Color(0.85, 0.95, 1.0))
	mi.material_override = mat
	if kind == Items.Type.BLUE_SHELL:
		for i in 8:   # spikes
			var spike := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = radius * 0.22
			cm.height = radius * 0.7
			spike.mesh = cm
			spike.material_override = mat
			var a := TAU * i / 8.0
			var dir := Vector3(cos(a), 0.7, sin(a)).normalized()
			spike.position = dir * radius * 0.85
			spike.basis = Basis(Vector3.UP.cross(dir).normalized(), Vector3.UP.angle_to(dir))
			mi.add_child(spike)
	return mi

## Shells orbiting a kart while it holds triple shells: one per remaining charge.
func _update_orbits() -> void:
	for id in karts.size():
		var want: int = holders[id].charges if holders[id].held == Items.Type.TRIPLE_SHELL else 0
		var orbit: Node3D = orbits.get(id)
		if want == 0:
			if orbit != null:
				orbit.queue_free()
				orbits.erase(id)
			continue
		if orbit == null:
			orbit = Node3D.new()
			add_child(orbit)
			orbits[id] = orbit
		while orbit.get_child_count() > want:
			var last := orbit.get_child(orbit.get_child_count() - 1)
			orbit.remove_child(last)
			last.queue_free()
		while orbit.get_child_count() < want:
			orbit.add_child(_make_shell_mesh(Items.Type.SHELL, 0.3))
		var n := orbit.get_child_count()
		for c in n:
			var a := time * 4.0 + TAU * c / n
			orbit.get_child(c).position = Vector3(cos(a), 0.0, sin(a)) * 1.5
		orbit.position = karts[id].global_position + Vector3(0, 0.9, 0)

func _make_banana_node() -> Node3D:
	var n := Node3D.new()
	for k in 2:
		var mi := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = 0.16
		cm.height = 0.9
		mi.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.9, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.8, 0.0)
		mat.emission_energy_multiplier = 0.4
		mi.material_override = mat
		mi.rotation_degrees = Vector3(0, 0, 70 + 40 * k)
		mi.position = Vector3(0.12 * k - 0.06, 0.25, 0)
		n.add_child(mi)
	return n

## A little white ghost: round body, two black eyes and a dark grin, slightly see-through.
func _make_boo_node() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	body.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.6, 0.8)
	mat.emission_energy_multiplier = 0.5
	body.material_override = mat
	n.add_child(body)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.08)
	for x in [-0.2, 0.2]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.1
		em.height = 0.2
		eye.mesh = em
		eye.material_override = dark
		eye.position = Vector3(x, 0.12, -0.46)
		n.add_child(eye)
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.3, 0.08, 0.1)
	mouth.mesh = mm
	mouth.material_override = dark
	mouth.position = Vector3(0, -0.15, -0.5)
	n.add_child(mouth)
	return n

## A floating box that looks like a real item box (upside-down glyph, faint red tint) —
## the Mario Kart 64 fake item. scale < 1 shrinks it for the dangling-behind-the-kart copy.
func _make_fake_box_node(scale := 1.0) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(1.4, 1.4, 1.4) * scale
	mi.mesh = m
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/item_box.gdshader") as Shader
	mat.set_shader_parameter("flip", 1.0)
	mat.set_shader_parameter("tint", Vector3(1.0, 0.7, 0.7))
	mi.material_override = mat
	mi.position.y = 1.4 * scale
	n.add_child(mi)
	return n

## A single banana / green shell / red shell / fake item box dangles behind the kart that
## holds it (Mario Kart 64 item dangling); a banana bunch trails one banana per charge.
func _update_trails() -> void:
	for id in karts.size():
		var kind: int = holders[id].held
		if not Items.is_dropped(kind) and kind != Items.Type.SHELL and kind != Items.Type.RED_SHELL and kind != Items.Type.BANANA_BUNCH:
			kind = Items.Type.NONE
		var entry = trails.get(id)
		if entry != null and entry[0] != kind:
			entry[1].queue_free()
			trails.erase(id)
			entry = null
		if kind == Items.Type.NONE:
			continue
		if entry == null:
			var node: Node3D
			if kind == Items.Type.BANANA:
				node = _make_banana_node()
			elif kind == Items.Type.FAKE_ITEM_BOX:
				node = _make_fake_box_node(0.6)
			elif kind == Items.Type.BANANA_BUNCH:
				node = Node3D.new()
			else:
				node = Node3D.new()
				node.add_child(_make_shell_mesh(kind, 0.4))
			add_child(node)
			entry = [kind, node]
			trails[id] = entry
		var k = karts[id]
		var fwd := Vector3(-sin(k.heading), 0, -cos(k.heading))
		var node: Node3D = entry[1]
		node.position = k.global_position - fwd * 2.2 + Vector3(0, 0.5, 0)
		if kind == Items.Type.BANANA_BUNCH:
			var want: int = holders[id].charges
			while node.get_child_count() > want:
				var last := node.get_child(node.get_child_count() - 1)
				node.remove_child(last)
				last.queue_free()
			while node.get_child_count() < want:
				node.add_child(_make_banana_node())
			for c in node.get_child_count():
				node.get_child(c).position = -fwd * (BUNCH_GAP * c)
		elif kind != Items.Type.BANANA:
			node.rotation.y = time * 12.0 if kind != Items.Type.FAKE_ITEM_BOX else time * 1.6

func _add_projectile(p) -> void:
	projectiles.append(p)
	var n := Node3D.new()
	if p.is_shell():
		n.add_child(_make_shell_mesh(p.kind, 0.55))
	elif p.kind == Items.Type.FAKE_ITEM_BOX:
		n = _make_fake_box_node()
	else:
		n = _make_banana_node()
	n.position = p.position
	add_child(n)
	nodes[p] = n

func _remove_projectile(p) -> void:
	projectiles.erase(p)
	if nodes.has(p):
		nodes[p].queue_free()
		nodes.erase(p)

func _physics_process(delta: float) -> void:
	time += delta
	for b in blasts.duplicate():
		if not b.tick(delta):
			blasts.erase(b)
			b.queue_free()
	for b in bolts.duplicate():
		if not b.tick(delta):
			bolts.erase(b)
			b.queue_free()
	var positions: Array = []
	var headings: Array = []
	for k in karts:
		positions.append(k.global_position)
		headings.append(k.heading)
	for id in karts.size():
		holders[id].update(delta)
	_update_boos(delta)
	_update_orbits()
	_update_trails()
	for b in boxes:
		b.tick(delta)
		for id in karts.size():
			if b.try_take(positions[id]):
				holders[id].pickup(_rank(id), karts.size())
	if Input.is_action_just_pressed("use_item") and not karts[0].frozen:
		use_item(0)
	for id in range(1, karts.size()):
		var drv = karts[id].driver
		if drv != null:
			var gaps := rival_gaps(id, positions, headings)
			if drv.wants_use(delta, holders[id].held, gaps.x, gaps.y):
				use_item(id)
	var valid: Array = []
	for k in karts:
		valid.append(not k.model.is_star() and not k.model.is_ghost())
	# a star kart bowls over anyone it touches
	for id in karts.size():
		if karts[id].model.is_star():
			for j in karts.size():
				if j != id and positions[id].distance_to(positions[j]) <= STAR_HIT_RADIUS and karts[j].model.spin_out():
					kart_hit.emit(Items.Type.STAR, j)
	for p in projectiles.duplicate():
		if p.kind == Items.Type.RED_SHELL:
			var dir: Vector3 = p.velocity.normalized()
			var ti: int = ItemProjectile.pick_target(p.position, dir, positions, p.owner_id, valid)
			p.target_pos = positions[ti] if ti >= 0 else null
		if p.kind == Items.Type.BLUE_SHELL:
			p.target_pos = positions[p.target_id] if p.target_id >= 0 else null
		p.step(delta, track)
		for id in karts.size():
			if not p.hits(positions[id], KART_RADIUS, id):
				continue
			if p.kind == Items.Type.BLUE_SHELL:   # explodes on the leader even if a star shrugs it off
				p.alive = false
				_explode(p)
				break
			if karts[id].model.spin_out():
				p.alive = false
				kart_hit.emit(p.kind, id)
				break
		if not p.alive:
			_remove_projectile(p)
		else:
			var n: Node3D = nodes[p]
			n.position = p.position
			n.rotation.y += (12.0 if p.is_shell() else (1.6 if p.kind == Items.Type.FAKE_ITEM_BOX else 0.0)) * delta
