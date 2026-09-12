extends Node3D

const KIT := preload("res://assets/environment/temple_modules.glb")
var coverage: Dictionary = {}
var before_contract: Dictionary = {}
var _meshes: Dictionary = {}
var _batches: Dictionary = {}
var _lamp_materials: Dictionary = {}
var _umbrellas: Dictionary = {}
var _target_model: ActorAnimation

func _ready() -> void:
	process_priority = 20
	_build.call_deferred()

func capture_contract(level: Node) -> Dictionary:
	var result := {}
	for path in ["Geometry","Markers","Population/TempleNavigation","TempleEnvironment"]:
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
	var level := get_parent() as RainyTemple
	before_contract = capture_contract(level)
	var kit := KIT.instantiate()
	for mesh: MeshInstance3D in kit.find_children("*","MeshInstance3D",true,false): _meshes[String(mesh.name)] = mesh.mesh
	kit.free()
	for child in level.get_children():
		if child is WorldEnvironment:
			child.environment.ambient_light_energy = 0.28
			child.environment.background_color = Color("172832")
		if child is DirectionalLight3D:
			child.shadow_enabled = true
			child.directional_shadow_max_distance = 130
			child.light_color = Color("a8bfd0")
	for body: StaticBody3D in level.get_node("Geometry").find_children("*","StaticBody3D",true,false): _replace(body)
	# Structural trim stays below the supported roof surface and above actor height.
	for spec in [[Vector3(51,10.45,32),30.0,&"hall"],[Vector3(48,7.9,58),11.0,&"gate"],[Vector3(48,7.9,62),11.0,&"gate"],[Vector3(26,7.9,51.5),5.0,&"bell"],[Vector3(26,7.9,56.5),5.0,&"bell"],[Vector3(27,6.8,40),14.0,&"lodging"],[Vector3(27,6.8,52),14.0,&"lodging"],[Vector3(78,6.8,24),16.0,&"cell"],[Vector3(78,6.8,40),16.0,&"cell"]]:
		var width: float = spec[1]
		for index in ceili(width/2):
			var span := width/ceili(width/2)
			_piece("eave_trim_2m",Transform3D(Basis.from_scale(Vector3(span/2,1,1)),spec[0]+Vector3(-width/2+span*(index+0.5),0,0)),spec[2])
	var bell := level.get_node("Mission/BellBody") as MeshInstance3D
	bell.mesh = _meshes["bronze_bell"]
	bell.material_override = null
	for index in bell.mesh.get_surface_count():
		var original := bell.mesh.surface_get_material(index) as BaseMaterial3D
		if original.resource_name == "Patinated bell bronze":
			var bronze := original.duplicate() as BaseMaterial3D
			bronze.metallic = 0.35
			bell.set_surface_override_material(index,bronze)
	_hanger(Vector3(26,6.66,54),7.4)
	_piece("temple_beam_2m",Transform3D(Basis.from_scale(Vector3(2,1,1)),Vector3(26,7.4,54)),&"bell")
	var wheel := level.get_node("Geometry/Water/MillWheel") as MeshInstance3D
	wheel.mesh = _meshes["waterwheel"]
	_water(level)
	EventBus.light_extinguished.connect(_sync_lantern)
	EventBus.light_relit.connect(_sync_lantern)
	for light: LightSource in level.get_node("TempleEnvironment/Lights").get_children():
		_hide_meshes(light)
		_lantern(light)
	for npc: CivilianNPC in level.get_node("Mission/Retainers").get_children():
		var visual := npc.get_node("Body") as MeshInstance3D
		visual.mesh = _meshes["temple_retainer"]
		visual.material_override = null
		coverage[&"retainers"] = int(coverage.get(&"retainers",0))+1
	for monk: EnemyBase in level.get_node("Population/Monks").get_children(): _dress_monk(monk)
	_target_model = level.get_node("Population/Tetsusenbo/Visual/Model") as ActorAnimation
	for part in _target_model._weapon.get_children():
		if part is MeshInstance3D: part.hide()
	var weapon := MeshInstance3D.new()
	weapon.name = "TempleNaginata"
	weapon.mesh = _meshes["naginata"]
	weapon.rotation.x = -PI/2
	_target_model._weapon.add_child(weapon)
	coverage[&"target"] = 1
	_flush()
	for child in level.get_children():
		if child is WeatherPresentation: apply_rain_cover(child)

func _area(label: String) -> StringName:
	if label.begins_with("Gate"): return &"gate"
	if label.begins_with("Bell"): return &"bell"
	if label.begins_with("Lodging"): return &"lodging"
	if label.begins_with("Cell") or label.begins_with("Crawl"): return &"cell"
	if label.begins_with("Mill"): return &"mill"
	if label.begins_with("Hall"): return &"hall"
	if label.begins_with("Grave"): return &"graves"
	return &"court"

func _replace(body: StaticBody3D) -> void:
	var shape: BoxShape3D
	for child in body.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D: shape = child.shape
	if shape == null: return
	var label := String(body.get_meta(&"art_role",body.name))
	var size := shape.size
	var area := _area(label)
	if label in ["Land","Seabed"]:
		_tint(body,Color("26352f") if label == "Land" else Color("14282b"))
		return
	if label == "Boundary":
		_tint(body,Color("1e302e"))
		# Faceted cliff skins stay inside the enclosing wall, without new cover.
		var along_x := size.x >= size.z
		var width := maxf(size.x,size.z)
		var rotation := Basis.IDENTITY if along_x else Basis(Vector3.UP,PI/2)
		var columns := ceili(width/8)
		var rows := ceili(size.y/6)
		for x in columns:
			for y in rows:
				var fitted := Vector3(width/columns,size.y/rows,minf(size.x,size.z))
				_fit_piece("boundary_rock",body.transform*Transform3D(rotation,Vector3.ZERO),Vector3(-width/2+fitted.x*(x+0.5),-size.y/2+fitted.y*(y+0.5),0),fitted,&"boundary")
		return
	if label == "GraveStone":
		_hide_meshes(body)
		_fit_piece("grave_stone",body.transform,Vector3.ZERO,size,area)
		return
	if label.ends_with("Post") or label.ends_with("Pillar"):
		_hide_meshes(body)
		_fit_piece("temple_post",body.transform,Vector3.ZERO,size,area)
		return
	if label == "HallBeamBoard":
		_hide_meshes(body)
		_fit_piece("temple_beam_2m",body.transform,Vector3.ZERO,size,area)
		return
	if size.y > 0.4 and minf(size.x,size.z) < 0.5:
		_hide_meshes(body)
		_wall(body,size,"cedar_wall_2m",area)
		return
	var roof := body.get_parent().name == &"Roofs" and not label.contains("Bridge")
	var steps := label.contains("Steps") or label.contains("Stairs") or label.ends_with("Step") or label == "MillRise"
	var module := "temple_roof_2m" if roof else ("stone_tread_2m" if steps else "wet_paving_2m")
	var height := minf(0.10,size.y)
	_tint(body,Color("2f3932"))
	# Relieve the top inside its solid extent; never span the authored hatch holes.
	for child in body.get_children():
		if child is MeshInstance3D:
			child.scale.y = (size.y-height)/size.y
			child.position.y = -height/2
	var columns := maxi(1,ceili(size.x/2))
	var rows := maxi(1,ceili(size.z/(0.9 if steps else 2.0)))
	for x in columns:
		for z in rows:
			var fitted := Vector3(size.x/columns,height,size.z/rows)
			var center := Vector3(-size.x/2+fitted.x*(x+0.5),size.y/2-height/2,-size.z/2+fitted.z*(z+0.5))
			_fit_piece(module,body.transform,center,fitted,area)
	if roof: coverage[&"roofs"] = int(coverage.get(&"roofs",0))+columns*rows
	if steps: coverage[&"steps"] = int(coverage.get(&"steps",0))+columns*rows
	# The tall terrace is solid masonry, unlike the thin floors and ramps.
	if size.y > 0.5:
		for sign_ in [-1.0,1.0]:
			_panel_surface(body.transform*Transform3D(Basis(Vector3.UP,0 if sign_ > 0 else PI),Vector3(0,0,sign_*(size.z/2-0.08))),size.x,size.y,0.16,"stone_wall_2m",area)
			_panel_surface(body.transform*Transform3D(Basis(Vector3.UP,sign_*PI/2),Vector3(sign_*(size.x/2-0.08),0,0)),size.z,size.y,0.16,"stone_wall_2m",area)

func _wall(body: Node3D,size: Vector3,module: String,area: StringName) -> void:
	var along_x := size.x >= size.z
	var rotation := Basis.IDENTITY if along_x else Basis(Vector3.UP,PI/2)
	var origin := body.transform*Transform3D(rotation,Vector3.ZERO)
	var depth := minf(size.x,size.z)
	# Both rooms and exteriors see cedar framing, without changing the solid wall.
	for sign_ in [-1.0,1.0]:
		var face := Transform3D(Basis(Vector3.UP,0 if sign_ > 0 else PI),Vector3(0,0,sign_*depth/4))
		_panel_surface(origin*face,maxf(size.x,size.z),size.y,depth/2,module,area)

func _panel_surface(origin: Transform3D,width: float,height: float,depth: float,module: String,area: StringName) -> void:
	var columns := maxi(1,ceili(width/2))
	var rows := maxi(1,ceili(height/(2.0 if module == "stone_wall_2m" else 3.6)))
	for x in columns:
		for y in rows:
			var fitted := Vector3(width/columns,height/rows,depth)
			_fit_piece(module,origin,Vector3(-width/2+fitted.x*(x+0.5),-height/2+fitted.y*(y+0.5),0),fitted,area)

func _lantern(light: LightSource) -> void:
	var shade := MeshInstance3D.new()
	shade.name = "ArtLantern"
	shade.mesh = _meshes["temple_lantern" if light.extinguishable else "temple_brazier"]
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Brazier feet rest on the original floor (source centre is 1.6m above it).
	light.add_child(shade)
	if light.extinguishable:
		var ray := PhysicsRayQueryParameters3D.create(light.global_position+Vector3.UP*0.6,light.global_position+Vector3.UP*6,1)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty(): _hanger(light.position+Vector3.UP*0.53,float(hit.position.y))
	var papers: Array[BaseMaterial3D] = []
	for index in shade.mesh.get_surface_count():
		var original := shade.mesh.surface_get_material(index) as BaseMaterial3D
		if original.resource_name in ["Warm lantern paper","Brazier embers"]:
			var paper := original.duplicate() as BaseMaterial3D
			shade.set_surface_override_material(index,paper)
			papers.append(paper)
	_lamp_materials[light] = papers
	_sync_lantern(light)
	coverage[&"lamps"] = int(coverage.get(&"lamps",0))+1

func _hanger(bottom: Vector3,top_y: float) -> void:
	var height := top_y-bottom.y
	if height <= 0: return
	var mesh := MeshInstance3D.new()
	var rod := CylinderMesh.new()
	rod.top_radius = 0.015
	rod.bottom_radius = 0.015
	rod.height = height
	rod.radial_segments = 6
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("2a2922")
	rod.material = iron
	mesh.mesh = rod
	mesh.position = bottom+Vector3.UP*height/2
	add_child(mesh)

func _sync_lantern(light: LightSource) -> void:
	for paper: BaseMaterial3D in _lamp_materials.get(light,[]): paper.emission_enabled = light.is_on()

func _dress_monk(monk: EnemyBase) -> void:
	var model := monk.get_node("Visual/Model") as ActorAnimation
	for visual: MeshInstance3D in model._rig.find_children("*","MeshInstance3D",true,false):
		for index in visual.mesh.get_surface_count():
			var original := visual.mesh.surface_get_material(index) as BaseMaterial3D
			if original == null: continue
			if original.resource_name.contains("cloth"):
				var cloth := original.duplicate() as BaseMaterial3D
				cloth.albedo_color = Color("6d6250")
				visual.set_surface_override_material(index,cloth)
			if original.resource_name == "Weathered straw": visual.hide()
	var grip := BoneAttachment3D.new()
	grip.name = "TempleUmbrellaGrip"
	grip.bone_name = "hand_l"
	model._skeleton.add_child(grip)
	var umbrella := MeshInstance3D.new()
	umbrella.name = "TempleUmbrella"
	umbrella.mesh = _meshes["monk_umbrella"]
	grip.add_child(umbrella)
	_umbrellas[monk] = umbrella
	coverage[&"monks"] = int(coverage.get(&"monks",0))+1

func _process(_delta: float) -> void:
	for monk: EnemyBase in _umbrellas:
		var umbrella := _umbrellas[monk] as MeshInstance3D
		# Follow the animated hand, keeping the canopy upright as the wrist swings.
		umbrella.global_basis = monk.global_basis
		umbrella.visible = not monk.is_assassinated() and not monk.brain().is_incapacitated()
	if is_instance_valid(_target_model): _target_model._weapon.visible = not _target_model._actor.is_assassinated() and not _target_model._actor.brain().is_incapacitated()

func _water(level: Node) -> void:
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode blend_mix, cull_disabled;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    float ripple=sin(world.x*4.1+world.z*0.8+TIME*2.2)*cos(world.z*5.0-TIME*1.7);
    ALBEDO=vec3(0.035,0.12,0.14)*(0.9+0.1*ripple);
    NORMAL_MAP=vec3(0.5+0.045*ripple,0.5+0.04*sin(world.z*3.0+TIME),1.0);
    METALLIC=0.2; ROUGHNESS=0.26; ALPHA=0.68;
}
"""
	var water := ShaderMaterial.new()
	water.shader = shader
	for surface in level.get_node("Geometry/Water").get_children():
		if surface is MeshInstance3D and surface.mesh is PlaneMesh: surface.material_override = water

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
	# Spatial batches keep an entire temple floor from defeating frustum culling.
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

func apply_rain_cover(weather: WeatherPresentation) -> void:
	var rectangles: Array[Vector4] = []
	var heights: Array[float] = []
	var level := get_parent()
	for body: StaticBody3D in level.get_node("Geometry/Roofs").get_children():
		var role := String(body.get_meta(&"art_role",""))
		if not role.contains("Roof") or role.contains("Bridge"): continue
		var shape := body.get_child(0) as CollisionShape3D
		var size := (shape.shape as BoxShape3D).size
		var centre := body.global_position
		rectangles.append(Vector4(centre.x-size.x/2,centre.z-size.z/2,centre.x+size.x/2,centre.z+size.z/2))
		heights.append(centre.y+size.y/2)
	assert(rectangles.size() <= 16,"M4 precipitation roof uniform capacity exceeded")
	var count := rectangles.size()
	while rectangles.size() < 16:
		rectangles.append(Vector4.ZERO)
		heights.append(0.0)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/levels/rainy_temple/temple_rain.gdshader")
	material.set_shader_parameter("roof_count",count)
	material.set_shader_parameter("roof_rects",rectangles)
	material.set_shader_parameter("roof_heights",heights)
	# Each weather owner has its own QuadMesh; outdoor particles/audio stay intact.
	weather._particles.draw_pass_1.material = material
