class_name FestivalFireworks
extends Node3D

const MAX_ELAPSED := 86399.0
const PLAYER_ORIGIN_ABOVE_FLOOR := 0.9
@export var tuning: FestivalTuning = preload("res://data/tuning/festival.tres")
var _elapsed: float = 0.0
var _active: bool = false
var _cycle_index: int = -1
var _population: Node
var _roofs: Array[StaticBody3D] = []
var _particles: GPUParticles3D
var _flash: OmniLight3D
var _audio: AudioStreamPlayer3D
var _label: Label
static var _boom: AudioStreamWAV

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	add_to_group(&"mission_noise_masks")
	add_to_group(&"mission_visibility_effects")

func _ready() -> void:
	process_priority = 20
	_population = get_parent().get_node_or_null("Population")
	var roofs := get_parent().get_node_or_null("Geometry/Roofs")
	if roofs != null:
		for node in roofs.get_children():
			if node is StaticBody3D: _roofs.append(node)
	_build_presentation()
	synchronize_elapsed(0.0,false)

func _physics_process(delta: float) -> void:
	if is_instance_valid(_population): synchronize_elapsed(_population.schedule_elapsed())
	else: synchronize_elapsed(minf(_elapsed+delta,MAX_ELAPSED))

static func burst_active_at(time: float,period: float,duration: float) -> bool:
	if not is_finite(time) or time < 0.0 or not is_finite(period) or not is_finite(duration) or period <= 0.0 or duration <= 0.0 or duration >= period: return false
	return fmod(time,period) >= period-duration

func elapsed() -> float:
	return _elapsed

func masks_gameplay_noise() -> bool:
	return _active

func synchronize_elapsed(value: float,emit_events: bool = true) -> bool:
	if not is_finite(value) or value < 0.0 or value > MAX_ELAPSED or tuning == null: return false
	var period := tuning.firework_period_seconds
	var duration := tuning.firework_burst_seconds
	if not is_finite(period) or not is_finite(duration) or period <= 0.0 or duration <= 0.0 or duration >= period: return false
	var active := burst_active_at(value,period,duration)
	var cycle := int(value/period)
	var began := active and (not _active or cycle != _cycle_index)
	var ended := not active and _active
	_elapsed = value
	_active = active
	_cycle_index = cycle
	if _particles != null:
		if began:
			_particles.restart()
			_particles.emitting = true
		elif not _active: _particles.emitting = false
	if _flash != null: _flash.light_energy = 5.0 if _active else 0.0
	if _audio != null:
		if began and emit_events: _audio.play()
		elif not _active or not emit_events: _audio.stop()
	if _label != null:
		_label.text = GameText.get_text(&"m05.fireworks.active") if _active else GameText.get_text(&"m05.fireworks.countdown").format({"seconds":ceili(period-duration-fmod(value,period))})
		_label.modulate = Color("ffe096") if _active else Color("eee4cb")
	if emit_events and (began or ended): EventBus.mission_event.emit(EventBus.EV_FIREWORK_BURST,{"active":_active,"elapsed":value})
	return true

func visibility_multiplier_at(world_position: Vector3) -> float:
	if not _active or not world_position.is_finite(): return 1.0
	var feet := world_position-Vector3.UP*PLAYER_ORIGIN_ABOVE_FLOOR
	for body in _roofs:
		if not is_instance_valid(body): continue
		var collision := body.get_child(0) as CollisionShape3D
		if collision == null or not collision.shape is BoxShape3D: continue
		var local := (body.global_transform*collision.transform).affine_inverse()*feet
		var half := (collision.shape as BoxShape3D).size*0.5
		if absf(local.x) <= half.x+0.25 and absf(local.z) <= half.z+0.25 and absf(local.y-half.y) <= 0.3:
			return tuning.roof_visibility_multiplier
	return 1.0

func _build_presentation() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "Burst"
	_particles.position = Vector3(55,22,18)
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 160
	_particles.lifetime = tuning.firework_burst_seconds
	_particles.explosiveness = 1.0
	_particles.visibility_aabb = AABB(Vector3(-20,-20,-20),Vector3(40,40,40))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.5
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 6.0
	process.initial_velocity_max = 10.0
	process.gravity = Vector3(0,-4,0)
	_particles.process_material = process
	var spark := SphereMesh.new()
	spark.radius = 0.08
	spark.height = 0.16
	spark.radial_segments = 6
	spark.rings = 3
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color("ffd273")
	glow.emission_enabled = true
	glow.emission = Color("ff9b38")
	glow.emission_energy_multiplier = 3.0
	spark.material = glow
	_particles.draw_pass_1 = spark
	add_child(_particles)
	_flash = OmniLight3D.new()
	_flash.name = "Flash"
	_flash.position = Vector3(55,14,18)
	_flash.omni_range = 80.0
	_flash.light_color = Color("ffe0a0")
	_flash.light_energy = 0.0
	_flash.shadow_enabled = true
	add_child(_flash)
	_audio = AudioStreamPlayer3D.new()
	_audio.name = "Boom"
	_audio.position = _particles.position
	_audio.stream = _boom_stream()
	_audio.bus = &"SE"
	_audio.unit_size = 80.0
	_audio.max_distance = 180.0
	_audio.volume_db = -12.0
	add_child(_audio)
	var overlay := CanvasLayer.new()
	overlay.layer = 5
	add_child(overlay)
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.offset_left = -460
	_label.offset_right = -24
	_label.offset_top = 48
	_label.offset_bottom = 90
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.add_theme_font_override(&"font",preload("res://assets/fonts/NotoSerifJP.ttf"))
	_label.add_theme_font_size_override(&"font_size",18)
	overlay.add_child(_label)

static func _boom_stream() -> AudioStreamWAV:
	if _boom != null: return _boom
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(rate*2*2)
	var random := RandomNumberGenerator.new()
	random.seed = 189
	var low_noise := 0.0
	for sample in range(rate*2):
		var time := float(sample)/rate
		low_noise = lerpf(low_noise,random.randf_range(-1,1),0.08)
		var value := (sin(time*TAU*43)*0.35+low_noise*0.65)*exp(-time*3)*minf(time*180,1.0)
		samples.encode_s16(sample*2,int(clampf(value,-1,1)*32767))
	_boom = AudioStreamWAV.new()
	_boom.mix_rate = rate
	_boom.format = AudioStreamWAV.FORMAT_16_BITS
	_boom.data = samples
	return _boom
