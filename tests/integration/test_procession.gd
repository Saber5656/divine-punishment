extends GutTest

func test_procession_visits_three_rests_and_exposes_target_only_when_stopped() -> void:
	var path := "res://src/npcs/procession_controller.gd"
	assert_true(FileAccess.file_exists(path))
	if not FileAccess.file_exists(path): return
	var target := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	add_child_autofree(target)
	var guards: Array[EscortGuard] = []
	for i in range(2):
		var guard := load("res://src/enemies/escort_guard.tscn").instantiate() as EscortGuard
		add_child_autofree(guard)
		guards.append(guard)
	var route := Curve3D.new()
	route.add_point(Vector3(0,0.9,0))
	route.add_point(Vector3(12,0.9,0))
	var procession = load(path).new()
	add_child_autofree(procession)
	procession.set_physics_process(false)
	procession.rest_seconds = 0.5
	assert_true(procession.configure(target,guards,route))
	assert_false(target.can_be_assassinated())
	var rests: Array = []
	var listener := func(id,payload):
		if id == &"procession_rest": rests.append(payload.index)
	EventBus.mission_event.connect(listener)
	var saw_target_outside := false
	for i in range(200):
		procession.advance(0.1)
		if procession.phase == &"resting":
			saw_target_outside = saw_target_outside or target.can_be_assassinated()
	assert_eq(rests,[0,1,2])
	assert_true(saw_target_outside)
	assert_eq(procession.phase,&"finished")
	assert_ne(guards[0].follow_offset,guards[1].follow_offset)
	EventBus.mission_event.disconnect(listener)

func test_riding_target_does_not_steal_melee_selection_from_a_guard() -> void:
	var player := load("res://src/player/player.tscn").instantiate() as PlayerController
	add_child_autofree(player)
	player.set_physics_process(false)
	var target := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	target.position = Vector3(0,0,-0.5)
	add_child_autofree(target)
	var guard := load("res://src/enemies/escort_guard.tscn").instantiate() as EscortGuard
	guard.position = Vector3(0,0,-1)
	add_child_autofree(guard)
	target.inside_palanquin = true
	assert_eq(player.combat._nearest_enemy(),guard)
	target.inside_palanquin = false
	assert_eq(player.combat._nearest_enemy(),target)

func test_procession_formation_turns_with_route_heading() -> void:
	var target := load("res://src/enemies/target_npc.tscn").instantiate() as TargetNpc
	add_child_autofree(target)
	var guard := load("res://src/enemies/escort_guard.tscn").instantiate() as EscortGuard
	add_child_autofree(guard)
	var procession := ProcessionController.new()
	add_child_autofree(procession)
	procession.set_physics_process(false)
	var route := Curve3D.new()
	route.add_point(Vector3.ZERO)
	route.add_point(Vector3(10,0,0))
	route.add_point(Vector3(10,0,-10))
	var guards: Array[EscortGuard] = [guard]
	assert_true(procession.configure(target,guards,route))
	assert_lt(guard.follow_offset.x,0.0,"Guard trails a carriage heading east")
	var initial := guard.follow_offset
	procession.rest_seconds = 0.1
	for step in range(55): procession.advance(0.25)
	assert_ne(guard.follow_offset,initial)
	assert_gt(guard.follow_offset.z,0.0,"Guard trails after the route turns north")
