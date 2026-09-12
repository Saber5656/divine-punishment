extends RefCounted

## Actor-centre navigation follows the collidable floor and the house stairs.
## Roof sentries are stationary; no airborne connection joins roof and ground.
static func build(parent: Node3D) -> NavigationRegion3D:
	var region := NavigationRegion3D.new()
	region.name = "PortNavigation"
	var mesh := NavigationMesh.new()
	var vertices := PackedVector3Array()
	var indices := {}
	var polygons: Array[PackedInt32Array] = []
	for z in range(1,67):
		for x in range(1,81):
			if not _allowed(Vector2(x+0.5,z+0.5)): continue
			var polygon := PackedInt32Array()
			for corner in [Vector2(x,z),Vector2(x+1,z),Vector2(x+1,z+1),Vector2(x,z+1)]:
				var point := Vector3(corner.x,_height(corner),corner.y)
				if not indices.has(point):
					indices[point] = vertices.size()
					vertices.append(point)
				polygon.append(indices[point])
			polygons.append(polygon)
	mesh.vertices = vertices
	for polygon in polygons: mesh.add_polygon(polygon)
	region.navigation_mesh = mesh
	parent.add_child(region)
	return region

static func _allowed(point: Vector2) -> bool:
	if point.y >= 58:
		return point.x < 15 and not Rect2(11,61,5,6).has_point(point)
	if Rect2(55,7,22,15).has_point(point): return true
	if Rect2(57,22,2,8).has_point(point): return true
	if Rect2(53,5,26,18).has_point(point): return false
	# Keep ground polygons from joining the side of the elevated stair mesh.
	if Rect2(56,22,4,8).has_point(point): return false
	for center in [24.0,48.0,68.0]:
		if (absf(point.x-(center-8)) < 0.65 or absf(point.x-(center+8)) < 0.65) and point.y > 29.35 and point.y < 42.65: return false
		if (absf(point.y-30) < 0.65 or absf(point.y-42) < 0.65) and absf(point.x-center) > 2.35 and absf(point.x-center) < 8.65: return false
		for cargo in [Vector2(center-4,37),Vector2(center+4,34)]:
			if absf(point.x-cargo.x) < 1.65 and absf(point.y-cargo.y) < 1.65: return false
	return true

static func _height(point: Vector2) -> float:
	if point.x >= 55 and point.x <= 77 and point.y >= 7 and point.y <= 22: return 3.02
	if point.x >= 57 and point.x <= 59 and point.y >= 22 and point.y <= 30: return 0.02+3.0*(30-point.y)/8.0
	return 0.02
