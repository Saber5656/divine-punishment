extends GutTest

const SCENE := "res://src/npcs/temple_retainer.tscn"

func after_each() -> void:
	WeatherSystem.start(MissionDefinition.Weather.CLEAR)

func _retainer(parent: Node,point: Vector3) -> ProtectedNPC:
	assert_true(ResourceLoader.exists(SCENE),"Rescued retainers have ground evacuation behavior")
	if not ResourceLoader.exists(SCENE): return null
	var npc := load(SCENE).instantiate() as ProtectedNPC
	npc.position = point
	parent.add_child(npc)
	npc.set_physics_process(false)
	return npc

func test_captive_waits_until_freed_and_dead_captive_cannot_be_rescued() -> void:
	var npc := _retainer(self,Vector3(76,4.1,35))
	if npc == null: return
	autofree(npc)
	var start := npc.position
	npc.call("advance_escape",1.0)
	assert_eq(npc.position,start)
	assert_false(npc.get("escaped"))
	npc.receive_combat_damage(1)
	assert_false(npc.rescue())
	npc.call("advance_escape",1.0)
	assert_eq(npc.position,start)

func test_freed_retainer_uses_real_stairs_and_escapes_at_the_ground_entry() -> void:
	if not ResourceLoader.exists(SCENE):
		assert_true(false,"Rescued retainer implementation exists")
		return
	var level: Node3D = load("res://src/levels/rainy_temple/temple_population.tscn").instantiate()
	add_child_autofree(level)
	var npc := _retainer(level,Vector3(76,4.1,35))
	for frame in range(4): await get_tree().physics_frame
	assert_true(npc.rescue())
	assert_false(npc.rescue())
	assert_false(npc.get("escaped"),"Freeing is not teleporting to safety")
	for frame in range(900):
		npc.call("advance_escape",0.1)
		if npc.get("escaped"): break
		await get_tree().physics_frame
	assert_true(npc.get("escaped"),"Actual evacuation: "+str(npc.global_position))
	assert_lt((npc.global_position+Vector3.UP*0.9).distance_to(Vector3(12,0.02,88)),0.6)
	assert_false(npc.visible,"Escaped NPC leaves the playable scene")
	assert_eq(npc.receive_combat_damage(1),0,"Escaped NPC is safely offstage")

func test_freed_retainer_does_not_move_without_navigation_or_with_invalid_time() -> void:
	var npc := _retainer(self,Vector3(76,4.1,35))
	if npc == null: return
	autofree(npc)
	for frame in range(4): await get_tree().physics_frame
	assert_true(npc.rescue())
	var start := npc.position
	for delta in [0.25,-1.0,NAN,INF]: npc.call("advance_escape",delta)
	assert_eq(npc.position,start)
	assert_false(npc.get("escaped"))
