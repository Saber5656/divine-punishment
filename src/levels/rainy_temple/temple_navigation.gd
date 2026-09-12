extends RefCounted

## Bake the actual collision geometry, then retain only authored walking floors.
## EnemyBase navigates its capsule centre, so lift the baked floor by 0.92 m.
static func build(parent: Node3D,geometry: Node3D) -> NavigationRegion3D:
	var source := NavigationMeshSourceGeometryData3D.new()
	var floors: Array[StaticBody3D] = []
	for group in geometry.get_children():
		for body in group.get_children():
			if not body is StaticBody3D: continue
			var shape := body.get_child(0) as CollisionShape3D
			if shape == null or not shape.shape is BoxShape3D: continue
			var box := BoxMesh.new()
			box.size = (shape.shape as BoxShape3D).size
			source.add_mesh_array(box.get_mesh_arrays(),body.global_transform*shape.transform)
			var role := str(body.get_meta(&"art_role",""))
			if role in ["Land","Graveyard","Courtyard","FrontSteps","HallSteps","HallBase","CellHallStairs","CellCourtStairs","GraveBridge"] or role.begins_with("CellFloor"):
				floors.append(body)
	var baked := NavigationMesh.new()
	baked.cell_size = 0.2
	baked.cell_height = 0.05
	baked.agent_radius = 0.4
	baked.agent_height = 1.8
	baked.agent_max_climb = 0.15
	baked.agent_max_slope = 50
	baked.region_min_size = 0
	baked.region_merge_size = 0
	NavigationServer3D.bake_from_source_geometry_data(baked,source)
	var mesh := NavigationMesh.new()
	var vertices := baked.vertices
	var kept: Array[PackedInt32Array] = []
	for index in baked.get_polygon_count():
		var polygon := baked.get_polygon(index)
		var center := Vector3.ZERO
		for vertex in polygon: center += vertices[vertex]
		center /= polygon.size()
		if _on_floor(center,floors): kept.append(polygon)
	for index in vertices.size(): vertices[index] += Vector3.UP*0.92
	mesh.vertices = vertices
	for polygon in kept: mesh.add_polygon(polygon)
	var region := NavigationRegion3D.new()
	region.name = "TempleNavigation"
	region.navigation_mesh = mesh
	parent.add_child(region)
	return region

static func _on_floor(point: Vector3,floors: Array[StaticBody3D]) -> bool:
	for floor_ in floors:
		var shape := floor_.get_child(0) as CollisionShape3D
		var local := (floor_.global_transform*shape.transform).affine_inverse()*point
		var half := (shape.shape as BoxShape3D).size*0.5
		if absf(local.x) <= half.x+0.05 and absf(local.z) <= half.z+0.05 and absf(local.y-half.y) < 0.2:
			return true
	return false
