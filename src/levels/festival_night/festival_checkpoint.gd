extends RefCounted

static func actors(population: Node) -> Array:
	return population.important_actors()+population.doshin

static func crowds(population: Node) -> Array[CrowdHideSpot]:
	# Dead members are reparented beside these groups; they are not new routes.
	return [population.get_node("Crowds/Introduction"),population.get_node("Crowds/Stalls")]

static func entities(population: Node) -> Dictionary:
	var result := {}
	for npc: EnemyBase in actors(population): result[String(npc.name)] = npc
	for npc: CivilianNPC in population.civilians: result[String(npc.get_meta(&"mission_entity_id"))] = npc
	return result

static func capture(level: Node3D,screams: int) -> Dictionary:
	var population := level.get_node("Population")
	var schedule := {"elapsed":population.schedule_elapsed(),"prayer_stage":population._prayer_stage,"prayer_elapsed":population.prayer_elapsed(),"goals":{}}
	for npc: EnemyBase in population.important_actors():
		var stop := npc.current_routine_stop()
		schedule.goals[String(npc.name)] = {"position":_array(stop.global_position),"action":String(stop.routine_action),"facing":_array(stop.facing_direction)}
	var world := {"version":1,"schedule":schedule,"scream_count":screams,"npcs":{},"civilians":{},"crowds":{},"lights":{},"mission":MissionDirector.capture_checkpoint_state(entities(population))}
	for npc: EnemyBase in actors(population): world.npcs[String(npc.name)] = MissionNpcSnapshot.capture(npc)
	for npc: CivilianNPC in population.civilians:
		world.civilians[String(npc.get_meta(&"mission_entity_id"))] = {"position":_array(npc.global_position),"yaw":npc.global_rotation.y,"health":npc.health(),"cooldown":npc._scream_cooldown,"scan":npc._scan_elapsed}
	for crowd: CrowdHideSpot in crowds(population):
		world.crowds[String(crowd.name)] = {"distance":crowd._distance,"disrupted":crowd._disrupted}
	for light: LightSource in level.get_node("FestivalEnvironment/Lights").get_children(): world.lights[String(light.name)] = light.is_on()
	return world

static func is_valid(world: Dictionary,level: Node3D) -> bool:
	if world.get("version") != 1 or not CheckpointSnapshot._whole_number(world.get("scream_count"),0,1000000): return false
	var population := level.get_node("Population")
	if not world.get("schedule") is Dictionary or not _valid_schedule(world.schedule,population): return false
	for field in ["npcs","civilians","crowds","lights","mission"]:
		if not world.get(field) is Dictionary: return false
	var all_entities := entities(population)
	if not MissionDirector.checkpoint_state_is_valid(world.mission,all_entities): return false
	if world.npcs.size() != actors(population).size() or world.civilians.size() != population.civilians.size(): return false
	var dead_ids: Array[String] = []
	var non_target_dead := 0
	for npc: EnemyBase in actors(population):
		var row: Variant = world.npcs.get(String(npc.name))
		if not row is Dictionary or not MissionNpcSnapshot.is_valid(row,npc): return false
		if row.brain.route_stop_count != npc.patrol_path().ordered_stops().size(): return false
		if row.brain.kind == "dead":
			dead_ids.append(String(npc.name))
			if npc != population.target: non_target_dead += 1
	var civilian_dead := 0
	for npc: CivilianNPC in population.civilians:
		var id := String(npc.get_meta(&"mission_entity_id"))
		var row: Variant = world.civilians.get(id)
		if not row is Dictionary or not _vector_valid(row.get("position")) or not CheckpointSnapshot._finite_number(row.get("yaw")): return false
		if not CheckpointSnapshot._whole_number(row.get("health"),0,1) or not _bounded(row.get("cooldown"),5.0) or not _bounded(row.get("scan"),CivilianNPC.SCAN_INTERVAL): return false
		if int(row.health) == 0:
			civilian_dead += 1
			dead_ids.append(id)
	var groups := crowds(population)
	if world.crowds.size() != groups.size(): return false
	for crowd: CrowdHideSpot in groups:
		var row: Variant = world.crowds.get(String(crowd.name))
		if not row is Dictionary or not row.get("disrupted") is bool or not _bounded(row.get("distance"),crowd.route.get_baked_length()): return false
		if float(row.distance) >= crowd.route.get_baked_length(): return false
	var lights := level.get_node("FestivalEnvironment/Lights").get_children()
	if world.lights.size() != lights.size(): return false
	for light: LightSource in lights:
		# Festival lanterns have no gameplay operation that extinguishes them.
		if not world.lights.get(String(light.name)) is bool or not world.lights[String(light.name)]: return false
	var mission: Dictionary = world.mission
	for key in ["killed","neutralized","corpses","contacts"]:
		var seen := {}
		for id in mission.get(key,[]):
			if seen.has(id): return false
			seen[id] = true
	if mission.killed.size() != dead_ids.size(): return false
	for id in dead_ids:
		if id not in mission.killed: return false
	var target_dead: bool = world.npcs.Kurosawa.brain.kind == "dead"
	if target_dead != (int(mission.objective) > 0) or int(mission.target_kills) != int(target_dead): return false
	if mission.stats.civilian_kills != civilian_dead or mission.stats.nontarget_kills != non_target_dead: return false
	if mission.stats.one_strike != (target_dead and mission.all_assassinated): return false
	if mission.stats.side_objective_completed != (mission.completed and int(world.scream_count) == 0): return false
	for npc: EnemyBase in population.escorts:
		if world.npcs[String(npc.name)].get("escort_reacted",false) and not target_dead: return false
	return true

static func restore(world: Dictionary,level: Node3D) -> bool:
	if not is_valid(world,level): return false
	var population := level.get_node("Population")
	var schedule: Dictionary = world.schedule
	population._elapsed = float(schedule.elapsed)
	population._prayer_stage = int(schedule.prayer_stage)
	population._prayer_elapsed = float(schedule.prayer_elapsed)
	population._previous_phase = population.phase()
	population._previous_cycle = int(population.schedule_elapsed()/population.tuning.cycle_seconds())
	for npc: EnemyBase in actors(population):
		MissionNpcSnapshot.restore(world.npcs[String(npc.name)],npc)
		(npc.get_node("NavigationAgent3D") as NavigationAgent3D).target_position = npc.global_position
	for npc: EnemyBase in population.important_actors():
		var row: Dictionary = schedule.goals[String(npc.name)]
		population._goal(npc,_vector(row.position),StringName(row.action),_vector(row.facing))
	for crowd: CrowdHideSpot in crowds(population):
		var row: Dictionary = world.crowds[String(crowd.name)]
		crowd._distance = float(row.distance)
		crowd._disrupted = row.disrupted
		crowd.position = crowd.route.sample_baked(crowd._distance)
		for member in crowd.members:
			var saved: Dictionary = world.civilians[String(member.get_meta(&"mission_entity_id"))]
			var parent: Node = crowd if int(saved.health) > 0 else crowd.get_parent()
			if member.get_parent() != parent: member.reparent(parent,true)
			member.get_node("Body").visible = int(saved.health) == 0
	for npc: CivilianNPC in population.civilians:
		var row: Dictionary = world.civilians[String(npc.get_meta(&"mission_entity_id"))]
		npc.restore_checkpoint_health(int(row.health))
		npc._scream_cooldown = float(row.cooldown)
		npc._scan_elapsed = float(row.scan)
		npc.global_position = _vector(row.position)
		npc.global_rotation.y = float(row.yaw)
		npc.velocity = Vector3.ZERO
	for crowd: CrowdHideSpot in crowds(population): crowd._sync_instances()
	for light: LightSource in level.get_node("FestivalEnvironment/Lights").get_children(): light.set_extinguished(false)
	level.get_node("FestivalEnvironment").sync_crowd_lights()
	level.get_node("Fireworks").synchronize_elapsed(population.schedule_elapsed(),false)
	MissionDirector.restore_checkpoint_state(world.mission,entities(population))
	return true

static func _valid_schedule(schedule: Dictionary,population: Node) -> bool:
	if not _bounded(schedule.get("elapsed"),86399.0) or not CheckpointSnapshot._whole_number(schedule.get("prayer_stage"),0,3): return false
	if not _bounded(schedule.get("prayer_elapsed"),population.tuning.prayer_seconds): return false
	var phase: StringName = population.phase_at(float(schedule.elapsed),population.tuning.durations())
	var stage := int(schedule.prayer_stage)
	var prayer := float(schedule.prayer_elapsed)
	if phase != &"shrine" and (stage != 0 or prayer != 0.0): return false
	if stage < 2 and prayer != 0.0: return false
	if stage == 2 and prayer >= population.tuning.prayer_seconds: return false
	if stage == 3 and prayer != population.tuning.prayer_seconds: return false
	var expected: Array = []
	if phase == &"dais": expected = [[Vector3(84,3.02,32),"watch"],[Vector3(82,3.02,30),"guard"],[Vector3(86,3.02,30),"guard"]]
	elif phase == &"stalls":
		var local_time: float = fmod(float(schedule.elapsed),population.tuning.cycle_seconds())-population.tuning.dais_seconds-population.tuning.shrine_seconds
		var point := Vector3(48,0.02,56) if local_time < population.tuning.stalls_seconds/2 else Vector3(58,0.02,42)
		expected = [[point,"browse"],[point+Vector3.LEFT*2,"escort"],[point+Vector3.RIGHT*2,"escort"]]
	elif phase == &"shrine":
		if stage == 3: expected = [[Vector3(51,3.02,24),"leave_prayer"],[Vector3(48,3.02,24),"escort"],[Vector3(54,3.02,24),"escort"]]
		elif stage in [1,2]: expected = [[Vector3(51,3.02,17),"pray" if stage == 2 else "approach_shrine"],[Vector3(47,0.02,31),"wait_outside"],[Vector3(55,0.02,31),"wait_outside"]]
		else: expected = [[Vector3(51,3.02,17),"approach_shrine"],[Vector3(48,3.02,19),"escort"],[Vector3(54,3.02,19),"escort"]]
	else: return false
	if not schedule.get("goals") is Dictionary or schedule.goals.size() != 3: return false
	var important: Array = population.important_actors()
	for index in range(3):
		var row: Variant = schedule.goals.get(String(important[index].name))
		if not row is Dictionary or not _vector_valid(row.get("position")) or not _vector_valid(row.get("facing")) or row.get("action") != expected[index][1]: return false
		var facing := Vector3.FORWARD
		if phase == &"shrine" and stage in [1,2] and index > 0: facing = Vector3.LEFT if index == 1 else Vector3.RIGHT
		if not _vector(row.position).is_equal_approx(expected[index][0]) or not _vector(row.facing).is_equal_approx(facing): return false
	return true

static func _array(point: Vector3) -> Array:
	return [point.x,point.y,point.z]

static func _vector(value: Array) -> Vector3:
	return Vector3(value[0],value[1],value[2])

static func _vector_valid(value: Variant) -> bool:
	if not value is Array or value.size() != 3: return false
	for number in value:
		if not CheckpointSnapshot._finite_number(number) or absf(float(number)) > 10000.0: return false
	return true

static func _bounded(value: Variant,maximum: float) -> bool:
	return CheckpointSnapshot._finite_number(value) and float(value) >= 0.0 and float(value) <= maximum
