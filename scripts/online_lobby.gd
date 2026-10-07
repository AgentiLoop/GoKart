extends Control
## ONLINE screen (O on the select screen): enter your name (saved in user://online.cfg), then
## Quick Match (any open public room) or Create / Join a private room by code. gokart.games only
## matches players and relays the WebRTC handshake (Net); the lobby lists the room's players with
## the host marked and the auto-start countdown, and the host can start early. Once every peer is
## connected directly (Net.mesh_ready) the race scene loads in online mode (OnlineRace.active).
## Esc leaves the room / goes back to the menu.

const OnlineRace := preload("res://scripts/online_race.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const RACE_SCENE := "res://scenes/main.tscn"
const MENU_SCENE := "res://scenes/menu.tscn"
const CONFIG := "user://online.cfg"
const CODE_MAX := 8

enum Screen { SETUP, WAITING, LOBBY, CONNECTING }

var screen := Screen.SETUP
var font: Font
var stage: Control
var title: Label
var status: Label
var setup_box: VBoxContainer
var name_edit: LineEdit
var code_edit: LineEdit
var quick_button: Button
var lobby_box: VBoxContainer
var room_label: Label
var players_label: Label
var countdown_label: Label
var start_button: Button
var leave_button: Button
var net: Node

## Room code typed by the player: upper case letters and digits only, at most CODE_MAX. Pure.
static func clean_code(s: String) -> String:
	var out := ""
	for ch in s.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			out += ch
	return out.left(CODE_MAX)

## A fresh private room code (no 0/O/1/I, so it reads aloud cleanly).
static func random_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var out := ""
	for i in 5:
		out += CHARS[randi() % CHARS.length()]
	return out

## The lobby's player list, one line each in join order: "Name", tagged (host) / (you). Pure.
static func player_lines(players: Array, host: int, me: int) -> Array:
	var out: Array = []
	for p in players:
		var tags: Array = []
		if int(p.id) == host:
			tags.append("host")
		if int(p.id) == me:
			tags.append("you")
		out.append(str(p.name) + ("   (%s)" % ", ".join(tags) if not tags.is_empty() else ""))
	return out

## The line under the player list. Pure.
static func countdown_text(countdown: int, count: int) -> String:
	if count < 2:
		return "Waiting for another player to join..."
	if countdown >= 0:
		return "Race starts in %d s  (%d / 4 players)" % [countdown, count]
	return "%d / 4 players  -  waiting for the host to start" % count

static func load_name() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG) == OK:
		return str(cfg.get_value("online", "name", ""))
	return ""

static func save_name(n: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG)
	cfg.set_value("online", "name", n)
	cfg.save(CONFIG)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	net = get_node_or_null("/root/Net")
	font = UiStyle.make_font()
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.05, 0.16)
	add_child(bg)
	stage = Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -640.0
	stage.offset_top = -360.0
	stage.offset_right = 640.0
	stage.offset_bottom = 360.0
	add_child(stage)
	var panel := Panel.new()
	panel.position = Vector2(340, 110)
	panel.size = Vector2(600, 500)
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style())
	stage.add_child(panel)
	title = Label.new()
	title.position = Vector2(340, 40)
	title.size = Vector2(600, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "ONLINE RACE"
	UiStyle.style_sign(title, font, 44)
	stage.add_child(title)
	# setup: name, quick match, create / join by code
	setup_box = _column()
	setup_box.add_child(_caption("YOUR NAME"))
	name_edit = _edit(load_name(), "Player", OS.get_environment("USER").left(16))
	name_edit.max_length = 16
	name_edit.text_submitted.connect(func(_t): _quick_match())
	setup_box.add_child(name_edit)
	setup_box.add_child(_gap())
	quick_button = _button("QUICK MATCH", _quick_match)
	setup_box.add_child(quick_button)
	setup_box.add_child(_button("CREATE PRIVATE ROOM", _create_room))
	setup_box.add_child(_gap())
	setup_box.add_child(_caption("ROOM CODE"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	code_edit = _edit("", "ABCDE", "")
	code_edit.max_length = CODE_MAX
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.text_changed.connect(func(t):
		var c := clean_code(t)
		if c != t:
			code_edit.text = c
			code_edit.caret_column = c.length())
	code_edit.text_submitted.connect(func(_t): _join_room())
	row.add_child(code_edit)
	var join := _button("JOIN", _join_room)
	join.custom_minimum_size.x = 140
	row.add_child(join)
	setup_box.add_child(row)
	setup_box.add_child(_gap())
	setup_box.add_child(_button("BACK", _back))
	# lobby: room code, players, countdown, start / leave
	lobby_box = _column()
	room_label = _text(30, UiStyle.GOLD)
	lobby_box.add_child(room_label)
	lobby_box.add_child(_caption("PLAYERS"))
	players_label = _text(24, UiStyle.CREAM)
	players_label.custom_minimum_size.y = 150
	lobby_box.add_child(players_label)
	countdown_label = _text(18, UiStyle.GREY)
	lobby_box.add_child(countdown_label)
	lobby_box.add_child(_gap())
	start_button = _button("START NOW", func(): if net: net.start_now())
	lobby_box.add_child(start_button)
	leave_button = _button("LEAVE", _back)
	lobby_box.add_child(leave_button)
	status = Label.new()
	status.position = Vector2(340, 624)
	status.size = Vector2(600, 60)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiStyle.style_label(status, font, 16, UiStyle.GREY)
	stage.add_child(status)
	if net != null:
		net.room_updated.connect(_on_room)
		net.match_started.connect(_on_match_started)
		net.mesh_ready.connect(_on_mesh_ready)
		net.failed.connect(_on_failed)
	status.text = "Players are matched on gokart.games; the race itself runs directly between your computers."
	_show(Screen.SETUP)

func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.position = Vector2(390, 130)
	v.size = Vector2(500, 460)
	v.add_theme_constant_override("separation", 8)
	stage.add_child(v)
	return v

func _caption(t: String) -> Label:
	var l := _text(15, UiStyle.GOLD_DIM)
	l.text = t
	return l

func _text(size: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.style_label(l, font, size, col)
	return l

func _gap() -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = 10
	return c

func _edit(text: String, placeholder: String, fallback: String) -> LineEdit:
	var e := LineEdit.new()
	e.text = text if text != "" else fallback
	e.placeholder_text = placeholder
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.custom_minimum_size.y = 44
	e.add_theme_font_override("font", font)
	e.add_theme_font_size_override("font_size", 22)
	return e

func _button(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size.y = 44
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_stylebox_override("normal", UiStyle.panel_style(Color(1, 1, 1, 0.06), Color(1, 1, 1, 0.3), 10))
	b.add_theme_stylebox_override("hover", UiStyle.panel_style(Color(1, 1, 1, 0.12), UiStyle.GOLD_DIM, 10))
	b.add_theme_stylebox_override("focus", UiStyle.lit_style(10))
	b.add_theme_stylebox_override("pressed", UiStyle.lit_style(10))
	b.add_theme_color_override("font_focus_color", UiStyle.GOLD)
	b.pressed.connect(cb)
	return b

func _show(s: Screen) -> void:
	screen = s
	setup_box.visible = s == Screen.SETUP
	lobby_box.visible = s != Screen.SETUP
	start_button.visible = false
	match s:
		Screen.SETUP:
			name_edit.grab_focus.call_deferred()
		Screen.WAITING:
			room_label.text = "Contacting gokart.games..."
			players_label.text = ""
			countdown_label.text = ""
			leave_button.grab_focus.call_deferred()
		Screen.CONNECTING:
			countdown_label.text = "Connecting directly to the other players..."
			leave_button.grab_focus.call_deferred()

func _player_name() -> String:
	var n: String = load("res://scripts/net.gd").clean_name(name_edit.text)
	name_edit.text = n
	save_name(n)
	return n

func _quick_match() -> void:
	if net == null:
		return
	var n := _player_name()
	_show(Screen.WAITING)
	net.quick_match(n)

func _create_room() -> void:
	if net == null:
		return
	var n := _player_name()
	_show(Screen.WAITING)
	# a private room races the course highlighted on the select screen
	net.join_room(random_code(), n, true, TrackLibrary.info(TrackLibrary.selected).name)

func _join_room() -> void:
	if net == null:
		return
	var code := clean_code(code_edit.text)
	if code == "":
		status.text = "Type the room code your friend sees in their lobby."
		code_edit.grab_focus()
		return
	var n := _player_name()
	_show(Screen.WAITING)
	net.join_room(code, n)

func _on_room(code: String, players: Array, host: int, countdown: int) -> void:
	if screen != Screen.WAITING and screen != Screen.LOBBY:
		return
	var first := screen != Screen.LOBBY
	_show(Screen.LOBBY)
	room_label.text = "ROOM  %s" % code
	players_label.text = "\n".join(player_lines(players, host, net.my_id))
	countdown_label.text = countdown_text(countdown, players.size())
	start_button.visible = host == net.my_id and players.size() >= 2
	if first:
		leave_button.grab_focus.call_deferred()
	status.text = "Friends can join with code %s." % code

func _on_match_started(_info: Dictionary) -> void:
	_show(Screen.CONNECTING)

func _on_mesh_ready() -> void:
	OnlineRace.active = true
	get_tree().change_scene_to_file(RACE_SCENE)

func _on_failed(message: String) -> void:
	_show(Screen.SETUP)
	status.text = message

## Esc / BACK / LEAVE: leave the room, or go back to the menu from the setup screen.
func _back() -> void:
	if screen == Screen.SETUP:
		if net != null:
			net.leave()
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	if net != null:
		net.leave()
	_show(Screen.SETUP)
	status.text = "Left the room."

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_back()
