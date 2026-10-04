extends Node3D
## Mario Kart 64 style roadside scenery node: renders the props a Scenery layout places beside the
## road. Every (kind, part) pair is one MultiMeshInstance3D — a few draw calls for hundreds of
## trees, cacti or lamps — with an instance per prop placed by the prop's position, yaw and scale.
## Props are decoration only (no collision: they stand beyond the walls).

const Scenery := preload("res://scripts/scenery.gd")

var props: Array = []            # the Scenery.props() layout this node shows
var batches: Array = []          # MultiMeshInstance3D per (kind, part) that has at least one prop

func _init(layout: Array) -> void:
	props = layout

func _ready() -> void:
	var by_kind := {}
	for p in props:
		if not by_kind.has(p.kind):
			by_kind[p.kind] = []
		by_kind[p.kind].append(p)
	for kind in by_kind:
		var group: Array = by_kind[kind]
		var parts: Array = Scenery.parts(kind)
		for pi in parts.size():
			var part: Dictionary = parts[pi]
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%s%d" % [kind.capitalize(), pi]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = make_mesh(part)
			mm.instance_count = group.size()
			for gi in group.size():
				mm.set_instance_transform(gi, prop_transform(group[gi], part))
			mmi.multimesh = mm
			var mat := StandardMaterial3D.new()
			mat.albedo_color = part.color
			mat.roughness = 0.9
			mmi.material_override = mat
			add_child(mmi)
			batches.append(mmi)

## The world transform of one part of a prop: the prop's yaw and scale about its ground point, then
## the part's offset inside the prop.
static func prop_transform(p: Dictionary, part: Dictionary) -> Transform3D:
	var basis := Basis.from_euler(Vector3(0, p.yaw, 0)).scaled(p.scale)
	return Transform3D(basis, p.pos) * Transform3D(Basis.IDENTITY, part.at)

## The unit mesh of a part (size as Scenery.parts documents).
static func make_mesh(part: Dictionary) -> Mesh:
	var size: Vector3 = part.size
	match part.shape:
		"box":
			var b := BoxMesh.new()
			b.size = size
			return b
		"sphere":
			var s := SphereMesh.new()
			s.radius = size.x
			s.height = size.x * 2.0
			s.radial_segments = 12
			s.rings = 6
			return s
		"cylinder":
			var c := CylinderMesh.new()
			c.top_radius = size.x
			c.bottom_radius = size.x
			c.height = size.y
			c.radial_segments = 10
			c.rings = 1
			return c
		"cone":
			var k := CylinderMesh.new()
			k.top_radius = 0.0
			k.bottom_radius = size.x
			k.height = size.y
			k.radial_segments = 10
			k.rings = 1
			return k
	return BoxMesh.new()

## How many prop instances the node draws in all (over every part batch of every kind, counted once
## per prop: the first part of each kind).
func prop_count() -> int:
	return props.size()
