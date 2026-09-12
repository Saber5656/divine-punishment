extends Node3D

var _moving: Dictionary = {}

func _ready() -> void:
	process_priority = 15
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	for x in [44,54]:
		for z in [72,60,48,36]: _lantern("Street%d_%d"%[x,z],Vector3(x,1.4,z))
	for spec in [["ShrineWest",Vector3(48,4.2,21)],["ShrineEast",Vector3(54,4.2,21)],["DaisWest",Vector3(80,4.2,30)],["DaisEast",Vector3(88,4.2,30)],["WestRoof",Vector3(28,5.4,58)],["EastRoof",Vector3(70,5.4,44)]]:
		_lantern(spec[0],spec[1])
	for name_ in ["Introduction","Stalls"]:
		_moving[name_] = _lantern(name_+"Lantern",Vector3.ZERO)
	sync_crowd_lights()
	var search := Node3D.new()
	search.name = "Search"
	add_child(search)
	var zones := {
		&"southstreet":[Vector3(40,0.02,76),Vector3(56,0.02,76)],
		&"weststreet":[Vector3(40,0.02,64),Vector3(40,0.02,46)],
		&"eaststreet":[Vector3(58,0.02,60),Vector3(58,0.02,44)],
		&"shrine":[Vector3(47,0.02,31),Vector3(55,0.02,31)],
		&"dais":[Vector3(96,0.02,34),Vector3(96,0.02,44)],
		&"rearalley":[Vector3(72,0.02,60),Vector3(72,0.02,24)],
		&"well":[Vector3(66,0.02,18),Vector3(72,0.02,18)]
	}
	for zone: StringName in zones:
		for index in range(2):
			var point := SearchPoint.new()
			point.name = String(zone)+str(index)
			point.area_id = zone
			point.search_order = index
			point.position = zones[zone][index]
			search.add_child(point)

func _physics_process(_delta: float) -> void:
	sync_crowd_lights()

func sync_crowd_lights() -> void:
	for name_: String in _moving:
		var crowd := get_parent().get_node("Population/Crowds/"+name_) as Node3D
		(_moving[name_] as Node3D).global_position = crowd.global_position+Vector3.UP*2.2

func _lantern(label: String,point: Vector3) -> LightSource:
	var light := LightSource.new()
	light.name = label
	light.position = point
	light.extinguishable = false
	light.rain_fragile = false
	light.gameplay_radius = 6.0
	light.gameplay_intensity = 0.55
	var glow := OmniLight3D.new()
	glow.omni_range = 6.0
	glow.light_color = Color("ffc879")
	glow.light_energy = 0.8
	glow.shadow_enabled = true
	light.add_child(glow)
	light.render_light = glow
	var shell := MeshInstance3D.new()
	shell.name = "Lantern"
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.5
	mesh.radial_segments = 12
	mesh.rings = 6
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("edba74")
	paper.emission_enabled = true
	paper.emission = Color("ffc879")
	mesh.material = paper
	shell.mesh = mesh
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(shell)
	get_node("Lights").add_child(light)
	return light
