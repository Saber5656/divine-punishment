extends Control


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	$Center/Choices/Restart.pressed.connect(_restart)
	$Center/Choices/Quit.pressed.connect(func() -> void: get_tree().quit())
	$Center/Choices/Restart.grab_focus()


func _restart() -> void:
	var path := PlayerRetryFlow.abandoned_scene
	if path.is_empty():
		path = "res://src/levels/samurai_residence/samurai_residence.tscn"
	GameState.area_alert_level = 0
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		$Center/Choices/Title.text = "任務を読み込めませんでした"
