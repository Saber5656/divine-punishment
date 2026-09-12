extends RefCounted

static func entities(duties: Node3D,retainers: Dictionary) -> Dictionary:
	var result := retainers.duplicate()
	for actor: EnemyBase in duties.actors(): result[String(actor.name)] = actor
	return result

static func capture(population: Node3D,duties: Node3D,retainers: Dictionary,side_failed: bool) -> Dictionary:
	var target := population.get_node("Tetsusenbo") as Tetsusenbo
	var world := {"version":1,"elapsed":population.schedule_elapsed(),"duties":duties.capture_checkpoint_state(),"side_failed":side_failed,"counter_remaining":target.counter_remaining(),"npcs":{},"retainers":{},"mission":MissionDirector.capture_checkpoint_state(entities(duties,retainers))}
	for actor: EnemyBase in duties.actors(): world.npcs[String(actor.name)] = MissionNpcSnapshot.capture(actor)
	for identity: String in retainers: world.retainers[identity] = retainers[identity].capture_checkpoint_state()
	return world

static func is_valid(world: Dictionary,population: Node3D,duties: Node3D,retainers: Dictionary) -> bool:
	if world.get("version") != 1 or not world.get("side_failed") is bool: return false
	if not _bounded(world.get("elapsed"),86399.0) or not _bounded(world.get("counter_remaining"),Tetsusenbo.COUNTER_WINDOW): return false
	if not world.get("duties") is Dictionary or not duties.checkpoint_state_is_valid(world["duties"],float(world["elapsed"])): return false
	var actors: Array = duties.actors()
	if not world.get("npcs") is Dictionary or world["npcs"].size() != actors.size(): return false
	if not world.get("retainers") is Dictionary or world["retainers"].size() != retainers.size(): return false
	if not world.get("mission") is Dictionary or not MissionDirector.checkpoint_state_is_valid(world["mission"],entities(duties,retainers)): return false
	for actor: EnemyBase in actors:
		var row: Variant = world["npcs"].get(String(actor.name))
		if not row is Dictionary or not MissionNpcSnapshot.is_valid(row,actor): return false
		if row["brain"]["route_stop_count"] != actor.patrol_path().ordered_stops().size(): return false
	var any_dead := false
	var all_escaped := true
	for identity: String in retainers:
		var row: Variant = world["retainers"].get(identity)
		if not row is Dictionary or not retainers[identity].checkpoint_state_is_valid(row): return false
		any_dead = any_dead or int(row["health"]) == 0
		all_escaped = all_escaped and row["escaped"]
	if world["side_failed"] != any_dead or world["mission"]["stats"]["side_objective_completed"] != (all_escaped and not any_dead): return false
	var dead: bool = world["npcs"][String(population.target.name)]["brain"]["kind"] == "dead"
	return dead == (int(world["mission"]["objective"]) > 0) and int(world["mission"]["target_kills"]) == int(dead)

static func restore(world: Dictionary,population: Node3D,duties: Node3D,retainers: Dictionary) -> bool:
	if not is_valid(world,population,duties,retainers): return false
	population.restore_schedule_elapsed(float(world["elapsed"]))
	duties.restore_checkpoint_state(world["duties"])
	for actor: EnemyBase in duties.actors():
		MissionNpcSnapshot.restore(world["npcs"][String(actor.name)],actor)
		# Discard a route calculated from the post-checkpoint position.
		(actor.get_node("NavigationAgent3D") as NavigationAgent3D).target_position = actor.global_position
	for identity: String in retainers: retainers[identity].restore_checkpoint_state(world["retainers"][identity])
	(population.target as Tetsusenbo).restore_counter_remaining(float(world["counter_remaining"]))
	MissionDirector.restore_checkpoint_state(world["mission"],entities(duties,retainers))
	return true

static func _bounded(value: Variant,maximum: float) -> bool:
	return CheckpointSnapshot._finite_number(value) and float(value) >= 0.0 and float(value) <= maximum
