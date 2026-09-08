extends Node

func _ready() -> void:
	var failures := 0
	var names: Array = []
	for id in [&"stone", &"dart", &"smoke", &"rope", &"naruko"]:
		var definition = load("res://data/tools/%s.tres" % id)
		var translated: String = definition.localized_name()
		if translated.is_empty() or translated == "tool.%s" % id: failures += 1
		names.append(translated)
	var main = load("res://src/ui/main.tscn").instantiate()
	add_child(main)
	main.get_node("SceneDirector").start_mission()
	for frame in range(10): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var hud_labels: Array = []
	for label in main.find_children("*", "Label", true, false):
		if label.text.contains(names[0]): hud_labels.append(label.text)
	if hud_labels.is_empty(): failures += 1
	print("LOCALIZED_CATALOG_SMOKE ",JSON.stringify({"failures":failures,"names":names,"hud_matches":hud_labels}))
	get_tree().quit(failures)
