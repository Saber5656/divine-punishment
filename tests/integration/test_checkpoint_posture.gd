extends GutTest
var level: SamuraiResidence

func before_each() -> void:
	PlayerRetryFlow.pending_scene = ""
	level = load("res://src/levels/samurai_residence/samurai_residence.tscn").instantiate() as SamuraiResidence
	add_child_autofree(level)
	for frame in 5: await get_tree().physics_frame
	(level.get_node("Player") as PlayerController).global_position = Vector3(8,0.02,12)

func after_each() -> void:
	PlayerRetryFlow.pending_scene = ""


func test_crawl_checkpoint_restores_capsule_under_house_and_rejects_standing_before_mutation() -> void:
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	var entrance := level.get_node("Markers/CrawlEntrances/U1_WestWaterEntry") as CrawlEntrance
	player.global_position = entrance.outside_world_position()
	assert_true(player.try_enter_crawlspace(entrance))
	player.global_position = Vector3(58,0.02,19.5)
	var snapshot := CheckpointSnapshot.capture(player,level.scene_file_path,&"below_target")
	assert_true(player.state_machine.change_state(&"Crouch"))
	player.global_position = Vector3(8,0.02,8)
	assert_true(CheckpointSnapshot.restore(snapshot,player,level.scene_file_path))
	assert_eq(player.state_machine.current_state(),&"Crawlspace","Restore must retain crawl posture beneath the house")
	var capsule := player.get_node("CollisionShape3D") as CollisionShape3D
	assert_almost_eq((capsule.shape as CapsuleShape3D).height,0.7,0.001)
	var before := player.global_position
	var invalid := snapshot.duplicate(true)
	invalid["posture"] = "Ground"
	invalid["position"] = [58,0.02,20.5]
	assert_false(CheckpointSnapshot.restore(invalid,player,level.scene_file_path),"Standing cannot be restored through the crawl roof")
	assert_eq(player.global_position,before,"Invalid posture must not partially move the player")
	invalid["posture"] = "Ghost"
	assert_false(CheckpointSnapshot.is_valid(invalid,level.scene_file_path))


func test_legacy_checkpoint_without_posture_restores_ground_and_transient_capture_is_rejected() -> void:
	var player := level.get_node("Player") as PlayerController
	player.set_physics_process(false)
	var snapshot := CheckpointSnapshot.capture(player,level.scene_file_path,&"legacy")
	snapshot.erase("posture")
	assert_true(CheckpointSnapshot.is_valid(snapshot,level.scene_file_path))
	assert_true(player.state_machine.change_state(&"Crouch"))
	assert_true(CheckpointSnapshot.restore(snapshot,player,level.scene_file_path))
	assert_eq(player.state_machine.current_state(),&"Ground")
	assert_true(player.state_machine.change_state(&"Assassinate"))
	assert_true(CheckpointSnapshot.capture(player,level.scene_file_path,&"transient").is_empty())
