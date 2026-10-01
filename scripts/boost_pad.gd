extends RefCounted
## Oriented rectangle on the road that gives a speed boost when driven over.

var center := Vector3.ZERO
var forward := Vector3(0, 0, -1)
var length := 7.0
var width := 5.0
var index := 0

func contains(p: Vector3) -> bool:
	var d := Vector3(p.x - center.x, 0, p.z - center.z)
	var along := d.dot(forward)
	var side := d.dot(Vector3(-forward.z, 0, forward.x))
	return absf(along) <= length * 0.5 and absf(side) <= width * 0.5
