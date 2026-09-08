class_name ResidenceLighting
extends Node3D

func _ready() -> void:
	_apply.call_deferred()

func _apply() -> void:
	var level := get_parent()
	var environment := WorldEnvironment.new()
	environment.name = "NightEnvironment"
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var atmosphere := ProceduralSkyMaterial.new()
	atmosphere.sky_top_color = Color(.012,.022,.045)
	atmosphere.sky_horizon_color = Color(.065,.08,.10)
	atmosphere.ground_bottom_color = Color(.012,.016,.018)
	atmosphere.ground_horizon_color = atmosphere.sky_horizon_color
	sky.sky_material = atmosphere
	settings.sky = sky
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.24,.31,.43)
	settings.ambient_light_energy = .07
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	settings.adjustment_enabled = true
	settings.adjustment_saturation = .65
	settings.adjustment_contrast = 1.12
	environment.environment = settings
	add_child(environment)
	for source in level.get_node("Markers/Lights").get_children():
		var light := source.render_light as OmniLight3D
		light.light_color = Color(1.0,.65,.32)
		light.light_energy = 2.2
		light.omni_range = source.gameplay_radius
		light.omni_attenuation = .9
		light.light_bake_mode = Light3D.BAKE_DISABLED
		light.shadow_enabled = true
	# Characters receive the baked probe field while remaining fully movable.
	for actor in level.get_node("Mission").npcs.values():
		_enable_probe_lighting(actor)
	_enable_probe_lighting(level.get_node("Player"))
	var overlay := StealthDebugOverlay.new()
	overlay.name = "StealthDebugOverlay"
	overlay.set_player(level.get_node("Player"))
	add_child(overlay)

func _enable_probe_lighting(actor: Node) -> void:
	for mesh in actor.find_children("*","MeshInstance3D",true,false):
		mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
