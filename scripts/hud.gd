extends CanvasLayer
## Race HUD: lap counter, lap/race timers, speed, boost/drift indicator, finish banner.
## Styled like the title menu (UiStyle): rounded bold font, gold / cream text with drop shadows,
## no black outlines; only the countdown and the centre banner are "signs" with a dark red rim.
## The results are a Mario Kart 64 style board: a gold title banner over a navy panel, one row
## per racer (colour swatch, gold / silver / bronze ordinal, name, time, points) with the player's
## row on a lit gold bar, section captions, time-trial key/value lines and a blinking prompt.

const Items := preload("res://scripts/items.gd")
const RaceRanking := preload("res://scripts/race_ranking.gd")
const Minimap := preload("res://scripts/minimap.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
const ItemIcon := preload("res://scripts/item_icon.gd")

## Item window (top centre): box side and the icon's side inside it.
const ITEM_WINDOW := 96.0
const ITEM_ICON := 72.0

## Results board geometry (pixels): panel widths (single column / two columns side by side),
## inner padding, row heights and the x of each cell inside a column.
const BOARD_W := 640.0
const BOARD_W_WIDE := 1012.0
const COLUMN_GAP := 20.0
const BOARD_PAD := Vector2(26, 22)
const BOARD_TITLE_H := 46.0
const ROW_H := 32.0
const SECTION_H := 34.0
const KV_H := 30.0
const SIGN_H := 50.0
const TEXT_H := 28.0
const PROMPT_H := 30.0
const GAP_H := 8.0
const SWATCH_X := 22.0
const ORDINAL_X := 50.0
const NAME_X := 128.0
const KV_VALUE_X := 170.0     # value column of the TIME / LAP n / BEST LAP lines
const SILVER := Color(0.85, 0.88, 0.94)
const BRONZE := Color(0.87, 0.58, 0.32)
const PLAYER_FALLBACK := Color(0.9, 0.1, 0.1)   # the player's kart red (Kart.body_color default)

var font: Font
var lap_label: Label
var time_label: Label
var speed_label: Label
var state_label: Label
var banner_label: Label
var item_label: Label
var item_window: Panel          # MK64 item box window (hidden while nothing is held)
var item_icon: ItemIcon
var hint_label: Label
var place_label: Label
var countdown_label: Label
var results_text := ""          # the raw table text the board was built from (checks read it)
var results_panel: Panel
var results_box: Control        # the board's rows, inside results_panel
var results_title: Label
var results_title_panel: Panel
var results_prompts: Array[Label] = []
var player_color := PLAYER_FALLBACK
var blink := 0.0
var cup_label: Label
var minimap: Minimap

static func format_time(t: float) -> String:
	var total_ms := int(round(t * 1000.0))
	return "%d:%02d.%03d" % [total_ms / 60000, (total_ms / 1000) % 60, total_ms % 1000]

## Held item label; multi-use items show the charges left ("x3"), a fired golden mushroom
## its remaining seconds.
static func item_text(item: int, charges := 0, golden_left := 0.0) -> String:
	if item == Items.Type.NONE:
		return ""
	var extra := ""
	if Items.charges_for(item) > 0 and charges > 0:
		extra = " x%d" % charges
	elif item == Items.Type.GOLDEN_MUSHROOM and golden_left > 0.0:
		extra = " %.1fs" % golden_left
	return "[ %s%s ]" % [Items.name_of(item), extra]

## Tells the player how to release a held item (empty when nothing is held).
static func item_hint_text(item: int) -> String:
	return "" if item == Items.Type.NONE else "Press E / Enter / Ctrl to use"

## Bottom-left status word: star beats a Boo ghost beats a boost beats shrunk beats the mini-turbo level.
static func state_text(boosting: bool, drift_level: int, star := false, shrunk := false, ghost := false) -> String:
	if star:
		return "STAR!"
	if ghost:
		return "BOO!"
	if boosting:
		return "BOOST!"
	if shrunk:
		return "SHRUNK!"
	if drift_level > 0:
		return ["", "MINI-TURBO...", "MINI-TURBO!"][mini(drift_level, 2)]
	return ""

static func place_text(rank: int, total: int) -> String:
	return "" if total <= 1 else "%s / %d" % [RaceRanking.ordinal(rank), total]

static func lap_text(lap: int, total: int) -> String:
	return "LAP %d/%d" % [clampi(lap, 1, total), total]

func _ready() -> void:
	# Drawn above the speed-effect overlay (layer 5) so speed lines / blur never touch the UI.
	layer = 10
	font = UiStyle.make_font()
	# Every label spans the whole viewport and is aligned/inset inside it, so the HUD
	# follows the window edges at any size or aspect ratio.
	lap_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 16), 36, UiStyle.GOLD)
	time_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 64), 22, UiStyle.CREAM)
	cup_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 128), 22, UiStyle.SKY_BLUE)
	speed_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM, Vector2(24, 24), 36, UiStyle.CREAM)
	state_label = _make_label(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_BOTTOM, Vector2(24, 24), 28, UiStyle.GOLD)
	# MK64 item window: a rounded navy box with a gold rim at the top centre holding the item's
	# icon (the roulette cycles the icon), the item's name and the use hint underneath
	item_window = Panel.new()
	item_window.anchor_left = 0.5
	item_window.anchor_right = 0.5
	item_window.offset_left = -ITEM_WINDOW * 0.5
	item_window.offset_right = ITEM_WINDOW * 0.5
	item_window.offset_top = 14.0
	item_window.offset_bottom = 14.0 + ITEM_WINDOW
	item_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_window.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_FILL, UiStyle.PANEL_RIM, 18))
	item_window.visible = false
	add_child(item_window)
	item_icon = ItemIcon.new()
	item_icon.font = font
	item_icon.position = Vector2(ITEM_WINDOW - ITEM_ICON, ITEM_WINDOW - ITEM_ICON) * 0.5
	item_icon.size = Vector2(ITEM_ICON, ITEM_ICON)
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_window.add_child(item_icon)
	item_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, Vector2(0, 14 + ITEM_WINDOW + 4), 22, UiStyle.GOLD)
	hint_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP, Vector2(0, 14 + ITEM_WINDOW + 34), 16, UiStyle.GREY)
	place_label = _make_label(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP, Vector2(24, 16), 48, UiStyle.GOLD)
	# the countdown and the centre banner are big "signs": gold with a dark red rim like the logo
	countdown_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -110), 160, UiStyle.GOLD)
	UiStyle.style_sign(countdown_label, font, 160)
	banner_label = _make_label(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER, Vector2(0, -30), 72, UiStyle.GOLD)
	UiStyle.style_sign(banner_label, font, 72)
	# results: a navy panel with a gold rim, centred on screen; the board (title banner + rows) is
	# built inside it by show_results
	results_panel = Panel.new()
	results_panel.set_anchors_preset(Control.PRESET_CENTER)
	results_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(UiStyle.PANEL_FILL, UiStyle.PANEL_RIM, 18))
	results_panel.visible = false
	add_child(results_panel)
	results_box = Control.new()
	results_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_panel.add_child(results_box)
	# the title sits in a gold-rimmed pill overlapping the panel's top edge, like the menu banner
	results_title_panel = Panel.new()
	results_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_title_panel.add_theme_stylebox_override("panel", UiStyle.panel_style(Color(0.08, 0.1, 0.28, 0.98), UiStyle.PANEL_RIM, 23))
	results_panel.add_child(results_title_panel)
	results_title = Label.new()
	results_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	results_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.style_sign(results_title, font, 30)
	results_panel.add_child(results_title)

func _process(delta: float) -> void:
	if not results_panel.visible:
		return
	blink += delta
	var a := 0.6 + 0.4 * sin(blink * 5.0)
	for p in results_prompts:
		p.modulate.a = a

func _make_label(h_align: HorizontalAlignment, v_align: VerticalAlignment, inset: Vector2, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.offset_left = inset.x
	l.offset_right = -inset.x
	if v_align == VERTICAL_ALIGNMENT_CENTER:
		l.offset_top = inset.y      # centred labels: inset.y shifts them up/down
		l.offset_bottom = inset.y
	else:
		l.offset_top = inset.y
		l.offset_bottom = -inset.y
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = h_align
	l.vertical_alignment = v_align
	UiStyle.style_label(l, font, font_size, col)
	add_child(l)
	return l

## Corner minimap of the track centerline (and the railway, if any); call update_minimap each frame
## with kart positions/colours.
func setup_minimap(points: PackedVector3Array, rail := PackedVector3Array()) -> void:
	minimap = Minimap.new()
	add_child(minimap)
	minimap.setup(points, Vector2(220, 220), rail)
	# pinned to the bottom-left corner, above the state text
	minimap.anchor_left = 0.0
	minimap.anchor_right = 0.0
	minimap.anchor_top = 1.0
	minimap.anchor_bottom = 1.0
	minimap.offset_left = 24.0
	minimap.offset_right = 244.0
	minimap.offset_top = -284.0
	minimap.offset_bottom = -64.0

func update_minimap(positions: Array, colors: Array) -> void:
	if colors.size() > 0:
		player_color = colors[0]   # the player's kart is always marker 0 (its swatch on the board)
	if minimap != null:
		minimap.set_markers(positions, colors)

## True for a standings row: an optional ">" player marker, then an ordinal ("1st", "12th").
static func is_rank_line(line: String) -> bool:
	var s := line.strip_edges()
	if s.begins_with(">"):
		s = s.substr(1).strip_edges()
	var tok := s.get_slice(" ", 0)
	return tok.length() >= 3 and tok.left(tok.length() - 2).is_valid_int() and tok.right(2) in ["st", "nd", "rd", "th"]

## Breaks a results text (RaceResults / GrandPrix / TimeTrial / Battle) into board items:
##   title   {text}                                  the first line
##   rank    {player, ordinal, name, value, points}  "> 1st  YOU      1:32.400  +9", "  2nd  BLUE  6 pts",
##                                                   "  3rd  GREEN  2 balloons", "> 1st  0:50.000"
##   section {text}                                  an all-caps caption ("RECORDS", "CUP STANDINGS  (RACE 2 / 4)")
##   kv      {key, value, extra}                     "TIME      1:02.500   NEW RECORD!", "LAP 1     0:21.000"
##   sign    {text}                                  an all-caps shout ("YOU WIN!", "GOLD TROPHY!")
##   prompt  {text}                                  "Press ENTER ..."
##   text    {text}                                  anything else
##   gap                                             a blank line
static func parse_results(text: String) -> Array:
	var items: Array = []
	var lines := text.split("\n")
	for i in lines.size():
		var raw: String = lines[i]
		var line := raw.strip_edges()
		if i == 0:
			items.append({"kind": "title", "text": line})
			continue
		if line == "":
			items.append({"kind": "gap"})
			continue
		if is_rank_line(raw):
			var player := raw.strip_edges().begins_with(">")
			var toks := Array(raw.replace(">", " ").split(" ", false))
			var ordinal: String = toks.pop_front()
			var name := ""
			if toks.size() > 0 and String(toks[0]).is_valid_identifier() and String(toks[0]) == String(toks[0]).to_upper():
				name = toks.pop_front()
			var points := ""
			if toks.size() > 0 and String(toks[-1]).begins_with("+"):
				points = toks.pop_back()
			elif toks.size() > 1 and toks[-1] == "pts":
				toks.pop_back()
				points = "%s pts" % toks.pop_back()
			items.append({"kind": "rank", "player": player, "ordinal": ordinal, "name": name, "value": " ".join(toks), "points": points})
			continue
		var prompt_at := line.find("Press ENTER")
		if prompt_at > 0:
			# "GOLD TROPHY!  Press ENTER for the menu" -> a sign, then the prompt
			items.append({"kind": "sign", "text": line.left(prompt_at).strip_edges()})
			items.append({"kind": "prompt", "text": line.substr(prompt_at)})
			continue
		if prompt_at == 0:
			items.append({"kind": "prompt", "text": line})
			continue
		var gap := RegEx.create_from_string("\\s{2,}").search(line)
		if gap != null:
			var key := line.left(gap.get_start()).strip_edges()
			var rest := line.substr(gap.get_end())
			if rest.begins_with("("):
				items.append({"kind": "section", "text": line})
				continue
			if key.ends_with("!"):
				# "RANK OUT!  6th - finish 4th or better to go on" -> a sign over a plain line
				items.append({"kind": "sign", "text": key})
				items.append({"kind": "text", "text": rest.strip_edges()})
				continue
			var rest_gap := RegEx.create_from_string("\\s{2,}").search(rest)
			var extra := ""
			if rest_gap != null:
				extra = rest.substr(rest_gap.get_end()).strip_edges()
				rest = rest.left(rest_gap.get_start()).strip_edges()
			items.append({"kind": "kv", "key": key, "value": rest, "extra": extra})
			continue
		if line == line.to_upper():
			# one all-caps word is a caption ("RECORDS"); a shout is a sign ("YOU WIN!", "BLUE WINS")
			items.append({"kind": "sign" if " " in line else "section", "text": line})
			continue
		items.append({"kind": "text", "text": line})
	return items

## Board colour for an ordinal: gold / silver / bronze for the podium, cream below.
static func ordinal_color(ordinal: String) -> Color:
	match ordinal:
		"1st":
			return UiStyle.GOLD
		"2nd":
			return SILVER
		"3rd":
			return BRONZE
	return UiStyle.CREAM

## Swatch colour for a racer name: the CPU karts are named after their colours; "YOU" is the
## player's kart colour; anything else gets no swatch (transparent).
func swatch_color(name: String) -> Color:
	if name == "YOU":
		return player_color
	return Color.from_string(name.to_lower(), Color(0, 0, 0, 0))

func _board_label(text: String, pos: Vector2, w: float, h: float, font_size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = pos
	l.size = Vector2(w, h)
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UiStyle.style_label(l, font, font_size, col)
	results_box.add_child(l)
	return l

func _board_rule(x0: float, y: float, col_w: float) -> void:
	var r := ColorRect.new()
	r.position = Vector2(x0 + 8, y)
	r.size = Vector2(col_w - 16, 1)
	r.color = Color(1, 1, 1, 0.16)
	results_box.add_child(r)

## Height of one board item (the title is drawn in its own pill above the rows).
static func item_height(item: Dictionary) -> float:
	match item.kind:
		"title":
			return 0.0
		"rank":
			return ROW_H
		"section":
			return SECTION_H
		"kv":
			return KV_H
		"sign":
			return SIGN_H
		"prompt":
			return PROMPT_H
		"gap":
			return GAP_H
	return TEXT_H

## Splits the board items into [head, side, tail]: when a caption ("CUP STANDINGS", "RECORDS") is
## followed by rank rows, that block becomes a second column beside the head (MK64 shows the race
## result and the cup points side by side); whatever follows the block (gap, trophy sign, prompt)
## is the full-width tail. Without such a block everything is the head.
static func split_columns(items: Array) -> Array:
	for i in range(1, items.size() - 1):
		if items[i].kind == "section" and items[i + 1].kind == "rank":
			var head: Array = items.slice(0, i)
			while head.size() > 0 and head[-1].kind == "gap":
				head.pop_back()
			var j := i + 1
			while j < items.size() and items[j].kind == "rank":
				j += 1
			# the head needs rows of its own, otherwise the caption just starts the single column
			if head.size() > 1:
				return [head, items.slice(i, j), items.slice(j)]
			break
	return [items, [], []]

## Lays `items` out in a column `col_w` wide starting at (x0, y0); returns the height used.
func _layout(items: Array, x0: float, y0: float, col_w: float) -> float:
	var y := y0
	var value_x := col_w - 230.0
	for item in items:
		var h := item_height(item)
		match item.kind:
			"title":
				results_title.text = item.text
			"rank":
				var col := ordinal_color(item.ordinal)
				if item.player:
					var bar := Panel.new()
					bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
					bar.position = Vector2(x0 + 6, y + 2)
					bar.size = Vector2(col_w - 12, h - 4)
					var sb := StyleBoxFlat.new()
					sb.bg_color = Color(1.0, 0.82, 0.22, 0.22)
					sb.border_color = UiStyle.GOLD
					sb.set_border_width_all(2)
					sb.set_corner_radius_all(10)
					bar.add_theme_stylebox_override("panel", sb)
					results_box.add_child(bar)
				var sw := swatch_color(item.name)
				if sw.a > 0.0:
					var dot := Panel.new()
					dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
					dot.position = Vector2(x0 + SWATCH_X, y + h * 0.5 - 8)
					dot.size = Vector2(16, 16)
					var ds := StyleBoxFlat.new()
					ds.bg_color = sw
					ds.border_color = Color(1, 1, 1, 0.8)
					ds.set_border_width_all(1)
					ds.set_corner_radius_all(8)
					dot.add_theme_stylebox_override("panel", ds)
					results_box.add_child(dot)
				_board_label(item.ordinal, Vector2(x0 + ORDINAL_X, y), NAME_X - ORDINAL_X - 8, h, 22, col)
				if item.name != "":
					_board_label(item.name, Vector2(x0 + NAME_X, y), value_x - NAME_X - 8, h, 22, UiStyle.GOLD if item.player else UiStyle.CREAM)
					_board_label(item.value, Vector2(x0 + value_x, y), col_w - value_x - 8, h, 22, UiStyle.CREAM)
				else:
					_board_label(item.value, Vector2(x0 + NAME_X, y), col_w - NAME_X - 8, h, 22, UiStyle.CREAM)
				if item.points != "":
					_board_label(item.points, Vector2(x0 + value_x, y), col_w - value_x - 12, h, 22, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			"section":
				_board_label(item.text, Vector2(x0 + 12, y), col_w - 24, h - 6, 17, UiStyle.GOLD_DIM)
				_board_rule(x0, y + h - 4, col_w)
			"kv":
				_board_label(item.key, Vector2(x0 + 12, y), KV_VALUE_X - 12, h, 19, UiStyle.GOLD_DIM)
				_board_label(item.value, Vector2(x0 + KV_VALUE_X, y), col_w - KV_VALUE_X - 12, h, 22, UiStyle.CREAM)
				if item.extra != "":
					_board_label(item.extra, Vector2(x0 + value_x, y), col_w - value_x - 12, h, 19, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
			"sign":
				var s := _board_label(item.text, Vector2(x0, y), col_w, h, 34, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
				UiStyle.style_sign(s, font, 34)
			"prompt":
				results_prompts.append(_board_label(item.text, Vector2(x0, y), col_w, h, 20, UiStyle.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
			"text":
				_board_label(item.text, Vector2(x0, y), col_w, h, 20, UiStyle.CREAM, HORIZONTAL_ALIGNMENT_CENTER)
		y += h
	return y - y0

## Results board (text from RaceResults.table_text / GrandPrix / TimeTrial / Battle); empty hides it.
## The text is parsed into rows, so the columns no longer depend on a monospace font.
func show_results(text: String) -> void:
	results_text = text
	results_panel.visible = text != ""
	for c in results_box.get_children():
		results_box.remove_child(c)
		c.queue_free()
	results_prompts.clear()
	if not results_panel.visible:
		return
	var parts := split_columns(parse_results(text))
	var two := (parts[1] as Array).size() > 0
	var board_w := BOARD_W_WIDE if two else BOARD_W
	var inner_w := board_w - 2.0 * BOARD_PAD.x
	var y := BOARD_PAD.y + BOARD_TITLE_H * 0.5
	if two:
		var col_w := (inner_w - COLUMN_GAP) * 0.5
		var left := _layout(parts[0], 0.0, y, col_w)
		var right := _layout(parts[1], col_w + COLUMN_GAP, y, col_w)
		y += maxf(left, right)
		y += _layout(parts[2], 0.0, y, inner_w)
	else:
		y += _layout(parts[0], 0.0, y, inner_w)
	# wrap the panel around the rows (centred on screen, nudged up like the old table), the title
	# pill straddling the top edge
	var board_h := y + BOARD_PAD.y
	results_panel.offset_left = -board_w * 0.5
	results_panel.offset_right = board_w * 0.5
	results_panel.offset_top = -20.0 - board_h * 0.5
	results_panel.offset_bottom = -20.0 + board_h * 0.5
	results_box.position = Vector2(BOARD_PAD.x, 0)
	results_box.size = Vector2(inner_w, board_h)
	var title_w := maxf(260.0, results_title.get_minimum_size().x + 60.0)
	results_title_panel.position = Vector2((board_w - title_w) * 0.5, -BOARD_TITLE_H * 0.5)
	results_title_panel.size = Vector2(title_w, BOARD_TITLE_H)
	results_title.position = results_title_panel.position
	results_title.size = results_title_panel.size

## Grand Prix progress line under the timers ("RACE 2 / 3"); empty hides it.
func show_cup(text: String) -> void:
	cup_label.text = text

## Big centre text for the start countdown ("3", "2", "1", "GO!"); empty hides it.
func show_countdown(text: String) -> void:
	countdown_label.text = text

## Item window: the icon of the held (or rolling) item, its name and the use hint; hidden when empty.
func show_item(item: int, charges := 0, golden_left := 0.0) -> void:
	item_window.visible = item != Items.Type.NONE
	item_icon.item = item
	item_label.text = item_text(item, charges, golden_left)
	hint_label.text = item_hint_text(item)

func update_hud(tracker, speed: float, boosting: bool, drift_level: int, item := 0, place := "", star := false, shrunk := false, charges := 0, golden_left := 0.0, ghost := false) -> void:
	place_label.text = place
	show_item(item, charges, golden_left)
	lap_label.text = lap_text(tracker.lap, tracker.total_laps) if tracker.lap > 0 else "READY"
	time_label.text = "TIME %s\nLAP  %s" % [format_time(tracker.race_time), format_time(tracker.lap_time)]
	speed_label.text = "%d km/h" % int(round(absf(speed) * 3.6))
	state_label.text = state_text(boosting, drift_level, star, shrunk, ghost)
	banner_label.text = "FINISH!" if tracker.is_finished else ""

## Battle mode HUD: balloons instead of laps, the battle clock instead of lap times, no finish banner
## (the centre banner shows `banner`: "BOMB KART!" / "YOU WIN!" / "OUT").
func update_battle(balloons_line: String, elapsed: float, speed: float, boosting: bool, drift_level: int, item := 0, place := "", star := false, shrunk := false, charges := 0, golden_left := 0.0, ghost := false, banner := "") -> void:
	place_label.text = place
	show_item(item, charges, golden_left)
	lap_label.text = balloons_line
	time_label.text = "TIME %s" % format_time(elapsed)
	speed_label.text = "%d km/h" % int(round(absf(speed) * 3.6))
	state_label.text = state_text(boosting, drift_level, star, shrunk, ghost)
	banner_label.text = banner
