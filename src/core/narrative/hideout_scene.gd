class_name HideoutScene
extends Resource

@export var id: StringName = &""
@export var background: Texture2D
@export var shura_threshold: int = -1
@export var lines_calm: Array[LineData] = []
@export var lines_blood: Array[LineData] = []
@export var ambience: AudioStream

func variant(shura: int) -> StringName:
	return &"blood" if shura_threshold >= 0 and shura > shura_threshold else &"calm"

func to_cutscene(shura: int) -> CutsceneData:
	var data := CutsceneData.new()
	data.id = StringName("%s.%s" % [id, variant(shura)])
	var slide := SlideData.new()
	slide.image = background
	slide.lines = (lines_blood if variant(shura) == &"blood" else lines_calm).duplicate()
	if ambience != null:
		slide.ambience = ambience.duplicate()
		if slide.ambience is AudioStreamWAV:
			var wav := slide.ambience as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
	data.slides = [slide]
	return data
