class_name SlideData
extends Resource

@export var image: Texture2D
@export var lines: Array[LineData] = []
@export var ambience: AudioStream
@export_range(8.0, 15.0, 0.1) var duration_auto: float = 12.0
