extends Node
var output := "user://audio-review"
func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): output=argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	var world := Node3D.new();add_child(world)
	var listener := AudioListener3D.new();world.add_child(listener);listener.make_current()
	var record := AudioEffectRecord.new()
	record.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,record)
	record.set_recording_active(true)
	print("AUDIO_LISTENER_ENABLED ",get_viewport().audio_listener_enable_3d)
	await get_tree().process_frame
	AudioDirector.play_effect(&"footstep_wood",Vector3(0,0,-1))
	await get_tree().create_timer(.65).timeout
	AudioDirector.play_bgm_set(&"normal")
	AudioDirector.set_ambience(&"night")
	await get_tree().create_timer(1.0).timeout
	AudioDirector.set_alert_tier(1)
	await get_tree().create_timer(2.0).timeout
	AudioDirector.set_alert_tier(2)
	await get_tree().create_timer(2.0).timeout
	for cue in [&"footstep_tatami",&"footstep_wood",&"footstep_gravel",&"footstep_shallow_water",&"tool_stone",&"tool_dart",&"tool_smoke",&"door"]:
		AudioDirector.play_effect(cue,Vector3(0,0,-1))
		await get_tree().create_timer(.45).timeout
	for i in range(24): AudioDirector.play_effect(&"footstep_wood",Vector3(0,0,-1))
	await get_tree().create_timer(.7).timeout
	AudioDirector.begin_assassination_audio(&"back")
	await get_tree().create_timer(.15).timeout
	AudioDirector.play_assassination_beat(&"back")
	await get_tree().create_timer(.5).timeout
	AudioDirector.restore_assassination_ambient()
	await get_tree().create_timer(1.0).timeout
	record.set_recording_active(false)
	var wav := record.get_recording()
	wav.save_to_wav(output.path_join("mix.wav"))
	var peak := 0.0
	var squared := 0.0
	for i in range(0,wav.data.size(),2):
		var value := float(wav.data.decode_s16(i))/32768.0
		peak=maxf(peak,absf(value));squared+=value*value
	var rms := sqrt(squared/maxf(1,wav.data.size()/2.0))
	var solo_peak := 0.0
	var channels := 2 if wav.stereo else 1
	for i in range(0,mini(wav.data.size(),int(.6*wav.mix_rate)*channels*2),2):
		solo_peak=maxf(solo_peak,absf(float(wav.data.decode_s16(i))/32768.0))
	var failures := 0 if peak>.01 and peak<.98 and rms>.002 and solo_peak>.01 else 1
	print("AUDIO_SMOKE ",JSON.stringify({"failures":failures,"peak":peak,"rms":rms,"seconds":wav.get_length(),"voices":24,"solo_effect_peak":solo_peak}))
	get_tree().quit(failures)
