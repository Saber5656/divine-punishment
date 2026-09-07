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
