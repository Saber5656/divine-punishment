extends SceneTree

## Export only deterministic static visuals into an isolated editor bake project.
var destination := ""
var sequence := 0
var scene: Node3D
var unwrapped: Dictionary = {}
func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output-project="): destination=argument.trim_prefix("--output-project=")
	if destination.is_empty(): quit(2); return
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(destination.path_join("assets/lighting/m02"))
	var level=load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate()
	level.get_node("ResidenceArt").use_baked=false
	root.add_child(level)
	for frame in range(4): await process_frame
	level.process_mode=Node.PROCESS_MODE_DISABLED
	scene=Node3D.new();scene.name="BakedVisuals"
	for node in level.get_node("ResidenceArt").find_children("*","MultiMeshInstance3D",true,false):
		var transforms: Array[Transform3D]=[]
		for i in range(node.multimesh.instance_count):
			transforms.append(node.transform*node.multimesh.get_instance_transform(i))
			if transforms.size()==24:
				_export_mesh(node.multimesh.mesh,transforms,null)
				transforms.clear()
		if not transforms.is_empty(): _export_mesh(node.multimesh.mesh,transforms,null)
	for node in level.get_node("Geometry").find_children("*","MeshInstance3D",true,false):
		if not node.visible: continue
		# Water stays dynamic and is not included in the lightmapped static scene.
		if node.get_parent().name==&"WaterSurfaces": continue
		_export_mesh(node.mesh,[level.global_transform.affine_inverse()*node.global_transform],node.material_override)
	var moon=DirectionalLight3D.new();moon.name="Moon"
	moon.rotation_degrees=Vector3(-48,-35,0)
	moon.light_color=Color(.45,.57,.78)
	moon.light_energy=.28
	moon.light_bake_mode=Light3D.BAKE_STATIC
	moon.shadow_enabled=true
	scene.add_child(moon);moon.owner=scene
	var gi=LightmapGI.new();gi.name="LightmapGI"
	gi.quality=LightmapGI.BAKE_QUALITY_LOW
	gi.texel_scale=.5
	gi.max_texture_size=2048
	gi.bounces=2
	gi.generate_probes_subdiv=LightmapGI.GENERATE_PROBES_SUBDIV_4
	gi.environment_mode=LightmapGI.ENVIRONMENT_MODE_CUSTOM_COLOR
	gi.environment_custom_color=Color(.18,.23,.32)
	gi.environment_custom_energy=.08
	gi.use_denoiser=true
	scene.add_child(gi);gi.owner=scene
	var packed=PackedScene.new();packed.pack(scene)
	var result=ResourceSaver.save(packed,destination.path_join("assets/lighting/m02/baked_visuals.tscn"))
	var metadata={"mesh_count":sequence,"coverage":level.get_node("ResidenceArt").coverage,"texel_metres":.4,"source":"tools/lighting/prepare_lightmap_scene.gd","static_light":"Moon"}
	var file=FileAccess.open(destination.path_join("assets/lighting/m02/manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"  "));file.close()
	scene.free();level.free()
	print("LIGHTMAP_PREPARED ",sequence," meshes; save=",result)
	quit(result)
func _export_mesh(source: Mesh, transforms: Array[Transform3D], override_material: Material) -> void:
	# Unwrap each source once; put each repeated instance in its own UV2 cell.
	# Re-unwrapping a joined scene makes chart generation needlessly quadratic.
	var key := source.get_instance_id()
	if not unwrapped.has(key):
		var prototype := ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			prototype.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.surface_get_arrays(surface))
		var result := prototype.lightmap_unwrap(Transform3D.IDENTITY,.4)
		if result!=OK:
			printerr("LIGHTMAP_UNWRAP_FAILED ",sequence," ",result);quit(3);return
		unwrapped[key]=prototype
	var prototype: ArrayMesh=unwrapped[key]
	var mesh := ArrayMesh.new()
	var grid := ceili(sqrt(float(transforms.size())))
	for surface in range(prototype.get_surface_count()):
		var tool := SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(transforms.size()):
			var arrays := prototype.surface_get_arrays(surface)
			var uv2: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
			for vertex in range(uv2.size()): uv2[vertex]=(uv2[vertex]+Vector2(i%grid,i/grid))/float(grid)
			arrays[Mesh.ARRAY_TEX_UV2]=uv2
			var instance_mesh := ArrayMesh.new()
			instance_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			tool.append_from(instance_mesh,0,transforms[i])
		tool.set_material(override_material if override_material!=null else source.surface_get_material(surface))
		tool.commit(mesh)
	mesh.lightmap_size_hint=prototype.lightmap_size_hint*grid
	var path := "res://assets/lighting/m02/mesh_%03d.res"%sequence
	var disk := destination.path_join(path.trim_prefix("res://"))
	ResourceSaver.save(mesh,disk)
	mesh.take_over_path(path)
	var instance := MeshInstance3D.new();instance.name="Static_%03d"%sequence
	instance.mesh=mesh;instance.gi_mode=GeometryInstance3D.GI_MODE_STATIC
	scene.add_child(instance);instance.owner=scene
	sequence+=1
