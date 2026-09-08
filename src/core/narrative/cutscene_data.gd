class_name CutsceneData
extends Resource

@export var id: StringName = &""
@export var slides: Array[SlideData] = []
@export var skippable: bool = true

func is_valid() -> bool:
	if id.is_empty() or slides.is_empty():
		return false
	for slide: SlideData in slides:
		if slide == null or slide.image == null or slide.lines.is_empty():
			return false
		if not is_finite(slide.duration_auto) or slide.duration_auto < 8.0 or slide.duration_auto > 15.0:
			return false
		for line: LineData in slide.lines:
			if line == null or line.text_key.is_empty() or line.style < 0 or line.style > LineData.Style.INNER:
				return false
			if line.style == LineData.Style.DIALOGUE and line.speaker_key.is_empty():
				return false
	return true
