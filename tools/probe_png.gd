extends SceneTree
func _initialize() -> void:
	for n in ["title", "menu0"]:
		var img := Image.load_from_file("/tmp/gokart_%s.png" % n)
		print(n, " size ", img.get_size())
		var cols := {}
		var step := 8
		for y in range(0, img.get_height(), step):
			for x in range(0, img.get_width(), step):
				var c := img.get_pixel(x, y)
				var key := "%d,%d,%d" % [int(c.r * 8), int(c.g * 8), int(c.b * 8)]
				cols[key] = cols.get(key, 0) + 1
		print("  distinct colour bins: ", cols.size())
		# sample rows
		for y in [40, 200, 360, 450, 540, 640]:
			var line := ""
			for x in range(0, img.get_width(), img.get_width() / 10):
				var c := img.get_pixel(x, y)
				line += "(%.2f %.2f %.2f) " % [c.r, c.g, c.b]
			print("  y=%d: %s" % [y, line])
	quit(0)
