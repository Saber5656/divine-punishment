extends GutTest

func after_each() -> void:
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)

func test_rain_reduces_real_footstep_and_vision_and_extinguishes_fragile_light() -> void:
	WeatherSystem.start(MissionDefinition.Weather.RAIN)
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	var emitter: NoiseEmitter = player.get_node("NoiseEmitter")
	var event := emitter.emit_footstep(Enums.Stance.WALK,&"wood")
	assert_eq(event.radius,NoiseEmitter.footstep_radius(Enums.Stance.WALK,&"wood",Tuning.movement())*0.5)
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	var perception = enemy.get_node("Perception")
	assert_true(perception.has_method(&"effective_view_distance"))
	if perception.has_method(&"effective_view_distance"):
		assert_almost_eq(perception.effective_view_distance(),perception.perception_config.view_distance_m*0.8,0.001)
	var light := LightSource.new()
	light.set("rain_fragile",true)
	add_child_autofree(light)
	assert_false(light.is_on())
	WeatherSystem.set_weather(&"clear")
	assert_false(light.is_on(),"Rain ending does not magically relight a lamp")

func test_snow_presentation_registers_bounded_expiring_footprint_anomalies() -> void:
	var script_path := "res://src/stealth/weather_presentation.gd"
	assert_true(FileAccess.file_exists(script_path))
	if not FileAccess.file_exists(script_path): return
	WeatherSystem.start(MissionDefinition.Weather.SNOW)
	var presentation = load(script_path).new()
	add_child_autofree(presentation)
	presentation.set_process(false)
	WeatherSystem.trail.sample(1,Vector3.ZERO,&"snow",0.0)
	WeatherSystem.trail.sample(1,Vector3(1,0,0),&"snow",0.0)
	presentation.sync_footprints()
	assert_eq(presentation.markers.size(),1)
	var marker: AnomalyMarker = presentation.markers.values()[0]
	assert_eq(marker.current_anomaly().kind,Enums.AnomalyKind.FOOTPRINT)
	assert_almost_eq(marker.global_position.x,0.8,0.001)
	WeatherSystem.advance(90.0)
	presentation.sync_footprints()
	assert_eq(presentation.markers.size(),0)
	assert_false(marker.active)

func test_guard_investigates_generated_player_track() -> void:
	WeatherSystem.start(MissionDefinition.Weather.SNOW)
	var enemy = load("res://src/enemies/enemy_base.tscn").instantiate()
	add_child_autofree(enemy)
	enemy.set_physics_process(false)
	var brain: EnemyBrain = enemy.get_node("Brain")
	brain.set_physics_process(false)
	var presentation := WeatherPresentation.new()
	add_child_autofree(presentation)
	presentation.set_process(false)
	WeatherSystem.trail.sample(1,Vector3(0,0,-2),&"snow",0.0)
	WeatherSystem.trail.sample(1,Vector3(0,0,-3),&"snow",0.0)
	presentation.sync_footprints()
	brain._physics_process(0.016)
	assert_eq(brain.alert_state(),Enums.AlertState.SUSPICIOUS)
	assert_almost_eq(brain.investigation_target().z,-2.8,0.001)

func test_friendly_tracks_are_visible_without_triggering_investigation() -> void:
	WeatherSystem.start(MissionDefinition.Weather.SNOW)
	var presentation := WeatherPresentation.new()
	add_child_autofree(presentation)
	presentation.set_process(false)
	assert_true("friendly_sources" in presentation)
	if not "friendly_sources" in presentation: return
	presentation.friendly_sources[2] = true
	WeatherSystem.trail.sample(2,Vector3.ZERO,&"snow",0.0)
	WeatherSystem.trail.sample(2,Vector3(1,0,0),&"snow",0.0)
	presentation.sync_footprints()
	assert_eq(presentation.markers.size(),1)
	var marker: AnomalyMarker = presentation.markers.values()[0]
	assert_true(marker.visible)
	assert_false(marker.active)

func test_guard_walks_towards_visible_snow_track_on_navigation_mesh() -> void:
	WeatherSystem.start(MissionDefinition.Weather.SNOW)
	var world := Node3D.new()
	add_child_autofree(world)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-5,0.9,-5),Vector3(5,0.9,-5),Vector3(5,0.9,5),Vector3(-5,0.9,5)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var enemy: EnemyBase = load("res://src/enemies/enemy_base.tscn").instantiate()
	enemy.position = Vector3(0,0.9,0)
	world.add_child(enemy)
	for frame in range(4): await get_tree().physics_frame
	var presentation := WeatherPresentation.new()
	world.add_child(presentation)
	presentation.set_process(false)
	WeatherSystem.trail.sample(1,Vector3(0,0,-2),&"snow",0.0)
	WeatherSystem.trail.sample(1,Vector3(0,0,-3),&"snow",0.0)
	presentation.sync_footprints()
	for frame in range(90): await get_tree().physics_frame
	assert_lt(enemy.position.z,-0.5,"Footprint investigation must physically move the guard")
