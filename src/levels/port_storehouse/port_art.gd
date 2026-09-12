extends Node3D

const KIT := preload("res://assets/environment/port_modules.glb")
var coverage: Dictionary = {}
var before_contract: Dictionary = {}
var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _lamp_materials: Dictionary = {}

func _ready() -> void:
	_build.call_deferred()

func capture_contract(level: Node) -> Dictionary:
	var result := {}
	for path in ["Geometry","Markers","Population/PortNavigation","PortEnvironment"]:
		var root := level.get_node(path)
		var nodes := root.find_children("*","Node3D",true,false)
		nodes.append(root)
		for node in nodes:
			var key := String(level.get_path_to(node))
			if node is CollisionShape3D:
				var shape: Shape3D = node.shape
				var size: Variant = shape.size if shape is BoxShape3D else (shape.radius if shape is SphereShape3D else shape.get_class())
				result[key] = [node.transform,size,node.disabled]
			elif node is CollisionObject3D:
				result[key] = [node.transform,node.collision_layer,node.collision_mask]
				if node is LightSource: result[key].append([node.gameplay_radius,node.gameplay_intensity,node.extinguishable])
			elif node is Marker3D: result[key] = node.transform
			elif node is NavigationRegion3D:
				var mesh: NavigationMesh = node.navigation_mesh
				var nav: Array = [node.transform,mesh.vertices,node.navigation_layers]
				for index in mesh.get_polygon_count(): nav.append(mesh.get_polygon(index))
				result[key] = nav
	return result

func _build() -> void:
	var level := get_parent() as PortStorehouse
	before_contract = capture_contract(level)
	var kit := KIT.instantiate()
	for mesh: MeshInstance3D in kit.find_children("*","MeshInstance3D",true,false): _meshes[String(mesh.name)] = mesh.mesh
	kit.free()
	# Moon shadows reveal building depth; gameplay light parameters stay unchanged.
	for child in level.get_children():
		if child is WorldEnvironment: child.environment.ambient_light_energy = 0.16
		if child is DirectionalLight3D:
			child.shadow_enabled = true
			child.directional_shadow_max_distance = 130
	EventBus.light_extinguished.connect(_sync_lantern)
	EventBus.light_relit.connect(_sync_lantern)
	for body: StaticBody3D in level.get_node("Geometry").find_children("*","StaticBody3D",true,false):
		_replace(body)
	var water := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    float ripple=sin(world.x*3.1+world.z*0.8+TIME*1.2)*cos(world.z*4.0-TIME*0.7);
    ALBEDO=vec3(0.035,0.14,0.17)*(0.9+0.1*ripple);
    NORMAL_MAP=vec3(0.5+0.055*ripple,0.5+0.04*sin(world.z*3.0+TIME),1.0);
    METALLIC=0.25; ROUGHNESS=0.22; ALPHA=0.68;
}
"""
	water.shader = shader
	for surface in level.get_node("Geometry/Water").get_children():
		if surface is MeshInstance3D: surface.material_override = water
	# Shore piles do not obstruct any traversable corridor or the underwater ship route.
	for x in range(18,81,4): _piece("quay_pile",Transform3D(Basis.IDENTITY,Vector3(x,-0.9,57.8)),&"pier")
	for z in range(22,58,4): _piece("quay_pile",Transform3D(Basis.IDENTITY,Vector3(81.8,-0.9,z)),&"pier")
	for light: LightSource in level.get_node("PortEnvironment/Lights").get_children():
		for child in light.get_children():
			if child is MeshInstance3D: child.hide()
		_lantern(light)
	for point in [Vector3(85,1.16,53),Vector3(85.9,1.16,53),Vector3(90,1.16,47),Vector3(90.9,1.16,47)]:
		_piece("port_barrel",Transform3D(Basis.IDENTITY,point),&"ship")
	for point in [Vector3(91,1.16,53),Vector3(91,2.16,53),Vector3(90,1.16,53)]:
		_piece("port_crate",Transform3D(Basis.IDENTITY,point),&"ship")
	_piece("coiled_rope",Transform3D(Basis.IDENTITY,Vector3(84,1.16,48)),&"ship")
	for civilian: CivilianNPC in level.get_node("Population/Civilians").get_children():
		(civilian.get_node("Body") as MeshInstance3D).mesh = _meshes["port_worker"]
		coverage[&"workers"] = int(coverage.get(&"workers",0))+1
	for child in level.get_node("Mission").get_children():
		if child is StaticBody3D:
			for visual in child.get_children():
				if visual is MeshInstance3D: visual.mesh = _meshes["counting_desk"]
	var cargo := level.get_node("Mission/OpiumCargo") as RigidBody3D
	for child in cargo.get_children():
		if child is MeshInstance3D:
			var extent: Vector3 = (child.mesh as BoxMesh).size
			child.mesh = _meshes["port_crate"]
			child.material_override = null
			var bounds: AABB = child.mesh.get_aabb()
			child.scale = extent/bounds.size
			child.position = -bounds.get_center()*child.scale
	_flush()

func _replace(body: StaticBody3D) -> void:
	var shape: BoxShape3D
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D: shape = child.shape
	if shape == null: return
	var label := String(body.get_meta(&"art_role",body.name))
	var size := shape.size
	if label.begins_with("Boundary") or label == "Seabed":
		_tint(body,Color("15252c"))
		return
	if label == "ShipHull":
		_hide_meshes(body)
		_piece("cargo_ship_hull",body.transform,&"ship")
		_piece("cargo_ship_rig",body.transform,&"ship")
		return
	if label.begins_with("Cargo"):
		_hide_meshes(body)
		for x in range(2):
			for z in range(2):
				for y in range(2):
					var step := size/Vector3(2,2,2)
					var center := -size*0.5+step*Vector3(x+0.5,y+0.5,z+0.5)
					_fit_piece("port_crate",body.transform,center,step,&"cargo")
		return
	var vertical := size.y > 0.4 and minf(size.x,size.z) < 0.5
	if vertical:
		_hide_meshes(body)
		var house := label.begins_with("House")
		var module := "house_shoji_2m" if house else "storehouse_panel_2m"
		var area := &"house" if house else &"storehouses"
		var along_x := size.x >= size.z
		var width := maxf(size.x,size.z)
		var columns := maxi(1,ceili(width/2))
		var rows := maxi(1,ceili(size.y/2.4))
		var rotation := Basis.IDENTITY if along_x else Basis(Vector3.UP,PI/2)
		for x in columns:
			for y in rows:
				var fitted_size := Vector3(width/columns,size.y/rows,minf(size.x,size.z))
				var center := Vector3(-width/2+fitted_size.x*(x+0.5),-size.y/2+fitted_size.y*(y+0.5),0)
				_fit_piece(module,body.transform*Transform3D(rotation,Vector3.ZERO),center,fitted_size,area)
		return
	# Planked floors and tiled roof relief lie within the original solid top.
	var is_roof := body.get_parent().name == &"Roofs" and label.begins_with("Roof") or label.begins_with("HouseRoof") and not label.contains("Bridge")
	var module := "port_roof_2m" if is_roof else "quay_planks_2m"
	var area := &"roofs" if is_roof else (&"house" if label.begins_with("Counting") or label.begins_with("Crawl") else &"pier")
	_tint(body,Color("302920"))
	for child in body.get_children():
		if child is MeshInstance3D:
			child.scale.y = 0.5
			child.position.y = -size.y*0.25
	var columns := maxi(1,ceili(size.x/2))
	var rows := maxi(1,ceili(size.z/2))
	for x in columns:
		for z in rows:
			var fitted_size := Vector3(size.x/columns,minf(0.12,size.y),size.z/rows)
			var center := Vector3(-size.x/2+fitted_size.x*(x+0.5),size.y/2-fitted_size.y/2,-size.z/2+fitted_size.z*(z+0.5))
			_fit_piece(module,body.transform,center,fitted_size,area)

func _lantern(light: LightSource) -> void:
	var shade := MeshInstance3D.new()
	shade.name = "ArtLantern"
	shade.mesh = _meshes["port_lantern"]
	shade.position = Vector3.DOWN*0.45
	# Paper transmits the enclosed point light; its decorative shell is no occluder.
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(shade)
	var papers: Array[BaseMaterial3D] = []
	for index in shade.mesh.get_surface_count():
		var original := shade.mesh.surface_get_material(index) as BaseMaterial3D
		if original.resource_name == "Rice paper":
			var paper := original.duplicate() as BaseMaterial3D
			paper.emission = Color("ffb55c")
			paper.emission_energy_multiplier = 1.8
			shade.set_surface_override_material(index,paper)
			papers.append(paper)
	_lamp_materials[light] = papers
	_sync_lantern(light)
	coverage[&"lamps"] = int(coverage.get(&"lamps",0))+1

func _sync_lantern(light: LightSource) -> void:
	for paper: BaseMaterial3D in _lamp_materials.get(light,[]):
		paper.emission_enabled = light.is_on()

func _fit_piece(module: String,origin: Transform3D,center: Vector3,size: Vector3,area: StringName) -> void:
	var mesh: Mesh = _meshes[module]
	var bounds := mesh.get_aabb()
	var scale_basis := Basis.from_scale(size/bounds.size)
	_piece(module,origin*Transform3D(scale_basis,center-scale_basis*bounds.get_center()),area)

func _hide_meshes(body: Node) -> void:
	for child in body.get_children():
		if child is MeshInstance3D: child.hide()

func _tint(body: Node,color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	for child in body.get_children():
		if child is MeshInstance3D: child.material_override = material

func _piece(module: String,placement: Transform3D,area: StringName) -> void:
	# Spatial batches keep an entire port-sized floor from defeating frustum culling.
	var key := "%s_%d_%d"%[module,floori(placement.origin.x/16),floori(placement.origin.z/16)]
	if not _batches.has(key): _batches[key] = {"module":module,"transforms":[]}
	_batches[key].transforms.append(placement)
	coverage[area] = int(coverage.get(area,0))+1

func _flush() -> void:
	for key: String in _batches:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = _meshes[_batches[key].module]
		batch.instance_count = _batches[key].transforms.size()
		for index in batch.instance_count: batch.set_instance_transform(index,_batches[key].transforms[index])
		var mesh := MultiMeshInstance3D.new()
		mesh.name = key
		mesh.multimesh = batch
		add_child(mesh)
