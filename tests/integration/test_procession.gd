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
