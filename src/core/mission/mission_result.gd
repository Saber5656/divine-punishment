class_name MissionResult
extends RefCounted


var score: int = 0
var rank: StringName = &"shoden"
var flags: Dictionary = {}


static func create(result_score: int, result_rank: StringName, result_flags: Dictionary) -> MissionResult:
	var result := MissionResult.new()
	result.score = result_score
	result.rank = result_rank
	result.flags = result_flags
	return result
