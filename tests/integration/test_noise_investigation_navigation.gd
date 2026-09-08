extends GutTest


func test_guard_physically_investigates_ground_noise_on_synchronized_navmesh() -> void:
	var world := Node3D.new()
	add_child_autofree(world)
	var region := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-5, 0.9, -5), Vector3(5, 0.9, -5), Vector3(5, 0.9, 5), Vector3(-5, 0.9, 5)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	region.navigation_mesh = mesh
	world.add_child(region)
	var enemy: EnemyBase = preload("res://src/enemies/enemy_base.tscn").instantiate()
	enemy.position = Vector3(0, 0.9, 0)
	world.add_child(enemy)
	for frame in range(4): await get_tree().physics_frame
	var target := Vector3(3, 0, 0)
	NoiseEventSystem.emit(NoiseEvent.create(target, 6.0, Enums.NoiseKind.TOOL, null), get_tree())
	for frame in range(90): await get_tree().physics_frame
	assert_gt(enemy.position.x, 0.5, "a received stone sound must move the guard through real navigation")
	assert_lt(enemy.position.distance_to(target), Vector3(0, 0.9, 0).distance_to(target))
	for frame in range(360): await get_tree().physics_frame
	assert_ne(enemy.brain().current_state(), Enums.AlertState.SUSPICIOUS, "ground-level sound must allow arrival and dwell to finish")
