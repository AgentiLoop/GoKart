extends SceneTree
## Throwaway: list the straight stretches of every course and what sits on them.

const TrackLibrary := preload("res://scripts/track_library.gd")

func _initialize() -> void:
	for t in TrackLibrary.count():
		var d := TrackLibrary.make_data(t)
		var info := TrackLibrary.info(t)
		print("== %s  count %d  length %.0f" % [info.name, d.count, d.length])
		var i := 0
		while i < d.count:
			# longest run from i with total heading change < 0.12 rad over the run
			var j := i
			var h0 := d.heading_at(i)
			while j + 1 < d.count and absf(wrapf(d.heading_at(j + 1) - h0, -PI, PI)) < 0.3:
				j += 1
			if j - i >= 10:
				var occ := []
				for p in d.pads:
					if p.index >= i and p.index <= j:
						occ.append("pad@%.3f" % (float(p.index) / d.count))
				for f in d.box_rows:
					var bi := int(f * d.count)
					if bi >= i and bi <= j:
						occ.append("boxes@%.3f" % f)
				for s in d.hazard_specs:
					var hi := int(s[0] * d.count)
					if hi >= i and hi <= j:
						occ.append("banana@%.3f" % s[0])
				for w in d.water:
					if w.end >= i and w.start <= j:
						occ.append("water %d-%d" % [w.start, w.end])
				for c in d.crossings:
					if c.road >= i and c.road <= j:
						occ.append("crossing@%d" % c.road)
				for m in d.mole_specs:
					var mi := int(m[0] * d.count)
					if mi >= i and mi <= j:
						occ.append("mole@%.3f" % m[0])
				for s in d.snowman_specs:
					var si := int(s[0] * d.count)
					if si >= i and si <= j:
						occ.append("snowman@%.3f" % s[0])
				for s in d.ice:
					if s.end >= i and s.start <= j:
						occ.append("ice %d-%d" % [s.start, s.end])
				for tv in d.traffic_specs:
					var ti := int(tv[0] * d.count)
					if ti >= i and ti <= j:
						occ.append("traffic@%.3f" % tv[0])
				print("  straight samples %3d-%3d  frac %.3f-%.3f  (%d m)  %s" % [i, j, float(i) / d.count, float(j) / d.count, (j - i) * 3, " ".join(occ)])
			i = j + 1
	quit()
