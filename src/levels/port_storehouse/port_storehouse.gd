class_name PortStorehouse
extends Node3D

const ROUTES := {
	&"A_pier": [Vector3(8,0.02,60),Vector3(14,0.02,54),Vector3(58,0.02,54),Vector3(58,0.12,30),Vector3(58,3.12,22),Vector3(62,3.02,17),Vector3(66,3.02,14)],
	&"B_roofs": [Vector3(8,0.02,60),Vector3(24,0.02,44),Vector3(24,0.02,40),Vector3(18,0.02,40),Vector3(18,5.02,40),Vector3(24,5.02,36),Vector3(48,5.02,36),Vector3(48,5.02,30),Vector3(66,6.72,22),Vector3(66,6.72,16),Vector3(66,7,14)],
	&"C_water": [Vector3(8,0.02,60),Vector3(12,0.02,60),Vector3(12,0.02,64),Vector3(20,-1.65,64),Vector3(88,-1.65,64),Vector3(88,-1.65,60),Vector3(88,-3.7,60),Vector3(88,-3.7,40),Vector3(88,-1.65,40),Vector3(88,-1.65,18),Vector3(80,0.02,18),Vector3(80,0.02,16),Vector3(85,0.02,16),Vector3(85,0.02,14),Vector3(78.5,1.72,14),Vector3(77,1.72,14),Vector3(66,1.72,14)]
}
var _built := false

func _enter_tree() -> void:
	if _built: return
	_built = true
	var geometry := _folder(self,"Geometry")
	var ground := _folder(geometry,"Ground")
	var roofs := _folder(geometry,"Roofs")
	var interiors := _folder(geometry,"Interiors")
	var water := _folder(geometry,"Water")
	_box(ground,"Land",Vector3(41,-1.1,29),Vector3(82,0.4,58),Color("394046"))
	_floor_with_hole(ground,"SafeLanding",Rect2(0,58,16,10),-0.9,Rect2(12,62,4,4))
	_box(water,"Seabed",Vector3(48,-5.2,36),Vector3(96,0.4,72),Color("182e36"))
	for x in [24.0,48.0,68.0]:
		var warehouse := _folder(interiors,"Storehouse%d"%int(x))
		_box(warehouse,"WestWall",Vector3(x-8,1.5,36),Vector3(0.3,4.8,12),Color("68706e"))
		_box(warehouse,"EastWall",Vector3(x+8,1.5,36),Vector3(0.3,4.8,12),Color("68706e"))
		for z in [30.0,42.0]:
			_box(warehouse,"DoorLeft%d"%int(z),Vector3(x-5.5,1.5,z),Vector3(5,4.8,0.3),Color("68706e"))
			_box(warehouse,"DoorRight%d"%int(z),Vector3(x+5.5,1.5,z),Vector3(5,4.8,0.3),Color("68706e"))
		for offset in [Vector3(-4,0,1),Vector3(4,0,-2)]:
			_box(warehouse,"Cargo",Vector3(x,0.1,36)+offset,Vector3(2.5,2,2.5),Color("66543c"))
		if x == 24.0: _floor_with_hole(roofs,"Roof1",Rect2(16,30,16,12),4.1,Rect2(17,39,2,2))
		else: _box(roofs,"Roof%d"%int(x),Vector3(x,4.0,36),Vector3(16,0.2,12),Color("313c48"))
	_ramp(roofs,"Plank12",Vector3(31,5.0,36),Vector3(41,5.0,36),1.6)
	_ramp(roofs,"Plank23",Vector3(55,5.0,36),Vector3(61,5.0,36),1.6)
	_ramp(roofs,"HouseRoofBridge",Vector3(48,5,30),Vector3(66,6.7,22),1.6)
	_floor_with_hole(interiors,"CountingFloor",Rect2(54,6,24,16),2.1,Rect2(65.8,13.8,0.4,0.4))
	_floor_with_hole(roofs,"HouseRoof",Rect2(54,6,24,16),5.8,Rect2(65,13,2,2))
	_box(interiors,"HouseWest",Vector3(54,3.95,14),Vector3(0.3,3.7,16),Color("68706e"))
	_box(interiors,"HouseEast",Vector3(78,3.95,14),Vector3(0.3,3.7,16),Color("68706e"))
	_box(interiors,"HouseNorth",Vector3(66,3.95,6),Vector3(24,3.7,0.3),Color("68706e"))
	_ramp(ground,"HouseStairs",Vector3(58,0,30),Vector3(58,3,22),3.0)
	_box(interiors,"CrawlFloor",Vector3(71,0.7,14),Vector3(14,0.2,2),Color("514536"))
	_box(interiors,"CrawlNorth",Vector3(71,1.35,12.85),Vector3(14,1.1,0.3),Color("514536"))
	_box(interiors,"CrawlSouth",Vector3(71,1.35,15.15),Vector3(14,1.1,0.3),Color("514536"))
	_floor_with_hole(ground,"RearDock",Rect2(78,10,6,8),-0.9,Rect2(82,16,2,2))
	_box(ground,"RearRampApproach",Vector3(84,-1,15),Vector3(4,0.2,4),Color("3e4a50"))
	_box(ground,"CrawlPorch",Vector3(78.75,0.7,14),Vector3(1.5,0.2,2),Color("514536"))
	_ramp(ground,"CrawlRamp",Vector3(84,0,14),Vector3(79.5,1.7,14),2.0)
	_ramp(ground,"SouthShore",Vector3(12,0,64),Vector3(20,-3.8,64),4.0)
	_ramp(ground,"RearShore",Vector3(82,0,18),Vector3(90,-3.8,18),4.0)
	_box(water,"ShipHull",Vector3(88,-0.8,50),Vector3(12,3.8,14),Color("4a382c"))
	for wall in [[Vector3(-0.5,0,36),Vector3(1,12,74)],[Vector3(96.5,0,36),Vector3(1,12,74)],[Vector3(48,0,-0.5),Vector3(96,12,1)],[Vector3(48,0,72.5),Vector3(96,12,1)]]:
		_box(ground,"Boundary",wall[0],wall[1],Color("25313b"))
	var ladder := _folder(roofs,"LadderVisual")
	for x in [17.45,18.55]: _visual_box(ladder,Vector3(x,2.15,40.5),Vector3(0.1,5.3,0.1))
	for index in range(13): _visual_box(ladder,Vector3(18,-0.5+index*0.4,40.5),Vector3(1.2,0.08,0.1))
	var markers := _folder(self,"Markers")
	var observation := _folder(markers,"Observation")
	for point in [Vector3(8,0.02,60),Vector3(28,0.02,40),Vector3(24,5.02,36),Vector3(88,-1.65,60),Vector3(88,-1.65,40),Vector3(74,1.72,14)]:
		var marker := Marker3D.new()
		marker.position = point
		observation.add_child(marker)
	var volumes := _folder(markers,"Water")
	_add_water(volumes,"SouthCanal",Vector3(56,-2.95,65),Vector3(76,4.1,14))
	# Leave the sloping rear landing outside the swim contract before contact.
	# The rest of the channel retains full coverage up to the bank.
	_add_water(volumes,"EastCanal",Vector3(88,-2.95,39),Vector3(12,4.1,38))
	_add_water(volumes,"NorthCanal",Vector3(88,-2.95,8),Vector3(12,4.1,16))
	_add_water(volumes,"RearPool",Vector3(90.4,-2.95,18),Vector3(7.2,4.1,4))
	var traversal := _folder(markers,"Traversal")
	var edge := ClimbEdge.new()
	edge.name = "RoofLadder"
	edge.position = Vector3(18,0.02,40)
	edge.top_offset = Vector3(0,5,0)
	edge.connected_beam_path = NodePath("../RoofAccess")
	traversal.add_child(edge)
	var beam := BeamPath.new()
	beam.name = "RoofAccess"
	beam.position = Vector3(18,5.02,40)
	var curve := Curve3D.new()
	curve.add_point(Vector3.ZERO)
	curve.add_point(Vector3(6,0,-4))
	beam.path_curve = curve
	beam.start_climb_edge = NodePath("../RoofLadder")
	traversal.add_child(beam)
	var kill_edge := ClimbEdge.new()
	kill_edge.name = "CountingBeamEntry"
	kill_edge.position = Vector3(66,6.7,16)
	kill_edge.top_offset = Vector3(0,0.3,-0.6)
	kill_edge.connected_beam_path = NodePath("../CountingBeam")
	traversal.add_child(kill_edge)
	var kill_beam := BeamPath.new()
	kill_beam.name = "CountingBeam"
	kill_beam.position = Vector3(66,7,15.4)
	var kill_curve := Curve3D.new()
	kill_curve.add_point(Vector3.ZERO)
	kill_curve.add_point(Vector3(0,0,-1.4))
	kill_beam.path_curve = kill_curve
	kill_beam.start_climb_edge = NodePath("../CountingBeamEntry")
	traversal.add_child(kill_beam)
	_box(roofs,"CountingBeamBoard",Vector3(66,6.025,14.7),Vector3(0.25,0.15,1.4),Color("66543c"))
	var crawl := CrawlEntrance.new()
	crawl.name = "RearCrawl"
	crawl.position = Vector3(78.5,1.72,14)
	crawl.inside_offset = Vector3(-1.5,0,0)
	traversal.add_child(crawl)
	var cover := _folder(markers,"Cover")
	for point in [Vector3(8,0.02,58),Vector3(28,0.02,40),Vector3(50,0.02,38),Vector3(70,0.02,39),Vector3(60,3.02,10),Vector3(74,1.72,14)]:
		var spot := HideSpot.new()
		spot.position = point
		cover.add_child(spot)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("132331")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("93adc2")
	env.environment.ambient_light_energy = 0.5
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-45,-30,0)
	moon.light_color = Color("a2bdd0")
	moon.light_energy = 0.5
	add_child(moon)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	player.name = "Player"
	player.position = ROUTES[&"A_pier"][0]
	add_child(player)

func route_waypoints(id: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in ROUTES.get(id,[]): result.append(point)
	return result

func _folder(parent: Node,name_: String) -> Node3D:
	var node := Node3D.new()
	node.name = name_
	parent.add_child(node)
	return node

func _box(parent: Node,name_: String,point: Vector3,size_: Vector3,color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name_
	body.position = point
	body.collision_layer = 1|16|32
	body.set_meta(&"floor_material",&"wood")
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
	body.set_meta(&"floor_material",&"creaky_wood" if parent.name == &"Roofs" else &"wood")

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
