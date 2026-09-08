class_name WeatherPresentation
extends Node3D

## Mission-owned precipitation and a bounded, simulation-time footprint trail.
var markers: Dictionary = {}
var friendly_sources: Dictionary = {}
var _particles: GPUParticles3D
var _audio: AudioStreamPlayer
var _sample_remaining := 0.0
var _mode: StringName = &""
var _print_mesh: CylinderMesh

func _ready() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "Precipitation"
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(Vector3(-16,-12,-16),Vector3(32,24,32))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_particles)
	_audio = AudioStreamPlayer.new()
	_audio.name = "RainAudio"
	var stream := load("res://assets/audio/rain.wav") as AudioStreamWAV
	if stream != null:
		stream = stream.duplicate()
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = stream.data.size()/2
	_audio.stream = stream
	_audio.bus = &"SE"
	_audio.volume_db = -14.0
	add_child(_audio)
	_print_mesh = CylinderMesh.new()
	_print_mesh.top_radius = 0.075
	_print_mesh.bottom_radius = 0.075
	_print_mesh.height = 0.003
	_print_mesh.radial_segments = 8
	var ink := StandardMaterial3D.new()
	ink.albedo_color = Color(0.18,0.23,0.28)
	_print_mesh.material = ink
	_refresh_weather()

func _process(delta: float) -> void:
	if _mode != WeatherSystem.current: _refresh_weather()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player != null: _particles.global_position = player.global_position + Vector3.UP * 7.0
	_sample_remaining -= delta
	if _sample_remaining > 0.0: return
	_sample_remaining = 0.1
	if WeatherSystem.current == &"snow" and player != null:
		_sample_actor(player)
		var enemies := get_tree().get_nodes_in_group(&"enemies")
		for index in mini(enemies.size(),32):
			var enemy := enemies[index] as Node3D
			if enemy != null:
				if friendly_sources.size() < 64: friendly_sources[enemy.get_instance_id()] = true
				_sample_actor(enemy)
	sync_footprints()

func _sample_actor(actor: Node3D) -> void:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*0.25,actor.global_position-Vector3.UP*0.4,1)
	if actor is CollisionObject3D: query.exclude = [actor.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		WeatherSystem.trail.sample(actor.get_instance_id(),actor.global_position,&"air",WeatherSystem.elapsed)
		return
	WeatherSystem.trail.sample(actor.get_instance_id(),hit.position,NoiseEmitter.floor_material_for(hit.collider,&"soil"),WeatherSystem.elapsed)

func sync_footprints() -> void:
	var alive: Dictionary = {}
	for entry in WeatherSystem.trail.entries:
		alive[entry.id] = true
		if markers.has(entry.id): continue
		var marker := AnomalyMarker.new()
		marker.active = false
		marker.anomaly_kind = Enums.AnomalyKind.FOOTPRINT
		marker.severity = 1
		add_child(marker)
		marker.global_position = entry.position + Vector3.UP*0.008
		var visual := MeshInstance3D.new()
		visual.mesh = _print_mesh
		visual.scale = Vector3(0.7,1.0,1.7)
		visual.rotation.y = atan2(entry.direction.x,entry.direction.z)
		marker.add_child(visual)
		marker.active = not friendly_sources.has(entry.source_id)
		markers[entry.id] = marker
	for id in markers.keys():
		if alive.has(id): continue
		var marker: AnomalyMarker = markers[id]
		marker.active = false
		marker.hide()
		marker.queue_free()
		markers.erase(id)

func _refresh_weather() -> void:
	_mode = WeatherSystem.current
	_particles.emitting = _mode != &"clear"
	if _mode == &"clear":
		_audio.stop()
		return
	var rain := _mode == &"rain"
	_particles.amount = 600 if rain else 300
	_particles.lifetime = 1.2 if rain else 6.0
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(10,0.5,10)
	process.direction = Vector3.DOWN
	process.spread = 4.0 if rain else 20.0
	process.initial_velocity_min = 10.0 if rain else 1.1
	process.initial_velocity_max = 13.0 if rain else 1.8
	process.gravity = Vector3(0,-4,0) if rain else Vector3(0,-0.15,0)
	_particles.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.012,0.35) if rain else Vector2(0.035,0.035)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_color = Color(0.65,0.75,0.9,0.45) if rain else Color(0.95,0.97,1,0.8)
	quad.material = material
	_particles.draw_pass_1 = quad
	if rain: _audio.play()
	else: _audio.stop()
