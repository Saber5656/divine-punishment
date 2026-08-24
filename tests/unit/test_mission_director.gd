extends GutTest


const MissionDirectorScript := preload("res://src/autoload/mission_director.gd")


func test_mission_director_contract_uses_mission_resource_types() -> void:
	var definition := MissionDefinition.new()
	var objective := ObjectiveData.new()
	definition.objectives = [objective]

	var director := MissionDirectorScript.new()
	director.start_mission(definition)
	var current: ObjectiveData = director.current_objective()
	var stats: MissionStats = director.stats()
	var result: MissionResult = director.build_result()

	assert_eq(current, objective)
	assert_true(stats is MissionStats)
	assert_true(result is MissionResult)
	director.free()
