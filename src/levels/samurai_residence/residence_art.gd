class_name ResidenceArt
extends Node3D

## Visual replacement only. The level remains the authority for solid surfaces.
const KIT := "res://assets/environment/residence_modules.glb"
const DECOR := "res://assets/environment/residence_decor.glb"
var coverage: Dictionary = {}
var before_contract: Dictionary = {}
var _meshes: Dictionary = {}
var _batches: Dictionary = {}

func _ready() -> void:
	call_deferred("_build")

func capture_contract(level: Node) -> Dictionary:
	var result: Dictionary = {}
	for root_name in ["Geometry", "Markers", "Navigation"]:
		var root := level.get_node_or_null(NodePath(root_name))
		if root == null: continue
		for node in root.find_children("*", "Node3D", true, false):
			var key := str(level.get_path_to(node))
			if node is CollisionShape3D:
				result[key] = [node.transform, _shape_data(node.shape), node.disabled]
			elif node is CollisionObject3D:
				result[key] = [node.transform, node.collision_layer, node.collision_mask]
			elif node is Marker3D:
				result[key] = node.transform
			elif node is NavigationRegion3D:
				result[key] = [node.transform, _navigation_data(node.navigation_mesh), node.navigation_layers]
	return result

func _shape_data(shape: Shape3D) -> Array:
	if shape is BoxShape3D: return ["box", shape.size]
	if shape is CapsuleShape3D: return ["capsule", shape.radius, shape.height]
	if shape is SphereShape3D: return ["sphere", shape.radius]
	if shape is CylinderShape3D: return ["cylinder", shape.radius, shape.height]
	if shape is ConvexPolygonShape3D: return ["convex", shape.points]
	return [shape.get_class()]

func _navigation_data(mesh: NavigationMesh) -> Array:
	if mesh == null: return []
	var data: Array = [mesh.get_vertices()]
	for i in range(mesh.get_polygon_count()): data.append(mesh.get_polygon(i))
	return data

func _build() -> void:
	var level := get_parent() as SamuraiResidence
	before_contract = capture_contract(level)
	for path in [KIT, DECOR]:
		var kit = load(path).instantiate()
		for part in kit.find_children("*", "MeshInstance3D", true, false):
			_meshes[String(part.name)] = part.mesh
		kit.free()
	for body in level.get_node("Geometry").find_children("*", "StaticBody3D", true, false):
		_replace_surface(body)
	# The selected garden beds are outside authored traversal and NPC paths.
	for point in [Vector3(11,-.9,36),Vector3(20,-.9,43),Vector3(91,-.9,20),Vector3(88,-.9,32),Vector3(7,-.9,56),Vector3(94,-.9,59)]:
		_piece("garden_pine", Transform3D(Basis.IDENTITY, point), &"garden")
	for point in [Vector3(17,-.9,36),Vector3(25,-.9,43),Vector3(91,-.9,29),Vector3(8,-.9,54)]:
		_piece("moss_stone", Transform3D(Basis.IDENTITY, point), &"garden")
	for light in level.get_node("Markers/Lights").get_children():
		var point: Vector3 = light.position
		point.y -= 1.0
		_piece("lantern", Transform3D(Basis.IDENTITY, point), &"garden")
	_flush()

func _replace_surface(body: StaticBody3D) -> void:
	var size: Vector3 = body.get_meta(&"graybox_bounds")
	var label := String(body.name)
	var material: StringName = body.get_meta(&"floor_material", &"")
	var module := ""
	var area: StringName = &""
	var vertical := size.y > 1.0
	if vertical:
		module = "fusuma_2m" if label.begins_with("ShoinNorthWall") else "plaster_2m"
		area = &"fusuma" if module == "fusuma_2m" else &"walls"
	elif label.contains("Roof") or label.contains("ClimbTop") or label.contains("BeamSupport"):
		# Crawl ceilings are flat timber; overhead platforms keep their exact top.
		module = "floor_2m" if label.begins_with("Crawl") else "roof_2m"
		area = &"roofs"
	elif material == &"tatami":
		module = "tatami_1x2"
		area = &"tatami"
	elif material in [&"wood", &"creaky_wood"]:
		module = "engawa_2m" if label.contains("Veranda") else "floor_2m"
		area = &"veranda"
	else:
		_treat_ground(body, material)
		coverage[&"garden"] = coverage.get(&"garden", 0) + 1
		return
	for child in body.get_children():
		if child is MeshInstance3D:
			child.visible = not vertical
			if not vertical:
				# A thin backing closes module joints without hiding their relief.
				child.scale.y = 0.1
				child.position.y = -size.y * 0.45
	var along_x := size.x >= size.z
	var width := size.x if along_x else size.z
	var count_x := maxi(1, ceili((width if vertical else size.x) / 2.0))
	var count_z := 1 if vertical else maxi(1, ceili(size.z / 2.0))
	for x in range(count_x):
		for z in range(count_z):
			var tile_size := size / Vector3(count_x, 1, count_z)
			var center := Vector3(-size.x*.5 + tile_size.x*(x+.5), 0, -size.z*.5 + tile_size.z*(z+.5))
			if vertical:
				tile_size = Vector3(width/count_x, size.y, minf(size.x,size.z))
				center = Vector3(-width*.5+tile_size.x*(x+.5),0,0) if along_x else Vector3(0,0,-width*.5+tile_size.x*(x+.5))
			var rotation := Basis(Vector3.UP, PI*.5) if vertical and not along_x else Basis.IDENTITY
			var mesh: Mesh = _meshes[module]
			var bounds := mesh.get_aabb()
			var fitted := Basis.from_scale(tile_size / bounds.size)
			var local := Transform3D(rotation * fitted, center - rotation * fitted * bounds.get_center())
			_piece(module, body.transform * local, area)

func _piece(module: String, transform_value: Transform3D, area: StringName) -> void:
	if not _batches.has(module): _batches[module] = []
	_batches[module].append(transform_value)
	coverage[area] = coverage.get(area, 0) + 1

func _flush() -> void:
	for module in _batches:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _meshes[module]
		batch.instance_count = _batches[module].size()
		for i in range(batch.instance_count): batch.set_instance_transform(i, _batches[module][i])
		var node := MultiMeshInstance3D.new()
		node.name = module
		node.multimesh = batch
		add_child(node)

func _treat_ground(body: StaticBody3D, material: StringName) -> void:
	for child in body.get_children():
		if not child is MeshInstance3D: continue
		var surface := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = """shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.2,0.2,0.18,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float grain=fract(sin(dot(floor(world.xz*45.0),vec2(12.9898,78.233)))*43758.5453);ALBEDO=base_color.rgb*(0.75+0.35*grain);ROUGHNESS=0.95;}
"""
		surface.shader = shader
		var color := Color(.19,.19,.17)
		if material == &"soil": color = Color(.13,.105,.07)
		elif material == &"gravel": color = Color(.29,.29,.26)
		elif material == &"shallow_water": color = Color(.10,.16,.15)
		surface.set_shader_parameter("base_color", color)
		child.material_override = surface
		child.position.y = {&"world": -0.006, &"gravel": 0.0, &"soil": 0.006, &"shallow_water": 0.009}.get(material, 0.0)
