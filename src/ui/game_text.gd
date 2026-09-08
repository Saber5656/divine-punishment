class_name GameText
extends RefCounted


static var _catalog: Dictionary = {}
static var _translation: Translation
static var _initialized := false


static func get_text(key: StringName) -> String:
	if not _initialized:
		_initialized = true
		var file := FileAccess.open("res://data/text/ja.csv", FileAccess.READ)
		if file != null:
			while not file.eof_reached():
				var row := file.get_csv_line()
				if row.size() == 2 and row[0] != "key":
					_catalog[StringName(row[0])] = row[1].replace("\\n", "\n")
		else:
			# Godot exports imported CSV translations and omits their raw source.
			var path := "res://data/text/ja.ja.translation"
			if ResourceLoader.exists(path):
				_translation = load(path) as Translation
	if _translation != null:
		var translated := _translation.get_message(key)
		return String(translated).replace("\\n", "\n") if not translated.is_empty() else String(key)
	return String(_catalog.get(key, String(key)))


static func binding_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		if event is InputEventMouseButton:
			var keys := {MOUSE_BUTTON_LEFT: &"input.mouse_left", MOUSE_BUTTON_RIGHT: &"input.mouse_right", MOUSE_BUTTON_MIDDLE: &"input.mouse_middle"}
			return get_text(keys[event.button_index]) if keys.has(event.button_index) else event.as_text()
	return String(action)


static func with_bindings(key: StringName) -> String:
	var result := get_text(key)
	for action in InputMap.get_actions():
		var placeholder := "{" + String(action) + "}"
		if result.contains(placeholder):
			result = result.replace(placeholder, binding_text(action))
	return result
