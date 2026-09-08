extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var failures := 0
	var variants: Array = []
	var player := CutscenePlayer.new()
	add_child(player)
	for number in range(1, 9):
		var scene = load("res://data/narrative/hideout/h%d.tres" % number)
		for shura in [0, 100]:
			var data: CutsceneData = scene.to_cutscene(shura)
			if not player.play(data, true):
				failures += 1
				continue
			for line in data.slides[0].lines:
				await get_tree().process_frame
				await RenderingServer.frame_post_draw
				if player.subtitle.text != GameText.get_text(line.text_key) or player.subtitle.text == String(line.text_key): failures += 1
				player.advance()
			if player.active or get_tree().paused: failures += 1
			variants.append(String(data.id))
	print("HIDEOUT_SMOKE ", JSON.stringify({"failures":failures,"variants":variants}))
	get_tree().quit(failures)
