class_name TutorialGeometry
extends RefCounted

const PLAYER := preload("res://src/player/player.tscn")
const ENEMY := preload("res://src/enemies/enemy_base.tscn")
const EARTH := Color("37463e")
const WOOD := Color("463a31")
const ROCK := Color("505b62")
const MOSS := Color("253e34")
const VERMILION := Color("963f31")
var root: Node3D
var nodes: Dictionary = {}


func build(level: Node3D) -> Dictionary:
	root = level
	_floor("MountainPath", Vector3(0, -0.4, -22), Vector3(15, 0.8, 60), &"wood", EARTH)
	_floor("HutCourt", Vector3(8, -0.4, -57), Vector3(33, 0.8, 18), &"wood", EARTH)
	_floor("GroundRoute", Vector3(8, -0.4, -73), Vector3(4, 0.8, 18), &"wood", EARTH)
	_floor("EscapeLanding", Vector3(3, -0.4, -83), Vector3(16, 0.8, 8), &"wood", EARTH)
	_floor("Gravel", Vector3(0, 0.01, -45), Vector3(10, 0.04, 7), &"gravel", Color("738079"))
	_wall("WestCliff", Vector3(-8, 2, -22), Vector3(1, 4, 62), ROCK)
	_wall("EastCliff", Vector3(8, 2, -20), Vector3(1, 4, 58), ROCK)
	_wall("StartRock", Vector3(0, 2, 8), Vector3(16, 4, 1), ROCK)
	_gate("SneakGate", Vector3(0, 1.6, -18), Vector3(15, 3.2, 0.5))
	_gate("HideGate", Vector3(0, 1.6, -38), Vector3(15, 3.2, 0.5))
	_wall("CourtNorthWall", Vector3(17, 2, -49), Vector3(18, 4, 0.6), WOOD)
	_wall("CourtEastWall", Vector3(25, 2, -59), Vector3(0.6, 4, 20), WOOD)
	_wall("CourtSouthFence", Vector3(-1, 2, -66), Vector3(16, 4, 0.6), WOOD)
	_wall("HutPartition", Vector3(10, 2, -59.5), Vector3(0.6, 4, 13), WOOD)
	_gate("LureGate", Vector3(10, 1.6, -51), Vector3(0.6, 3.2, 3))
	_wall("HutBackWall", Vector3(19, 2, -66), Vector3(12, 4, 0.6), WOOD)
	_gate("DocumentGate", Vector3(12, 1.6, -66), Vector3(3, 3.2, 0.6))
	_wall("GateWestFence", Vector3(5.8, 1, -73), Vector3(0.4, 2, 14), WOOD)
	_wall("GateEastFence", Vector3(10.2, 1, -74), Vector3(0.4, 2, 12), WOOD)
	_gate("GroundGate", Vector3(8, 1.6, -73), Vector3(4, 3.2, 0.5))
	_floor("RoofWalk", Vector3(10, 2.7, -71), Vector3(20, 0.6, 4), &"wood", WOOD)
	# The climb approaches the clear eastern lip; it never intersects the hut wall.
	_floor("ClimbApproach", Vector3(18, -0.4, -67.5), Vector3(15, 0.8, 3), &"wood", EARTH)
	var edge := ClimbEdge.new()
	edge.name = "RoofClimb"
	edge.position = Vector3(20, 0.9, -67)
	edge.top_offset = Vector3(-1, 3, -3)
	edge.entry_radius = 1.3
	root.add_child(edge)
	nodes.roof_climb = edge
	_wall("RoofBackRail", Vector3(10, 3.4, -69), Vector3(20, 0.8, 0.2), VERMILION)
	_wall("RoofFrontRail", Vector3(13, 3.4, -73), Vector3(14, 0.8, 0.2), VERMILION)
	# Descending roof exit stays physically supported all the way to the landing.
	for index in range(6):
		var height := 2.5 - float(index) * 0.5
		_floor("RoofExitStep%d" % index, Vector3(3, height - 0.25, -73.5 - index), Vector3(3, 0.5, 1), &"wood", WOOD)
	# Moonlight and real occluding canopy give a safe visibility comparison.
	_light("MoonPool", Vector3(0, 6, -3), 13.0, false, Color("adc6df"))
	_wall("PineCanopy", Vector3(-3, 3.1, -11), Vector3(5, 0.5, 7), MOSS)
	_wall("PineTrunk", Vector3(-5.2, 1.4, -11), Vector3(0.4, 2.8, 0.4), WOOD)
	_wall("PeekRock", Vector3(-6.8, 1.5, -33), Vector3(0.6, 3, 6), ROCK)
	nodes.brush = _hide("Brush", Vector3(-5.7, 0.9, -28))
	_visual("BrushLeaves", Vector3(-5.7, 0.65, -28), Vector3(2.8, 1.3, 2.8), MOSS)
	nodes.body_hide = _hide("BodyHide", Vector3(14, 0.9, -62.5))
	_visual("StorageCover", Vector3(14, 0.25, -63), Vector3(2.6, 0.5, 2), WOOD)
	nodes.lamp_a = _light("HutLanternA", Vector3(13, 0.9, -53), 5.5, true, Color("ffb166"))
	nodes.lamp_b = _light("HutLanternB", Vector3(22, 0.9, -56), 5.5, true, Color("ffb166"))
	nodes.gate_lamp = _light("GateLantern", Vector3(8, 0.9, -68), 6.0, true, Color("ffb166"))
	nodes.document = _visual("Document", Vector3(16, 1, -64), Vector3(0.7, 0.2, 0.5), Color("e5d4a1"))
	nodes.stone_box = _visual("StoneBox", Vector3(4, 0.5, -49), Vector3(1.2, 1, 1.2), WOOD)
	nodes.gate_stone_box = _visual("GateStoneBox", Vector3(12, 0.5, -67), Vector3(1, 1, 1), WOOD)
	_visual("FirstThrowMark", Vector3(1, 0.07, -55), Vector3(1.8, 0.08, 1.8), VERMILION)
	_visual("GateThrowMark", Vector3(4, 0.07, -59), Vector3(1.8, 0.08, 1.8), VERMILION)
	_nav("MountainNav", Rect2(-6, -17, 12, 15))
	_nav("CliffNav", Rect2(-4, -36, 10, 16))
	_nav("GateNav", Rect2(-5, -64, 14, 15))
	_nav("HutNav", Rect2(12, -64, 12, 14))
	nodes.guard_a = _enemy("MountainSentry", Vector3(-4, 0.9, -15), [], Vector3.FORWARD)
	nodes.patrol_b = _enemy("CliffPatrol", Vector3(0, 0.9, -25), [Vector3(0, 0.9, -25), Vector3(3, 0.9, -33)], Vector3.FORWARD)
	nodes.guard_c = _enemy("GateSentry", Vector3(2, 0.9, -59), [], Vector3.RIGHT)
	nodes.patrol_d = _enemy("HutPatrol", Vector3(15, 0.9, -55), [Vector3(15, 0.9, -55), Vector3(20, 0.9, -61)], Vector3.FORWARD)
	nodes.patrol_d.add_to_group(&"tutorial_target")
	var player := PLAYER.instantiate() as PlayerController
	player.name = "Player"
	player.position = Vector3(0, 0.9, 5)
	root.add_child(player)
	_add_actor_visual(player, Color("252939"))
	nodes.player = player
	for point in [Vector3(0, 0.9, -20), Vector3(0, 0.9, -40), Vector3(12, 0.9, -51), Vector3(12, 0.9, -67)]:
		var checkpoint := CheckpointArea.new()
		checkpoint.name = "Checkpoint%d" % int(-point.z)
		checkpoint.checkpoint_id = StringName(checkpoint.name)
		checkpoint.position = point
		var shape := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = Vector3(2, 2, 2)
		shape.shape = volume
		checkpoint.add_child(shape)
		root.add_child(checkpoint)
	_environment()
	return nodes


func _floor(label: String, center: Vector3, size: Vector3, material: StringName, color: Color) -> void:
	var floor := _wall(label, center, size, color)
	floor.set_meta(&"floor_material", material)


func _wall(label: String, center: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = center
	body.collision_layer = 1 | (1 << 4) | (1 << 5)
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.material_override = _material(color)
	body.add_child(mesh)
	return body


func _gate(label: String, center: Vector3, size: Vector3) -> void:
	var gate := _wall(label, center, size, VERMILION)
	nodes[StringName(label)] = gate


func _visual(label: String, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.position = center
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color)
	root.add_child(mesh)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	return material


func _hide(label: String, center: Vector3) -> HideSpot:
	var spot := HideSpot.new()
	spot.name = label
	spot.position = center
	spot.entry_radius = 1.3
	spot.storage_offset = Vector3(0, -0.1, -0.8)
	root.add_child(spot)
	return spot


func _light(label: String, center: Vector3, radius: float, can_extinguish: bool, color: Color) -> LightSource:
	var source := LightSource.new()
	source.name = label
	source.position = center
	source.gameplay_radius = radius
	source.extinguishable = can_extinguish
	source.interaction_radius = 1.6
	var render := OmniLight3D.new()
	render.light_color = color
	render.light_energy = 1.6 if can_extinguish else 1.0
	render.omni_range = radius
	render.shadow_enabled = true
	source.add_child(render)
	source.render_light = render
	root.add_child(source)
	if can_extinguish:
		_visual(label + "Housing", center + Vector3(0, -0.35, 0), Vector3(0.35, 0.7, 0.35), Color("bb8252"))
	return source


func _nav(label: String, area: Rect2) -> void:
	var region := NavigationRegion3D.new()
	region.name = label
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(area.position.x, 0.9, area.position.y), Vector3(area.end.x, 0.9, area.position.y), Vector3(area.end.x, 0.9, area.end.y), Vector3(area.position.x, 0.9, area.end.y)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	root.add_child(region)


func _enemy(label: String, center: Vector3, stops: Array, facing: Vector3) -> EnemyBase:
	var enemy := ENEMY.instantiate() as EnemyBase
	enemy.name = label
	enemy.position = center
	enemy.rotation.y = atan2(-facing.x, -facing.z)
	if not stops.is_empty():
		enemy.routine_type = &"ashigaru_patrol"
		var path := PatrolPath.new()
		path.name = label + "Route"
		path.position = center
		for index in stops.size():
			var stop := RoutineStop.new()
			stop.name = "Stop%d" % index
			stop.position = stops[index] - center
			stop.route_index = index
			stop.dwell_seconds = 4.0
			stop.facing_direction = facing if index == 0 else -facing
			path.add_child(stop)
		root.add_child(path)
		enemy.patrol_path_path = NodePath("../" + path.name)
	root.add_child(enemy)
	_add_actor_visual(enemy, Color("82775e"))
	return enemy


func _add_actor_visual(actor: Node3D, color: Color) -> void:
	if actor.get_node("Visual/Model") is ActorAnimation: return
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	mesh.mesh = capsule
	mesh.material_override = _material(color)
	actor.get_node("Visual/Model").add_child(mesh)
	var facing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.25, 0.15, 0.2)
	facing.mesh = box
	facing.position = Vector3(0, 0.65, -0.32)
	facing.material_override = _material(Color("a94332"))
	mesh.add_child(facing)


func _environment() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("101d2c")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("899cba")
	environment.ambient_light_energy = 0.4
	world.environment = environment
	root.add_child(world)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-50, -30, 0)
	moon.light_color = Color("a8bad0")
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	root.add_child(moon)
