@tool
extends EditorPlugin

## Run only in the isolated project prepared by bake_residence.py.
func _enter_tree() -> void:
	_run.call_deferred()
func _run() -> void:
	await get_tree().create_timer(3).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await get_tree().process_frame
	var path := "res://assets/lighting/m02/baked_visuals.tscn"
	EditorInterface.open_scene_from_path(path)
	var deadline := Time.get_ticks_msec()+30000
	while (EditorInterface.get_edited_scene_root()==null or EditorInterface.get_edited_scene_root().scene_file_path!=path) and Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
	var edited := EditorInterface.get_edited_scene_root()
	if edited==null or edited.scene_file_path!=path:
		_fail("Editor did not open bake scene");return
	var gi := edited.get_node("LightmapGI") as LightmapGI
	EditorInterface.edit_node(gi)
	await get_tree().process_frame
	for button in EditorInterface.get_base_control().find_children("*","Button",true,false):
		if button.text=="Bake Lightmaps" or (button.text.contains("ライトマップ") and button.text.contains("ベイク")):
			print("LIGHTMAP_BAKE_START")
			button.pressed.emit()
			for dialog in button.find_children("*","EditorFileDialog",true,false):
				if str(dialog.filters).contains("lmbake"):
					dialog.file_selected.emit("res://assets/lighting/m02/residence.lmbake")
			if gi.light_data==null or gi.light_data.get_user_count()==0:
				_fail("Bake did not produce populated LightmapGIData");return
			edited.get_node("Moon").shadow_enabled=false
			EditorInterface.save_scene()
			print("LIGHTMAP_BAKE_SUCCESS users=",gi.light_data.get_user_count())
			get_tree().quit();return
	_fail("Lightmap bake control not available")
func _fail(reason: String) -> void:
	printerr("LIGHTMAP_BAKE_FAILED ",reason)
	get_tree().quit(2)
