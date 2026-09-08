extends Control

var player: CutscenePlayer

func _ready() -> void:
	theme = GameUi.theme()
	var background := ColorRect.new()
	background.color = Color("151e20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var menu := VBoxContainer.new()
	center.add_child(menu)
	for key in [&"cutscene.sample.title", &"cutscene.sample.note"]:
		var label := Label.new()
		label.text = GameText.get_text(key)
		menu.add_child(label)
	for entry in [[&"cutscene.replay", _replay], [&"cutscene.home", _home]]:
		var button := Button.new()
		button.text = GameText.get_text(entry[0])
		button.pressed.connect(entry[1])
		menu.add_child(button)
	player = CutscenePlayer.new()
	add_child(player)
	_replay()

func _replay() -> void:
	player.play(load("res://data/narrative/cutscenes/sample.tres"))

func _home() -> void:
	get_tree().change_scene_to_file("res://src/ui/main.tscn")
