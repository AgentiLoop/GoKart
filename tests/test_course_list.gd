extends RefCounted
## The select screen's course list (Mario Kart 64's map-select pictures): a course picture in the
## course's own sky / ground colours with the road loop across it beside every name, the picked
## row's picture framed in gold on the lit bar, arena pictures in battle mode.

const Menu := preload("res://scripts/menu.gd")
const TrackLibrary := preload("res://scripts/track_library.gd")
const ArenaData := preload("res://scripts/arena_data.gd")
const UiStyle := preload("res://scripts/ui_style.gd")
var runner

func _root() -> Node:
	return Engine.get_main_loop().root

func _menu() -> Node:
	var m = Menu.new()
	_root().add_child(m)
	if m.select_box == null:
		m._ready()   # the runner's root is not ready yet during _initialize
	m.dismiss_title()
	return m

func _rows(m: Node) -> Array:
	var out: Array = []
	for c in m.list_box.get_children():
		if c.name.begins_with("Row"):
			out.append(c)
	return out

func _bars(m: Node) -> Array:
	var out: Array = []
	for c in m.list_box.get_children():
		if c is Panel:
			out.append(c)
	return out

func test_loop_points_fit_the_ground_strip() -> void:
	var square := PackedVector3Array([Vector3(-50, 0, -20), Vector3(50, 0, -20), Vector3(50, 0, 20), Vector3(-50, 0, 20)])
	var area := Vector2(64, 40)
	var loop := Menu.CourseThumb.loop_points(square, area, 5.0)
	runner.check(loop.size() == square.size() + 1 and loop[0] == loop[loop.size() - 1], "loop closed back to its first point")
	var top := area.y * Menu.CourseThumb.HORIZON
	var ok := true
	for p in loop:
		ok = ok and p.x >= 5.0 - 0.01 and p.x <= area.x - 5.0 + 0.01 and p.y >= top + 5.0 - 0.01 and p.y <= area.y - 5.0 + 0.01
	runner.check(ok, "every loop point inside the ground strip under the horizon: %s" % [loop])
	var w := loop[1].x - loop[0].x
	var h := loop[2].y - loop[1].y
	runner.check(absf(h - (area.y - top - 10.0)) < 0.01 and absf(h / w - 0.4) < 0.01, "loop fills the strip's height keeping its aspect: %.1f x %.1f" % [w, h])
	runner.check(Menu.CourseThumb.loop_points(PackedVector3Array(), area, 5.0).is_empty(), "no points -> empty loop")

func test_rows_carry_course_pictures() -> void:
	var m = _menu()
	var rows := _rows(m)
	runner.check(rows.size() == TrackLibrary.count() and m.list_box.get_child_count() == TrackLibrary.count() + 1, "a row per course plus the lit bar: %d children" % m.list_box.get_child_count())
	runner.check(_bars(m).size() == 1 and _bars(m)[0].position.y == rows[m.selected].position.y, "the lit bar sits behind the picked row")
	var bar_rect := Rect2(16, 0, 388, Menu.LIST_BAR_H)
	for i in rows.size():
		var row: Control = rows[i]
		var thumb = row.get_node("Thumb")
		var label: Label = row.get_node("Name")
		var info := TrackLibrary.info(i)
		runner.check(thumb is Menu.CourseThumb and thumb.sky_top == info.sky_top and thumb.sky_horizon == info.sky_horizon and thumb.ground == info.ground, "row %d: picture in %s's colours" % [i, info.name])
		runner.check(thumb.loop.size() == TrackLibrary.make_data(i).points.size() + 1, "row %d: the whole road loop" % i)
		var inside := true
		for p in thumb.loop:
			inside = inside and Rect2(Vector2.ZERO, thumb.size).has_point(p)
		runner.check(inside and bar_rect.encloses(Rect2(thumb.position, thumb.size)), "row %d: loop inside the picture, picture inside the bar" % i)
		runner.check(thumb.lit == (i == m.selected), "row %d: only the picked picture is framed in gold" % i)
		runner.check(label.text == info.name and label.position.x >= thumb.position.x + thumb.size.x + 8.0 and label.position.x + label.size.x <= bar_rect.end.x, "row %d: name right of the picture, inside the bar" % i)
		runner.check(label.get_theme_color("font_color") == (UiStyle.GOLD if i == m.selected else UiStyle.CREAM) and label.get_theme_constant("outline_size") == 0, "row %d: gold when picked, cream otherwise, no outline" % i)
	m.move(1)
	rows = _rows(m)
	runner.check(rows[1].get_node("Thumb").lit and not rows[0].get_node("Thumb").lit and _bars(m)[0].position.y == rows[1].position.y, "Right moves the gold frame and the bar to row 1")
	runner.check(m.picture_cache.has("t0:false") and not m.picture_cache.has("t0:true"), "pictures cached per course (plain)")
	m.move_engine(1)   # 150cc -> Extra: mirrored courses, mirrored pictures
	runner.check(m.picture_cache.has("t0:true"), "Extra class caches the mirrored pictures")
	m.free()

func test_arena_pictures_in_battle_mode() -> void:
	var m = _menu()
	while m.mode != Menu.MODE_BATTLE:
		m.toggle_mode()
	var rows := _rows(m)
	runner.check(rows.size() == ArenaData.arena_count() and m.list_box.get_child_count() == ArenaData.arena_count() + 1, "a row per arena plus the lit bar")
	for i in rows.size():
		var thumb = rows[i].get_node("Thumb")
		var info := ArenaData.info(i)
		runner.check(thumb.sky_top == info.sky_top and thumb.ground == info.ground and thumb.loop.size() > 3, "arena row %d: picture in %s's colours with its outline" % [i, info.name])
		runner.check(thumb.lit == (i == m.arena_selected), "arena row %d: gold frame on the picked arena" % i)
	runner.check(m.picture_cache.has("a0"), "arena pictures cached")
	m.free()
