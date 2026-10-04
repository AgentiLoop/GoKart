extends CanvasLayer
## Mario Kart 64 style pause screen. MK64's Start button freezes the race where it is and puts a
## small menu over it — continue, retry, change the course, quit. Here Esc does the same: the whole
## race (karts, timers, music, Lakitu) stops dead (`get_tree().paused`) and a navy panel with a gold
## rim pops up in the middle of the frozen picture, PAUSE as a sign on its top edge, then the four
## lines — CONTINUE / RETRY / COURSE CHANGE / QUIT — the picked one gold on a lit bar, over a navy
## veil that dims the scene. Up / Down (W / S) move the cursor with a tick, Enter picks (a chime),
## Esc resumes. Text uses drop shadows, no black outlines; only the PAUSE sign keeps the dark red
## rim the HUD's signs use. This layer runs while the tree is paused, so it is the only thing
## listening to the keys until the race goes on.

const UiStyle := preload("res://scripts/ui_style.gd")
const SoundSynth := preload("res://scripts/sound_synth.gd")
const GrandPrix := preload("res://scripts/grand_prix.gd")
const CourseIntro := preload("res://scripts/course_intro.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const MENU_SCRIPT := "res://scripts/menu.gd"   # loaded late: menu.gd preloads main.gd, which preloads this

const CONTINUE := 0
const RETRY := 1
const COURSE_CHANGE := 2
const QUIT := 3
const OPTIONS := ["CONTINUE", "RETRY", "COURSE CHANGE", "QUIT"]

const LAYER := 11                        # over the HUD (10)
const VEIL := Color(0.04, 0.05, 0.16, 0.45)   # the menu's navy dip, no black
const PANEL_SIZE := Vector2(360, 272)
const PANEL_RADIUS := 18
const TITLE_W := 200.0
const TITLE_H := 46.0                    # the PAUSE pill straddles the panel's top edge
const TITLE_FONT := 30
const ROWS_Y := 56.0
const ROW_H := 40.0
const ROW_INSET := 28.0
const ROW_FONT := 24
const BAR_PAD := 3.0                     # the lit bar sits this far inside the row
const HINT := "ENTER PICKS   ESC RESUMES"
const HINT_FONT := 13
const HINT_H := 24.0
const POP_TIME := 0.18                   # the panel pops in (scale POP_FROM -> 1 with an overshoot)
const POP_FROM := 0.8
const EFFECTS := ["pause", "resume", "cursor", "confirm"]
const EFFECT_DB := -6.0

var shown := false
var cursor := CONTINUE
var anim_t := POP_TIME                   # seconds since the panel came up
var picked := -1                         # the last line carried out (checks read it)
var played: Array = []                   # effect names triggered so far (tests read it)
var font: Font
var veil: ColorRect
var panel: Panel
var title: Label
var rows: Array[Label] = []
var bar: Panel
var hint: Label
var streams := {}
var voice: AudioStreamPlayer

## Cursor one line up / down, wrapping round.
static func step(from: int, dir: int, count := OPTIONS.size()) -> int:
	return posmod(from + dir, count)

static func direction_for_key(code: int) -> int:
	if code == KEY_UP or code == KEY_W:
		return -1
	if code == KEY_DOWN or code == KEY_S:
		return 1
	return 0

static func is_confirm_key(code: int) -> bool:
	return code == KEY_ENTER or code == KEY_KP_ENTER

static func is_pause_key(code: int) -> bool:
	return code == KEY_ESCAPE

## Where line `i` sits inside the panel.
static func row_rect(i: int) -> Rect2:
	return Rect2(ROW_INSET, ROWS_Y + i * ROW_H, PANEL_SIZE.x - 2.0 * ROW_INSET, ROW_H)

static func ease_out_back(t: float) -> float:
	var u := t - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u

## The panel's pose `t` seconds after it came up: scale (overshooting once) and alpha.
static func pop_pose(t: float) -> Dictionary:
	var u := clampf(t / POP_TIME, 0.0, 1.0)
	return {"scale": lerpf(POP_FROM, 1.0, ease_out_back(u)), "alpha": clampf(u * 2.0, 0.0, 1.0)}

func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = UiStyle.make_font()
	veil = ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.color = VEIL
	add_child(veil)
	panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x * 0.5
	panel.offset_right = PANEL_SIZE.x * 0.5
	panel.offset_top = -PANEL_SIZE.y * 0.5
	panel.offset_bottom = PANEL_SIZE.y * 0.5
	panel.pivot_offset = PANEL_SIZE * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_FILL, UiStyle.PANEL_RIM, PANEL_RADIUS))
	add_child(panel)
	var title_panel := Panel.new()
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.position = Vector2((PANEL_SIZE.x - TITLE_W) * 0.5, -TITLE_H * 0.5)
	title_panel.size = Vector2(TITLE_W, TITLE_H)
	title_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.08, 0.1, 0.28, 0.98), UiStyle.PANEL_RIM, 23))
	panel.add_child(title_panel)
	title = Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = "PAUSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.position = title_panel.position
	title.size = title_panel.size
	UiStyle.style_sign(title, font, TITLE_FONT)
	panel.add_child(title)
	bar = Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UiStyle.lit_style(10))
	panel.add_child(bar)
	for i in OPTIONS.size():
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.text = OPTIONS[i]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var r := row_rect(i)
		l.position = r.position
		l.size = r.size
		UiStyle.style_label(l, font, ROW_FONT, UiStyle.CREAM)
		panel.add_child(l)
		rows.append(l)
	hint = Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = HINT
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, PANEL_SIZE.y - HINT_H - 12.0)
	hint.size = Vector2(PANEL_SIZE.x, HINT_H)
	UiStyle.style_label(hint, font, HINT_FONT, UiStyle.GREY)
	panel.add_child(hint)
	var lib := SoundSynth.effect_library()
	for name in EFFECTS:
		streams[name] = SoundSynth.to_wav(lib[name])
	voice = AudioStreamPlayer.new()
	voice.volume_db = EFFECT_DB
	add_child(voice)
	_apply_cursor()
	visible = false

## Esc during the race: freeze everything and bring the panel up on CONTINUE.
func open() -> void:
	if shown:
		return
	shown = true
	cursor = CONTINUE
	anim_t = 0.0
	_apply_cursor()
	_apply_pop()
	visible = true
	get_tree().paused = true
	_play("pause")

## Back to the race exactly where it stopped.
func resume() -> void:
	if not shown:
		return
	shown = false
	visible = false
	get_tree().paused = false
	_play("resume")

func move(dir: int) -> void:
	cursor = step(cursor, dir)
	_apply_cursor()
	_play("cursor")

## Carry out the line the cursor is on.
func pick(option: int) -> void:
	picked = option
	match option:
		CONTINUE:
			resume()
		RETRY:
			# the same race from the grid, with its course intro, nothing scored (a cup keeps its points)
			_play("confirm")
			_hand_over_voice()
			get_tree().paused = false
			shown = false
			CourseIntro.pending = true
			get_tree().reload_current_scene()
		COURSE_CHANGE:
			_leave(false)
		QUIT:
			_leave(true)

## To the menu: the select screen (course change) or the title screen (quit); a cup is over.
func _leave(to_title: bool) -> void:
	_play("confirm")
	_hand_over_voice()
	get_tree().paused = false
	shown = false
	GrandPrix.stop()
	if to_title:
		load(MENU_SCRIPT).title_seen = false
	get_tree().change_scene_to_file(MENU_SCENE)

## The chime outlives the scene change: the voice moves to the scene root and frees itself.
func _hand_over_voice() -> void:
	if not is_inside_tree():
		return
	remove_child(voice)
	get_tree().root.add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice = AudioStreamPlayer.new()
	voice.volume_db = EFFECT_DB
	add_child(voice)

func _play(name: String) -> void:
	played.append(name)
	voice.stream = streams[name]
	if is_inside_tree():
		voice.play()

func _apply_cursor() -> void:
	var r := row_rect(cursor)
	bar.position = r.position + Vector2(0, BAR_PAD)
	bar.size = r.size - Vector2(0, 2.0 * BAR_PAD)
	for i in rows.size():
		rows[i].add_theme_color_override("font_color", UiStyle.GOLD if i == cursor else UiStyle.CREAM)

func _apply_pop() -> void:
	var pose := pop_pose(anim_t)
	panel.scale = Vector2.ONE * pose.scale
	panel.modulate.a = pose.alpha

func _process(delta: float) -> void:
	if shown and anim_t < POP_TIME:
		anim_t = minf(anim_t + delta, POP_TIME)
		_apply_pop()

func _unhandled_input(event: InputEvent) -> void:
	if not shown or not (event is InputEventKey and event.pressed and not event.echo):
		return
	var code: int = event.physical_keycode
	var vp := get_viewport()   # taken first: a scene change below detaches this node at once
	if is_pause_key(code):
		resume()
	elif is_confirm_key(code):
		pick(cursor)
	elif direction_for_key(code) != 0:
		move(direction_for_key(code))
	else:
		return
	vp.set_input_as_handled()
