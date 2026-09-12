class_name FestivalNight
extends Node3D

const ROUTES := {
	&"A_crowd":[Vector3(12,0.02,88),Vector3(24,0.02,80),Vector3(48,0.02,76),Vector3(48,0.02,60),Vector3(48,0.02,40),Vector3(51,0.02,33),Vector3(51,3.02,25),Vector3(51,3.02,17)],
	&"B_roofs":[Vector3(12,0.02,88),Vector3(18,0.02,78),Vector3(18,0.02,76),Vector3(18,4.02,74),Vector3(22,4.02,70),Vector3(28,4.02,48),Vector3(68,4.02,48),Vector3(70,4.02,44),Vector3(84,6.62,40),Vector3(84,6.62,34),Vector3(84,6.9,32)],
	&"C_well":[Vector3(12,0.02,88),Vector3(72,0.02,84),Vector3(72,0.02,38),Vector3(66,0.02,38),Vector3(66,0.02,26),Vector3(72,0.02,18),Vector3(69,0.02,16),Vector3(69,-3,13),Vector3(84,-3,13),Vector3(84,-3,22.5),Vector3(84,-3,24),Vector3(84,1.72,34.4),Vector3(84,1.74,34.5),Vector3(84,3.02,38),Vector3(84,3.02,39),Vector3(87,3.02,39),Vector3(87,3.02,33.2),Vector3(84,3.02,33.2)]
}
var _built := false

func _enter_tree() -> void:
	if _built: return
	_built = true
	var geometry := _folder(self,"Geometry")
	var ground := _folder(geometry,"Ground")
	var roofs := _folder(geometry,"Roofs")
	var interiors := _folder(geometry,"Interiors")
	var canal := _folder(geometry,"Canal")
	_floor(ground,"Land",Rect2(0,0,108,96),-0.9,[Rect2(67,11,4,4),Rect2(76,24,16,16)],0.4)
	_floor(interiors,"ShrineDeck",Rect2(40,8,22,17),2.1,[])
	_floor(roofs,"ShrineRoof",Rect2(40,8,22,17),5.7,[])
	_ramp(ground,"ShrineSteps",Vector3(51,0,33),Vector3(51,3,25),5)
	for x in [40.0,62.0]: _box(interiors,"ShrineSide",Vector3(x,3.9,16.5),Vector3(0.3,3.6,17),Color("675b46"))
	_box(interiors,"ShrineNorth",Vector3(51,3.9,8),Vector3(22,3.6,0.3),Color("675b46"))
	for x in [40.0,46.0,56.0,62.0]: _box(interiors,"ShrinePost",Vector3(x,3.9,25),Vector3(0.4,3.6,0.4),Color("674331"))
	_floor(interiors,"DaisDeck",Rect2(76,24,16,16),2.1,[Rect2(82,34,4,4)])
	_floor(roofs,"DaisRoof",Rect2(76,24,16,16),5.7,[Rect2(83,31,2,2)])
	_ramp(ground,"DaisSteps",Vector3(68,0,32),Vector3(76,3,32),4)
	_box(interiors,"DaisEast",Vector3(92,3.9,32),Vector3(0.3,3.6,16),Color("725c42"))
	_box(interiors,"DaisNorth",Vector3(84,3.9,24),Vector3(16,3.6,0.3),Color("725c42"))
	for spec in [[27.0,6.0],[37.0,6.0]]: _box(interiors,"DaisWest",Vector3(76,3.9,spec[0]),Vector3(0.3,3.6,spec[1]),Color("725c42"))
	for x in [76.0,80.0,88.0,92.0]: _box(interiors,"DaisPost",Vector3(x,3.9,40),Vector3(0.4,3.6,0.4),Color("674331"))
	_floor(roofs,"WestRoof",Rect2(18,48,16,26),3.1,[])
	for x in [18.0,34.0]: _box(interiors,"WestHouseSide",Vector3(x,1.1,61),Vector3(0.3,4,26),Color("726653"))
	_floor(roofs,"EastRoof",Rect2(64,40,12,12),3.1,[])
	_ramp(roofs,"StreetRoofBridge",Vector3(28,4,48),Vector3(68,4,48),2)
	_ramp(roofs,"DaisRoofBridge",Vector3(70,4,44),Vector3(84,6.6,40),1.8)
	_box(roofs,"DaisBeamBoard",Vector3(84,5.925,32.7),Vector3(0.25,0.15,1.4),Color("806546"))
	for x in [36.0,62.0]:
		for z in [38.0,56.0,68.0]:
			_box(interiors,"StallCounter",Vector3(x,0, z),Vector3(4,1.8,3),Color("896c4b"))
			_box(roofs,"StallAwning",Vector3(x,2.8,z),Vector3(5,0.2,4),Color("835345"))
	# Ground below the well and dais is physically absent, so the canal never
	# climbs through an invisible land slab. Its water is shallow enough to walk.
	_box(canal,"CanalWestFloor",Vector3(76,-4,13),Vector3(18,0.2,4),Color("3f4a45"))
	_box(canal,"CanalNorthFloor",Vector3(84,-4,19),Vector3(4,0.2,12),Color("3f4a45"))
	_box(canal,"UndercroftFloor",Vector3(84,-4,32),Vector3(16,0.2,16),Color("3f4a45"))
	# Seal the ground cutout up to the deck underside; only the low canal
	# opening remains. The western stair surface stays above this foundation.
	for x in [76.0,92.0]: _box(canal,"DaisFoundationSide",Vector3(x,-1,32),Vector3(0.3,5.8,16),Color("3f4a45"))
	_box(canal,"DaisFoundationSouth",Vector3(84,-1,40),Vector3(16,5.8,0.3),Color("3f4a45"))
	for x in [79.0,89.0]: _box(canal,"DaisFoundationNorth",Vector3(x,-1,24),Vector3(6,5.8,0.3),Color("3f4a45"))
	_box(canal,"CanalLintel",Vector3(84,0.4,24),Vector3(4,3,0.3),Color("3f4a45"))
	for x in [66.85,86.15]: _box(canal,"CanalEnd",Vector3(x,-2.5,13),Vector3(0.3,2.8,4),Color("444b43"))
	_box(canal,"CanalWall",Vector3(76,-2.5,10.85),Vector3(18,2.8,0.3),Color("444b43"))
	_box(canal,"CanalWall",Vector3(74.5,-2.5,15.15),Vector3(15,2.8,0.3),Color("444b43"))
	for x in [81.85,86.15]: _box(canal,"CanalSide",Vector3(x,-2.5,20),Vector3(0.3,2.8,10),Color("444b43"))
	_ramp(canal,"CanalRise",Vector3(84,-3,25),Vector3(84,1.72,34),2)
	_ramp(interiors,"HatchStep",Vector3(84,1.72,35),Vector3(84,3,38),2)
	_box(canal,"CrawlLanding",Vector3(84,0.72,34.5),Vector3(2,0.2,1),Color("5c5545"))
	for body in canal.get_children(): body.set_meta(&"floor_material",&"shallow_water")
	for point in [Vector3(76,-3.73,13),Vector3(84,-3.73,19)]:
		var surface := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(18,4) if point.z == 13 else Vector2(4,12)
		surface.mesh = plane
		surface.position = point
		var water := StandardMaterial3D.new()
		water.albedo_color = Color(0.08,0.16,0.17,0.5)
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plane.material = water
		canal.add_child(surface)
	for wall in [[Vector3(-0.5,3,48),Vector3(1,16,98)],[Vector3(108.5,3,48),Vector3(1,16,98)],[Vector3(54,3,-0.5),Vector3(108,16,1)],[Vector3(54,3,96.5),Vector3(108,16,1)]]:
		_box(ground,"Boundary",wall[0],wall[1],Color("252b31"))
	var markers := _folder(self,"Markers")
	var traversal := _folder(markers,"Traversal")
	_climb(traversal,"WestRoofGrip",Vector3(18,0.02,76),Vector3(0,4,-2),"WestRoofBeam",Vector3(18,4.02,74),Vector3(22,4.02,70))
	_climb(traversal,"DaisBeamGrip",Vector3(84,6.62,34),Vector3(0,0.28,-0.6),"DaisBeam",Vector3(84,6.9,33.4),Vector3(84,6.9,32))
	for spec in [["CanalCrawl",Vector3(84,-3,22.5),Vector3(0,0,1.5)],["DaisCrawl",Vector3(84,1.74,34.5),Vector3(0,0,-0.5)]]:
		var entrance := CrawlEntrance.new()
		entrance.name = spec[0]
		entrance.position = spec[1]
		entrance.inside_offset = spec[2]
		traversal.add_child(entrance)
	var observation := _folder(markers,"Observation")
	var cover := _folder(markers,"Cover")
	for point in [Vector3(12,0.02,88),Vector3(24,0.02,80),Vector3(48,0.02,72),Vector3(28,4.02,50),Vector3(72,0.02,18),Vector3(51,3.02,24),Vector3(87,3.02,39)]:
		var marker := Marker3D.new()
		marker.position = point
		observation.add_child(marker)
		var spot := HideSpot.new()
		spot.position = point
		cover.add_child(spot)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("172337")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("a6b4ce")
	env.environment.ambient_light_energy = 0.4
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55,-30,0)
	moon.light_energy = 0.4
	add_child(moon)
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	player.name = "Player"
	player.position = ROUTES[&"A_crowd"][0]
	add_child(player)

func route_waypoints(id: StringName) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point in ROUTES.get(id,[]): result.append(point)
	return result

func escape_waypoints() -> Array[Vector3]:
	return [Vector3(78,3.02,32),Vector3(76,3.02,32),Vector3(68,0.02,32),Vector3(48,0.02,40),Vector3(48,0.02,76),Vector3(40,0.02,84),Vector3(12,0.02,88)]

func _floor(parent: Node,label: String,bounds: Rect2,height: float,holes: Array,thickness: float = 0.2) -> void:
	var pieces: Array[Rect2] = [bounds]
	for hole: Rect2 in holes:
		var next: Array[Rect2] = []
		for rect in pieces:
			var cut := rect.intersection(hole)
			if not cut.has_area():
				next.append(rect)
				continue
			for piece in [Rect2(rect.position,Vector2(cut.position.x-rect.position.x,rect.size.y)),Rect2(Vector2(cut.end.x,rect.position.y),Vector2(rect.end.x-cut.end.x,rect.size.y)),Rect2(Vector2(cut.position.x,rect.position.y),Vector2(cut.size.x,cut.position.y-rect.position.y)),Rect2(Vector2(cut.position.x,cut.end.y),Vector2(cut.size.x,rect.end.y-cut.end.y))]:
				if piece.has_area(): next.append(piece)
		pieces = next
	for index in pieces.size():
		var rect := pieces[index]
		_box(parent,label+str(index),Vector3(rect.get_center().x,height-thickness/2,rect.get_center().y),Vector3(rect.size.x,thickness,rect.size.y),Color("4f5254"))

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
