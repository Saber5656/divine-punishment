class_name HideoutScene
extends Resource

@export var id: StringName = &""
@export var background: Texture2D
@export var shura_threshold: int = -1
@export var lines_calm: Array[LineData] = []
@export var lines_blood: Array[LineData] = []
@export var outcome_flag: StringName = &""
@export var lines_success: Array[LineData] = []
@export var lines_failure: Array[LineData] = []
@export var ambience: AudioStream

func variant(shura: int) -> StringName:
	return &"blood" if shura_threshold >= 0 and shura > shura_threshold else &"calm"

func to_cutscene(shura: int,mission_flags: Dictionary = {}) -> CutsceneData:
	var data := CutsceneData.new()
	data.id = StringName("%s.%s" % [id, variant(shura)])
	var slide := SlideData.new()
	slide.image = background
	slide.lines = (lines_blood if variant(shura) == &"blood" else lines_calm).duplicate()
	if not outcome_flag.is_empty() and mission_flags.has(outcome_flag):
		slide.lines.append_array(lines_success if mission_flags[outcome_flag] else lines_failure)
	if ambience != null:
		slide.ambience = ambience.duplicate()
		if slide.ambience is AudioStreamWAV:
			var wav := slide.ambience as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	data.slides = [slide]
	return data
