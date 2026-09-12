class_name RainyTemple
extends Node3D

const ROUTES := {
	&"A_steps": [Vector3(12,0.02,88),Vector3(40,0.02,88),Vector3(40,0.12,84),Vector3(40,4.12,66),Vector3(48,4.02,58),Vector3(48,4.12,40),Vector3(48,8.12,32),Vector3(51,8.02,22)],
	&"B_cliff": [Vector3(12,0.02,88),Vector3(18,0.02,76),Vector3(18,0.02,72),Vector3(18,4.02,70),Vector3(24,4.02,58),Vector3(28,4.02,54),Vector3(28,8.02,50),Vector3(28,8.12,44),Vector3(44,11.72,32),Vector3(44,11.62,30),Vector3(51,11.62,24),Vector3(51,11.9,22)],
	&"C_stream": [Vector3(12,0.02,88),Vector3(80,0.02,92),Vector3(84,0.02,92),Vector3(94,-1.65,92),Vector3(94,-1.65,44),Vector3(84,0.02,44),Vector3(86.75,0.12,44),Vector3(86.75,3.72,33),Vector3(86.75,3.72,32),Vector3(85.25,3.72,32),Vector3(76,3.72,32),Vector3(74.5,3.72,32),Vector3(72,5.02,32)]
}
var _built := false

func _enter_tree() -> void:
	if _built: return
	_built = true
	var geometry := _folder(self,"Geometry")
	var ground := _folder(geometry,"Ground")
	var terraces := _folder(geometry,"Terraces")
	var roofs := _folder(geometry,"Roofs")
	var interiors := _folder(geometry,"Interiors")
	var water := _folder(geometry,"Water")
	_box(ground,"Land",Vector3(44,-1.1,50),Vector3(88,0.4,100),Color("303b39"))
	_box(water,"Seabed",Vector3(92,-5.2,50),Vector3(8,0.4,100),Color("152e35"))
	_box(terraces,"Graveyard",Vector3(20,1.1,56),Vector3(24,4,32),Color("48504c"))
	_box(terraces,"Courtyard",Vector3(52,1.1,49),Vector3(36,4,34),Color("48504c"))
	_box(terraces,"GraveBridge",Vector3(33,3,58),Vector3(2,0.2,4),Color("48504c"))
	_ramp(ground,"FrontSteps",Vector3(40,0,84),Vector3(40,4,66),4)
	_ramp(terraces,"HallSteps",Vector3(48,4,40),Vector3(48,8,32),4)
	_box(terraces,"HallBase",Vector3(51,3.1,23),Vector3(30,8,18),Color("394542"))
	# Keep a real opening for the roof route and its assassination beam.
	_floor_with_hole(roofs,"HallRoof",Rect2(36,14,30,18),10.7,Rect2(50,21,2,2))
	for x in [36.0,66.0]: _box(interiors,"HallSide",Vector3(x,8.9,23),Vector3(0.3,3.6,18),Color("646964"))
	_box(interiors,"HallNorth",Vector3(51,8.9,14),Vector3(30,3.6,0.3),Color("646964"))
	# The front stays open; pillar-sized solids remain outside the central approach.
	for x in [36.0,42.0,60.0,66.0]: _box(interiors,"HallPillar",Vector3(x,8.9,32),Vector3(0.4,3.6,0.4),Color("65583d"))
	_box(roofs,"LodgingRoof",Vector3(27,7,46),Vector3(14,0.2,12),Color("313f46"))
	for x in [20.0,34.0]: _box(interiors,"LodgingSide",Vector3(x,5.1,46),Vector3(0.3,4,12),Color("60635b"))
	_ramp(roofs,"HallRoofBridge",Vector3(28,8,44),Vector3(44,11.6,32),1.8)
	# Cell deck has a lower crawl tunnel and a real floor hatch/short internal ramp.
	_floor_with_hole(interiors,"CellFloor",Rect2(70,24,16,16),4.1,Rect2(72,31,3,2))
	_box(roofs,"CellRoof",Vector3(78,7,32),Vector3(16,0.2,16),Color("313f46"))
	for z in [24.0,40.0]: _box(interiors,"CellEnd",Vector3(78,5.6,z),Vector3(16,3,0.3),Color("65583d"))
	_box(interiors,"CellWestNorth",Vector3(70,5.6,25.5),Vector3(0.3,3,3),Color("65583d"))
	_box(interiors,"CellWestSouth",Vector3(70,5.6,36.5),Vector3(0.3,3,7),Color("65583d"))
	_box(interiors,"CellEast",Vector3(86,5.6,32),Vector3(0.3,3,16),Color("65583d"))
	_box(interiors,"CrawlFloor",Vector3(80.5,2.7,32),Vector3(15,0.2,2),Color("514536"))
	for z in [30.85,33.15]: _box(interiors,"CrawlSide",Vector3(79.5,3.35,z),Vector3(13,1.1,0.3),Color("514536"))
	_ramp(interiors,"CellInnerStep",Vector3(74,3.72,32),Vector3(72,5,32),1.8)
	_ramp(ground,"MillRise",Vector3(86.75,0,44),Vector3(86.75,3.72,33),1.6)
	_ramp(terraces,"CellHallStairs",Vector3(70,5,28),Vector3(66,8,28),2.4)
	_ramp(terraces,"CellCourtStairs",Vector3(70,5,30),Vector3(64,4,38),2.4)
	_ramp(ground,"StreamEntry",Vector3(88,0,92),Vector3(96,-3.8,92),4)
	_ramp(ground,"MillShore",Vector3(88,0,44),Vector3(96,-3.8,44),4)
	# Watermill graybox: east landing is open and the north gap clears the rise.
	_box(roofs,"MillRoof",Vector3(86,3,46),Vector3(8,0.2,8),Color("313f46"))
	_box(interiors,"MillWest",Vector3(82,1.1,46),Vector3(0.3,4,8),Color("65583d"))
	_box(interiors,"MillSouth",Vector3(86,1.1,50),Vector3(8,4,0.3),Color("65583d"))
	_box(interiors,"MillNorthWest",Vector3(83,1.1,42),Vector3(2,4,0.3),Color("65583d"))
	_box(interiors,"MillNorthEast",Vector3(89.5,1.1,42),Vector3(1,4,0.3),Color("65583d"))
	var wheel := MeshInstance3D.new()
	wheel.name = "MillWheel"
	wheel.mesh = CylinderMesh.new()
	(wheel.mesh as CylinderMesh).top_radius = 1.4
	(wheel.mesh as CylinderMesh).bottom_radius = 1.4
	(wheel.mesh as CylinderMesh).height = 0.25
	wheel.position = Vector3(90.2,0.3,47)
	wheel.rotation.z = PI/2
	water.add_child(wheel)
	for wall in [[Vector3(-0.5,4,50),Vector3(1,24,102)],[Vector3(96.5,4,50),Vector3(1,24,102)],[Vector3(48,4,-0.5),Vector3(96,24,1)],[Vector3(48,4,100.5),Vector3(96,24,1)]]:
		_box(ground,"Boundary",wall[0],wall[1],Color("22333b"))
	# Bell tower and gate silhouettes sit beside, not across, their approach lanes.
	for x in [24.0,28.0]:
		for z in [52.0,56.0]: _box(interiors,"BellPost",Vector3(x,5.6,z),Vector3(0.3,5,0.3),Color("65583d"))
	_box(roofs,"BellRoof",Vector3(26,8.1,54),Vector3(5,0.25,5),Color("313f46"))
	for x in [44.0,52.0]: _box(interiors,"GatePost",Vector3(x,5.6,60),Vector3(0.6,5,0.6),Color("65583d"))
	_box(roofs,"GateRoof",Vector3(48,8.1,60),Vector3(11,0.3,4),Color("313f46"))
	for x in [12.0,16.0,20.0]:
		for z in [48.0,54.0]: _box(terraces,"GraveStone",Vector3(x,3.8,z),Vector3(0.8,1.4,0.4),Color("5b615c"))
	var markers := _folder(self,"Markers")
	var traversal := _folder(markers,"Traversal")
	_climb(traversal,"CliffGrip",Vector3(18,0.02,72),Vector3(0,4,-2),"CliffTop",Vector3(18,4.02,70),Vector3(24,4.02,66))
	_climb(traversal,"LodgingGrip",Vector3(28,4.02,54),Vector3(0,4,-4),"LodgingTop",Vector3(28,8.02,50),Vector3(28,8.02,48))
	_climb(traversal,"HallBeamGrip",Vector3(51,11.62,24),Vector3(0,0.28,-0.6),"HallBeam",Vector3(51,11.9,23.4),Vector3(51,11.9,22))
	_box(roofs,"HallBeamBoard",Vector3(51,10.925,22.7),Vector3(0.25,0.15,1.4),Color("7d6749"))
	for spec in [["MillCrawl",Vector3(86.75,3.72,32),Vector3(-1.5,0,0)],["CellCrawl",Vector3(74.5,3.72,32),Vector3(1.5,0,0)]]:
		var entrance := CrawlEntrance.new()
		entrance.name = spec[0]
		entrance.position = spec[1]
		entrance.inside_offset = spec[2]
		traversal.add_child(entrance)
	var volumes := _folder(markers,"Water")
	# Banks leave swimming before rising above surface: split shore pockets laterally.
	_add_water(volumes,"Stream",Vector3(94.4,-2.95,50),Vector3(3.2,4.1,100))
	for spec in [["NorthRun",21.0,42.0],["MiddleRun",68.0,44.0],["SouthRun",97.0,6.0]]:
		_add_water(volumes,spec[0],Vector3(90.4,-2.95,spec[1]),Vector3(4.8,4.1,spec[2]))
	var observation := _folder(markers,"Observation")
	var cover := _folder(markers,"Cover")
	for point in [Vector3(12,0.02,88),Vector3(38,0.02,84),Vector3(24,4.02,58),Vector3(44,4.02,62),Vector3(28,8.02,48),Vector3(84,0.02,44),Vector3(72,5.02,32)]:
		var marker := Marker3D.new()
		marker.position = point
		observation.add_child(marker)
		var spot := HideSpot.new()
		spot.position = point
		cover.add_child(spot)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("132331")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("93adc2")
	env.environment.ambient_light_energy = 0.4
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55,-30,0)
	moon.light_energy = 0.4
	add_child(moon)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	player.name = "Player"
	player.position = ROUTES[&"A_steps"][0]
	add_child(player)

func _climb(parent: Node,name_: String,position_: Vector3,offset: Vector3,beam_name: String,start: Vector3,end: Vector3) -> void:
	var edge := ClimbEdge.new()
	edge.name = name_
	edge.position = position_
	edge.top_offset = offset
	edge.connected_beam_path = NodePath("../"+beam_name)
	parent.add_child(edge)
	var beam := BeamPath.new()
	beam.name = beam_name
	beam.position = start
	beam.path_curve = Curve3D.new()
	beam.path_curve.add_point(Vector3.ZERO)
	beam.path_curve.add_point(end-start)
	beam.start_climb_edge = NodePath("../"+name_)
	parent.add_child(beam)

func route_waypoints(id: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in ROUTES.get(id,[]): result.append(point)
	return result

func rescue_return_waypoints() -> Array[Vector3]:
	return [Vector3(72,5.02,30),Vector3(70,5.12,30),Vector3(64,4.12,38),Vector3(48,4.02,58),Vector3(40,4.12,66),Vector3(40,0.12,84),Vector3(40,0.02,88),Vector3(12,0.02,88)]

func _folder(parent: Node,name_: String) -> Node3D:
	var node := Node3D.new()
	node.name = name_
	parent.add_child(node)
	return node

func _box(parent: Node,name_: String,point: Vector3,size_: Vector3,color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.set_meta(&"art_role",name_)
	body.position = point
	body.collision_layer = 1|16|32
	body.set_meta(&"floor_material",&"gravel" if parent.name in [&"Ground",&"Terraces"] else &"wood")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = size_
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size_
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	parent.add_child(body)
	return body

func _ramp(parent: Node,name_: String,start: Vector3,end: Vector3,width: float) -> void:
	var axis_z := (start-end).normalized()
	var axis_x := Vector3.UP.cross(axis_z).normalized()
	var axis_y := axis_z.cross(axis_x).normalized()
	var body := _box(parent,name_,(start+end)*0.5-Vector3.UP*0.9-axis_y*0.1,Vector3(width,0.2,start.distance_to(end)),Color("745d41"))
	body.basis = Basis(axis_x,axis_y,axis_z)
	body.set_meta(&"floor_material",&"creaky_wood" if parent.name == &"Roofs" else (&"gravel" if parent.name in [&"Ground",&"Terraces"] else &"wood"))

func _floor_with_hole(parent: Node,name_: String,bounds: Rect2,height: float,hole: Rect2) -> void:
	var pieces := [Rect2(bounds.position,Vector2(hole.position.x-bounds.position.x,bounds.size.y)),Rect2(Vector2(hole.end.x,bounds.position.y),Vector2(bounds.end.x-hole.end.x,bounds.size.y)),Rect2(Vector2(hole.position.x,bounds.position.y),Vector2(hole.size.x,hole.position.y-bounds.position.y)),Rect2(Vector2(hole.position.x,hole.end.y),Vector2(hole.size.x,bounds.end.y-hole.end.y))]
	for i in pieces.size():
		var rect: Rect2 = pieces[i]
		if rect.size.x <= 0.0 or rect.size.y <= 0.0: continue
		_box(parent,name_+str(i),Vector3(rect.get_center().x,height-0.1,rect.get_center().y),Vector3(rect.size.x,0.2,rect.size.y),Color("3e4a50"))

func _add_water(parent: Node,name_: String,point: Vector3,size_: Vector3) -> void:
	var volume := WaterVolume.new()
	volume.name = name_
	volume.position = point
	volume.size = size_
	volume.surface_body_depth = 0.75
	volume.underwater_body_depth = 2.8
	parent.add_child(volume)
	var visual := MeshInstance3D.new()
	visual.mesh = PlaneMesh.new()
	(visual.mesh as PlaneMesh).size = Vector2(size_.x,size_.z)
	visual.position = point+Vector3.UP*size_.y*0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.06,0.25,0.3,0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.3
	visual.material_override = material
	get_node("Geometry/Water").add_child(visual)

func _visual_box(parent: Node,point: Vector3,size_: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size_
	mesh.position = point
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b49464")
	mesh.material_override = material
	parent.add_child(mesh)
