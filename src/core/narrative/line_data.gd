class_name LineData
extends Resource

enum Style { NARRATION, DIALOGUE, INNER }

@export var speaker_key: StringName = &""
@export var text_key: StringName = &""
@export var style: Style = Style.NARRATION
