class_name GameplayPresentation
extends CanvasLayer

## A single non-blocking edge pulse; the centre remains readable during combat.
var alarm_strength := 0.0
var focus_strength := 0.0
var _alarm_elapsed := 1.0
var _surface: ColorRect
const ALARM_SECONDS := 0.8

func _ready() -> void:
	layer = 40
	_surface = ColorRect.new()
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
uniform float alarm = 0.0;
uniform float focus = 0.0;
void fragment() {
	vec2 edge = abs(UV - vec2(0.5)) * 2.0;
	float vignette = smoothstep(0.45, 1.0, max(edge.x, edge.y));
	float bars = smoothstep(0.92, 0.96, edge.y) * focus;
	vec3 tint = mix(vec3(0.015, 0.02, 0.025), vec3(0.52, 0.035, 0.02), alarm);
	COLOR = vec4(tint, min(0.75, vignette * alarm * 0.48 + bars * 0.68));
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	_surface.material = material
	add_child(_surface)
	EventBus.player_detected.connect(_detected)

func _detected() -> void:
	# Repeated detections in the same pulse cannot restart the sound or flash.
	if _alarm_elapsed < ALARM_SECONDS: return
	_alarm_elapsed = 0.0
	alarm_strength = 1.0
	AudioDirector.play_stinger(&"detection")
	_sync()

func set_focus(value: float) -> void:
	focus_strength = clampf(value, 0.0, 1.0)
	_sync()

func advance(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0: return
	_alarm_elapsed = minf(_alarm_elapsed + delta, ALARM_SECONDS)
	alarm_strength = pow(1.0 - _alarm_elapsed / ALARM_SECONDS, 2.0)
	_sync()

func _process(delta: float) -> void:
	advance(delta)

func _sync() -> void:
	if not is_instance_valid(_surface): return
	_surface.visible = alarm_strength > 0.0 or focus_strength > 0.0
	_surface.material.set_shader_parameter("alarm", alarm_strength)
	_surface.material.set_shader_parameter("focus", focus_strength)
