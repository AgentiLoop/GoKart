extends RefCounted
## 3D sign text (Lakitu's sign, the start-gate banner, the train's "64" plate) shares the menu / HUD
## look: the rounded font with a thin rim in the board's own shade instead of a thick black outline.

const UiStyle := preload("res://scripts/ui_style.gd")
const Lakitu := preload("res://scripts/lakitu.gd")
const Track := preload("res://scripts/track.gd")
const TrackData := preload("res://scripts/track_data.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const Train := preload("res://scripts/train.gd")
const Railway := preload("res://scripts/railway.gd")
var runner

const DESERT := 3

func _is_thin_rim(l: Label3D, what: String) -> void:
	runner.check(l.outline_size == maxi(4, l.font_size / 8), "%s: rim %d for %d px text" % [what, l.outline_size, l.font_size])
	runner.check(l.outline_size * 8 <= l.font_size, "%s: rim is at most 1/8 of the text size (was 1/4 - 1/3.5)" % what)
	runner.check(l.outline_modulate != Color.BLACK and l.outline_modulate.v > 0.05, "%s: rim is a colour, not black (%s)" % [what, l.outline_modulate])
	runner.check(l.font is SystemFont and (l.font as SystemFont).font_names == PackedStringArray(UiStyle.FONT_NAMES), "%s: rounded menu font" % what)

func test_style_label3d_helper() -> void:
	var l := Label3D.new()
	UiStyle.style_label3d(l, 96, Color.WHITE, Color(0.3, 0.0, 0.0))
	runner.check(l.font_size == 96 and l.outline_size == 12 and l.modulate == Color.WHITE and l.outline_modulate == Color(0.3, 0.0, 0.0), "96 px -> 12 px rim")
	UiStyle.style_label3d(l, 24, UiStyle.GOLD, UiStyle.SIGN_RIM)
	runner.check(l.outline_size == 4, "small text keeps a 4 px minimum rim")
	var board := Color(0.9, 0.05, 0.05)
	var rim := UiStyle.board_rim(board)
	runner.check(rim.r < board.r and rim.g <= board.g and rim.b <= board.b and rim.r > 0.3, "board rim is a darker red, not black: %s" % rim)
	l.free()

func test_lakitu_sign_text_sits_on_its_board() -> void:
	var lk = Lakitu.new()
	_is_thin_rim(lk._sign_label, "Lakitu sign")
	runner.check(lk._sign_label.modulate == Color(1, 1, 1), "white text on the board")
	# the rim follows the board colour: red REVERSE, green LAP n, orange FINAL LAP
	lk._sign_label.text = "REVERSE"
	lk._set_board(Color(0.9, 0.05, 0.05))
	runner.check(lk._sign_label.outline_modulate == UiStyle.board_rim(Color(0.9, 0.05, 0.05)) and (lk._sign_board.material_override as StandardMaterial3D).albedo_color == Color(0.9, 0.05, 0.05), "red board, dark red rim")
	lk._set_board(Color(0.1, 0.6, 0.2))
	var green_rim: Color = lk._sign_label.outline_modulate
	runner.check(green_rim.g > green_rim.r and green_rim.g > green_rim.b, "green board -> green-shaded rim: %s" % green_rim)
	lk.free()

func test_start_banner_rim_follows_the_banner_colour() -> void:
	var track = Track.new(TrackData.new())
	track._ready()
	runner.check(track._banner_labels.size() == 2, "a label on each face of the banner")
	for lbl in track._banner_labels:
		_is_thin_rim(lbl, "start banner")
	# START: green banner, white text, green-shaded rim
	track.set_banner("START")
	var rim: Color = track._banner_labels[0].outline_modulate
	runner.check(track._banner_labels[0].modulate == Color(1, 1, 1) and rim == UiStyle.board_rim(Color(0.05, 0.55, 0.15)) and rim.g > rim.r, "START rim in the green banner's shade: %s" % rim)
	track.set_banner("FINISH")
	rim = track._banner_labels[1].outline_modulate
	runner.check(rim == UiStyle.board_rim(Color(0.75, 0.05, 0.05)) and rim.r > rim.g, "FINISH rim in the red banner's shade: %s" % rim)
	track.set_banner("CONTINUE")
	rim = track._banner_labels[0].outline_modulate
	runner.check(track._banner_labels[0].modulate == Color(1.0, 0.85, 0.1) and rim.b > rim.r, "CONTINUE: gold text, blue-shaded rim: %s" % rim)
	track.free()

func test_train_plate_is_a_gold_sign() -> void:
	var d := TrackLibrary.make_data(DESERT)
	var tr := Train.new(d)
	var rw = Railway.new(d, tr)
	rw._ready()
	var plate: Label3D = null
	for ch in rw.cars[0][0].get_children():
		if ch is Label3D:
			plate = ch
	runner.check(plate != null and plate.text == "64", "the locomotive carries the 64 plate")
	if plate != null:
		_is_thin_rim(plate, "train plate")
		runner.check(plate.modulate == UiStyle.GOLD and plate.outline_modulate == UiStyle.SIGN_RIM, "gold with the logo's dark red rim")
	rw.free()

func test_no_thick_outlines_left_in_scripts() -> void:
	# every Label3D / Label outline in scripts/ goes through UiStyle (logo rim 7 px is the one exception)
	var dir := DirAccess.open("res://scripts")
	var offenders: Array = []
	for f in dir.get_files():
		if not f.ends_with(".gd") or f == "ui_style.gd":
			continue
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		var re := RegEx.create_from_string("outline_size\\s*=\\s*(\\d+)")
		for m in re.search_all(src):
			var n := int(m.get_string(1))
			if n > 7:
				offenders.append("%s: %d" % [f, n])
		var re2 := RegEx.create_from_string("\"outline_size\",\\s*(\\d+)")
		for m in re2.search_all(src):
			if int(m.get_string(1)) > 7:
				offenders.append("%s: %s" % [f, m.get_string(1)])
	runner.check(offenders.is_empty(), "no hard-coded outline wider than the logo rim: %s" % str(offenders))
