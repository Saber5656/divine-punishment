class_name AudioPlayback
extends RefCounted

const CUES := [&"civilian_scream",&"footstep_world",&"footstep_wood",&"footstep_creaky_wood",&"footstep_tatami",&"footstep_gravel",&"footstep_soil",&"footstep_shallow_water",&"tool_stone",&"tool_dart",&"tool_smoke",&"tool_rope",&"tool_naruko",&"door",&"landing",&"combat_hit",&"assassination",&"detection",&"result",&"water",&"bell"]
const MAX_VOICES := 24
static var _streams: Dictionary = {}
var _music: Array[AudioStreamPlayer] = []
var _ambience: AudioStreamPlayer
var _stinger: AudioStreamPlayer
var _effects: Node3D
var _voices: Array[AudioStreamPlayer3D] = []
var _cursor := 0
var _gains := [0.0,0.0]
var _tier := 0
var _music_active := false
var _ambient_active := false
var _duck := 1.0
var _silenced := false

func _init(parent: Node) -> void:
	for bus in [&"BGM",&"SE"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,&"Master")
	var music := Node.new();music.name="Music";parent.add_child(music)
	for id in [&"unease",&"combat"]:
		var player := AudioStreamPlayer.new();player.name=id
		player.stream=_stream(id,true);player.bus=&"BGM";player.volume_db=-80
		music.add_child(player);_music.append(player)
	_ambience=AudioStreamPlayer.new();_ambience.name="Ambience"
	_ambience.stream=_stream(&"night",true);_ambience.bus=&"SE";_ambience.volume_db=-80
	parent.add_child(_ambience)
	_stinger=AudioStreamPlayer.new();_stinger.name="Stinger";_stinger.bus=&"SE"
	_stinger.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(_stinger)
	_effects=Node3D.new();_effects.name="Effects";parent.add_child(_effects)

func music_active(active: bool) -> void:
	_music_active=active
	if active:
		for layer in _music:
			if not layer.playing: layer.play()
func ambience_active(active: bool) -> void:
	_ambient_active=active
	if active and not _ambience.playing: _ambience.play()
func set_tier(tier: int) -> void:
	_tier=clampi(tier,0,2)
func silence(value: bool) -> void:
	_silenced=value
	if value: _duck=0.0;_apply_volumes()
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<0: return
	var goals := [1.0 if _tier==1 else (.35 if _tier==2 else 0.0),1.0 if _tier==2 else 0.0]
	for i in range(2): _gains[i]=move_toward(_gains[i],goals[i] if _music_active else 0.0,delta/.8)
	_duck=move_toward(_duck,0.0 if _silenced else 1.0,delta/.4)
	_apply_volumes()
func levels() -> Array:
	return _gains.duplicate()
func _apply_volumes() -> void:
	for i in range(2): _music[i].volume_db=linear_to_db(maxf(.65*_gains[i]*_duck,.0001))
	_ambience.volume_db=linear_to_db(maxf(.65*_duck if _ambient_active else 0.0,.0001))
func play_effect(cue: StringName, point: Vector3) -> bool:
	if cue not in CUES or not point.is_finite(): return false
	var voice: AudioStreamPlayer3D
	if _voices.size()<MAX_VOICES:
		voice=AudioStreamPlayer3D.new();voice.bus=&"SE";voice.max_distance=28.0
		voice.unit_size=3.0;_effects.add_child(voice);_voices.append(voice)
	else:
		voice=_voices[_cursor];_cursor=(_cursor+1)%MAX_VOICES
	voice.stop();voice.stream=_stream(cue,false);voice.global_position=point
	voice.volume_db=-5.0;voice.pitch_scale=1.0
	voice.play()
	return true
func play_stinger(cue: StringName) -> void:
	if cue not in CUES: cue=&"result"
	_stinger.stream=_stream(cue,false);_stinger.volume_db=-6;_stinger.play()
func _stream(id: StringName, loop: bool) -> AudioStreamWAV:
	if not _streams.has(id):
		var stream=load("res://assets/audio/%s.wav"%id).duplicate() as AudioStreamWAV
		if loop:
			stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin=0
			stream.loop_end=int(stream.get_length()*stream.mix_rate)
		_streams[id]=stream
	return _streams[id]
