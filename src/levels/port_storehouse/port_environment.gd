extends Node3D

func _ready() -> void:
	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)
	for spec in [
		["PierWestLamp",Vector3(26,0.5,49),false,true],
		["PierMiddleLamp",Vector3(46,0.5,49),false,true],
		["PierBrazier",Vector3(60,0.5,52),false,false],
		["ShipBrazier",Vector3(74,0.5,49),false,false],
		["StorehouseLamp",Vector3(34,0.5,27),false,true],
		["HouseApproachLamp",Vector3(58,0.5,27),false,true],
		["CountingLamp",Vector3(65,3.5,12),true,true],
		["HouseLamp",Vector3(71,3.5,18),true,true],
	]:
		var light := LightSource.new()
		light.name = spec[0]
		light.position = spec[1]
		light.set_meta(&"indoor",spec[2])
		light.extinguishable = spec[3]
		light.gameplay_radius = 6
		light.interaction_radius = 1.5
		var glow := OmniLight3D.new()
		glow.omni_range = 6
		glow.light_color = Color("ffbe73")
		glow.light_energy = 0.7
		glow.shadow_enabled = true
		light.add_child(glow)
		light.render_light = glow
		var lantern := MeshInstance3D.new()
		lantern.mesh = SphereMesh.new()
		(lantern.mesh as SphereMesh).radius = 0.15
		(lantern.mesh as SphereMesh).height = 0.3
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("d49b50")
		lantern.material_override = material
		light.add_child(lantern)
		lights.add_child(light)
	var search := Node3D.new()
	search.name = "Search"
	add_child(search)
	var zones := {
		&"pier":[Vector3(30,0.02,48),Vector3(68,0.02,52)],
		&"storehouse_one":[Vector3(24,0.02,34),Vector3(24,0.02,40)],
		&"storehouse_two":[Vector3(48,0.02,34),Vector3(48,0.02,40)],
		&"storehouse_three":[Vector3(68,0.02,34),Vector3(68,0.02,40)],
		&"house":[Vector3(58,3.02,20),Vector3(70,3.02,16)],
		&"rear_dock":[Vector3(80,0.02,14),Vector3(80,0.02,18)],
	}
	for zone: StringName in zones:
		for index in range(2):
			var point := SearchPoint.new()
			point.name = String(zone)+str(index)
			point.area_id = zone
			point.search_order = index
			point.position = zones[zone][index]
			search.add_child(point)
