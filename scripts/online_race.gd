extends RefCounted
## Online race rules shared by every peer, and the packets they swap over the WebRTC mesh (Net).
## Every peer simulates only its own kart and sends its pose ~30 times a second (unreliable); the
## other karts are puppets that replay those poses a little in the past (Puppet), so they glide
## smoothly between packets. The start is agreed with two reliable messages: each peer says READY
## once its race scene is up, and the host (lowest id) answers GO when all are ready; everyone runs
## the 3-2-1 countdown from there.

const TrackLibrary := preload("res://scripts/track_library.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const RaceResults := preload("res://scripts/race_results.gd")

## Set by whoever starts an online race (menu / smoke test) before switching to the race scene.
static var active := false

const LAPS := 3
const ENGINE_CLASS := 2   # 150cc for everyone (speeds must match on every peer)
const SEND_INTERVAL := 1.0 / 30.0
const READY_RESEND := 0.5
## The host starts without peers that are still not ready after this long.
const READY_TIMEOUT := 15.0
## Karts by grid slot: red, blue, green, yellow.
const COLORS := [Color(0.9, 0.1, 0.1), Color(0.15, 0.3, 0.95), Color(0.15, 0.75, 0.25), Color(0.95, 0.85, 0.15)]

enum Packet { STATE = 1, READY = 2, GO = 3, FINISH = 4, ITEM = 5, HIT = 6 }

## How long a "X left the race" notice stays up.
const NOTICE_TIME := 4.0

## Flags in a state packet.
const F_VISIBLE := 1
const F_ON_FLOOR := 2
const F_DRIFTING := 4
const F_BOOSTING := 8
const F_DRIFT_RIGHT := 16
const F_STAR := 32
const F_GHOST := 64

## The course everyone races: the room's course by name, else one picked by the room's seed.
static func course_index(info: Dictionary) -> int:
	var want := str(info.get("course", ""))
	for i in TrackLibrary.count():
		if want != "" and TrackLibrary.info(i).name == want:
			return i
	return posmod(int(info.get("seed", 0)), TrackLibrary.count())

## Peer ids in grid order (the same on every peer): lowest id on pole.
static func grid_order(ids: Array) -> Array:
	var out := ids.duplicate()
	out.sort()
	return out

static func pack_ready() -> PackedByteArray:
	return PackedByteArray([Packet.READY])

static func pack_go() -> PackedByteArray:
	return PackedByteArray([Packet.GO])

## Sent (reliable) once when a player crosses the line: their race time as their own machine
## measured it, so every peer ranks the finishers by the same times.
static func pack_finish(race_time: float) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(Packet.FINISH)
	b.put_double(race_time)
	return b.data_array

## The race time in a finish packet, or -1 for a short/garbled one.
static func unpack_finish(data: PackedByteArray) -> float:
	if data.size() < 9 or data[0] != Packet.FINISH:
		return -1.0
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.seek(1)
	return maxf(b.get_double(), 0.0)

## A player's name as the results board shows it: the board reads a racer's name as one upper-case
## word, so spaces and other symbols become "_" (and a leading digit gets a "P").
static func board_name(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		var c := ch.unicode_at(0)
		out += ch if (c >= 65 and c <= 90) or (c >= 48 and c <= 57) or c == 95 else "_"
	if out == "" or (out.unicode_at(0) >= 48 and out.unicode_at(0) <= 57):
		out = "P" + out
	return out

## The line under the online results: how many are still racing, and Enter for the menu.
static func results_footer(still_racing: int) -> String:
	if still_racing > 0:
		return "WAITING FOR %d  Press ENTER for the menu" % still_racing
	return "Press ENTER for the menu"

## The online results board (racer 0 is this player): finishers by the times they reported, the
## rest by progress; a player who left before finishing shows LEFT instead of a time.
static func results_text(names: Array, progresses: Array, finish_times: Array, left: Array) -> String:
	var board: Array = []
	var racing := 0
	for i in names.size():
		board.append(board_name(names[i]))
		if finish_times[i] < 0.0 and not left[i]:
			racing += 1
	var rows := RaceResults.rows(board, progresses, finish_times)
	for row in rows:
		if left[row.id] and not row.finished:
			row.time = "LEFT"
			row.points = 0
	return RaceResults.table_text(rows, 0, results_footer(racing))

## A kart's pose: s = {t (ms), pos, heading, speed, yaw (body), pitch, scale, flags, drift_level, weight,
## held (item in the slot), charges}.
static func pack_state(s: Dictionary) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(Packet.STATE)
	b.put_u32(int(s.t))
	var p: Vector3 = s.pos
	b.put_float(p.x)
	b.put_float(p.y)
	b.put_float(p.z)
	b.put_float(s.heading)
	b.put_float(s.speed)
	b.put_float(s.yaw)
	b.put_float(s.pitch)
	b.put_float(s.scale)
	b.put_u8(int(s.flags))
	b.put_u8(int(s.drift_level))
	b.put_u8(int(s.weight))
	b.put_u8(int(s.get("held", 0)))
	b.put_u8(int(s.get("charges", 0)))
	return b.data_array

## The packet's type, or 0 for an empty packet.
static func kind(data: PackedByteArray) -> int:
	return data[0] if data.size() > 0 else 0

## Reverses pack_state; {} for a short/garbled packet.
static func unpack_state(data: PackedByteArray) -> Dictionary:
	if data.size() < 42 or data[0] != Packet.STATE:
		return {}
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.seek(1)
	var s := {}
	s.t = b.get_u32()
	s.pos = Vector3(b.get_float(), b.get_float(), b.get_float())
	s.heading = b.get_float()
	s.speed = b.get_float()
	s.yaw = b.get_float()
	s.pitch = b.get_float()
	s.scale = b.get_float()
	s.flags = b.get_u8()
	s.drift_level = b.get_u8()
	s.weight = b.get_u8()
	s.held = b.get_u8()
	s.charges = b.get_u8()
	return s

## Sent (reliable) when a player fires / drops an item: what it was, which way, the kart's pose at
## that moment, the target (blue shell leader / Boo victim as a peer id, 0 = none) and the id that
## names the thrown item on every peer (0 = nothing thrown).
## u = {item, flip, pos, heading, speed, target, net_id}.
static func pack_item(u: Dictionary) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(Packet.ITEM)
	b.put_u8(int(u.item))
	b.put_u8(1 if u.flip else 0)
	b.put_u32(int(u.target))
	b.put_32(int(u.net_id))
	var p: Vector3 = u.pos
	b.put_float(p.x)
	b.put_float(p.y)
	b.put_float(p.z)
	b.put_float(u.heading)
	b.put_float(u.speed)
	return b.data_array

## Reverses pack_item; {} for a short/garbled packet.
static func unpack_item(data: PackedByteArray) -> Dictionary:
	if data.size() < 31 or data[0] != Packet.ITEM:
		return {}
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.seek(1)
	var u := {}
	u.item = b.get_u8()
	u.flip = b.get_u8() != 0
	u.target = b.get_u32()
	u.net_id = b.get_32()
	u.pos = Vector3(b.get_float(), b.get_float(), b.get_float())
	u.heading = b.get_float()
	u.speed = b.get_float()
	return u

## Sent (reliable) by a player whose kart was hit by thrown item net_id, so every peer removes it.
static func pack_hit(net_id: int) -> PackedByteArray:
	var b := StreamPeerBuffer.new()
	b.put_u8(Packet.HIT)
	b.put_32(net_id)
	return b.data_array

## The item id in a hit packet, or 0 for a short/garbled one.
static func unpack_hit(data: PackedByteArray) -> int:
	if data.size() < 5 or data[0] != Packet.HIT:
		return 0
	var b := StreamPeerBuffer.new()
	b.data_array = data
	b.seek(1)
	return b.get_32()

## A name floating over a kart (billboard, always readable, shrinks with distance like the kart).
static func make_tag(text: String, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	UiStyle.style_label3d(l, 56, Color.WHITE, UiStyle.board_rim(color))
	l.pixel_size = 0.008
	l.position = Vector3(0, 2.0, 0)
	l.no_depth_test = true
	return l

## Replays a remote kart's poses INTERP_DELAY behind the newest one, blending between the two
## that bracket the playback time.
class Puppet:
	const INTERP_DELAY := 100.0   # ms
	const SNAP := 300.0           # ms off the target: jump instead of easing
	const KEEP := 20
	var snaps: Array = []   # oldest first
	var clock := -1.0       # playback time in the sender's ms
	var left := false       # the player left the race

	func push(s: Dictionary) -> void:
		if not snaps.is_empty() and int(s.t) <= int(snaps[-1].t):
			return   # late or duplicate packet
		snaps.append(s)
		if snaps.size() > KEEP:
			snaps.pop_front()

	## Advances the playback clock by delta seconds and returns the pose to show ({} until one arrives).
	func sample(delta: float) -> Dictionary:
		if snaps.is_empty():
			return {}
		var target: float = float(snaps[-1].t) - INTERP_DELAY
		if clock < 0.0 or absf(clock - target) > SNAP:
			clock = target
		else:
			clock += delta * 1000.0
			clock += (target - clock) * 0.05   # drift toward the target so jitter can't build up
		if clock <= float(snaps[0].t):
			return snaps[0]
		for i in range(snaps.size() - 1, 0, -1):
			var a: Dictionary = snaps[i - 1]
			var b: Dictionary = snaps[i]
			if clock >= float(a.t):
				if clock >= float(b.t):
					return b
				var f: float = (clock - float(a.t)) / maxf(float(b.t) - float(a.t), 1.0)
				var s := b.duplicate()
				s.pos = (a.pos as Vector3).lerp(b.pos, f)
				s.heading = lerp_angle(a.heading, b.heading, f)
				s.speed = lerpf(a.speed, b.speed, f)
				s.yaw = lerp_angle(a.yaw, b.yaw, f)
				s.pitch = lerpf(a.pitch, b.pitch, f)
				s.scale = lerpf(a.scale, b.scale, f)
				return s
		return snaps[-1]
