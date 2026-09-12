extends Node3D

func _ready() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	EventBus.light_extinguished.connect(_sync_glow)
	EventBus.light_relit.connect(_sync_glow)
	for spec in [
		["GateLamp",Vector3(45,4.7,60),true],
		["HallWestLamp",Vector3(42.7,8.7,31),true],
		["HallEastLamp",Vector3(59.3,8.7,31),true],
		["CellLamp",Vector3(84,5.7,35),true],
		["BellLamp",Vector3(24.6,4.7,53),true],
		["LodgingLamp",Vector3(31,4.7,46),true],
		["CourtWestBrazier",Vector3(38,4.7,58),false],
		["CourtEastBrazier",Vector3(66,4.7,44),false]
	]:
		var light := LightSource.new()
		light.name = spec[0]
		light.position = spec[1]
		light.extinguishable = spec[2]
		light.set_meta(&"sheltered",spec[2])
		light.gameplay_radius = 6.0
		light.interaction_radius = 1.5
		# Authored roof cover protects lamps; outdoor braziers resist rain.
		light.rain_fragile = false
		var glow := OmniLight3D.new()
		glow.omni_range = light.gameplay_radius
		glow.light_color = Color("ffbd76")
		glow.light_energy = 0.8
		glow.shadow_enabled = true
		light.add_child(glow)
		light.render_light = glow
		var mesh := MeshInstance3D.new()
		mesh.name = "LampGlow"
		mesh.mesh = SphereMesh.new()
		(mesh.mesh as SphereMesh).radius = 0.12
		(mesh.mesh as SphereMesh).height = 0.24
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("dbb47d")
		material.emission = Color("ffbd76")
		mesh.material_override = material
		light.add_child(mesh)
		lights.add_child(light)
		_sync_glow(light)
	var search := Node3D.new()
	search.name = "Search"
	add_child(search)
	var zones := {
		&"gate":[Vector3(40,4.02,62),Vector3(54,4.02,62)],
		&"graveyard":[Vector3(18,4.02,66),Vector3(28,4.02,60)],
		&"bell":[Vector3(26,4.02,58),Vector3(30,4.02,54)],
		&"lodging":[Vector3(26,4.02,46),Vector3(30,4.02,48)],
		&"court":[Vector3(46,4.02,46),Vector3(62,4.02,42)],
		&"hall":[Vector3(44,8.02,26),Vector3(58,8.02,26)],
		&"cell":[Vector3(76,5.02,28),Vector3(82,5.02,36)]
	}
	for zone: StringName in zones:
		for index in range(2):
			var point := SearchPoint.new()
			point.name = String(zone)+str(index)
			point.area_id = zone
			point.search_order = index
			point.position = zones[zone][index]
			search.add_child(point)

func _sync_glow(light: LightSource) -> void:
	if not is_instance_valid(light) or not is_ancestor_of(light): return
	var material := (light.get_node("LampGlow") as MeshInstance3D).material_override as StandardMaterial3D
	material.emission_enabled = light.is_on()
