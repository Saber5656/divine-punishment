extends GutTest


func _valid() -> Dictionary:
	return {"version": 1, "scene": "res://mission.tscn", "id": "entry", "position": [1, 2, 3], "yaw": 0.0,
		"tools": [{"id": "smoke", "count": 2}], "selected_slot": 0, "area_alert": 3}


func test_json_roundtrip_and_cross_scene_rejection() -> void:
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(_valid()))
	assert_true(CheckpointSnapshot.is_valid(decoded, "res://mission.tscn"))
	assert_false(CheckpointSnapshot.is_valid(decoded, "res://different.tscn"))


func test_invalid_numbers_and_incomplete_snapshot_rejected() -> void:
	assert_false(CheckpointSnapshot.is_valid({}, "res://mission.tscn"))
	for value: Variant in [NAN, INF, "1", true, null, 100001.0]:
		var snapshot := _valid()
		snapshot["position"][0] = value
		assert_false(CheckpointSnapshot.is_valid(snapshot, "res://mission.tscn"))
	for value: Variant in [-1, 6, 1.5, NAN, "1"]:
		var snapshot := _valid()
		snapshot["area_alert"] = value
		assert_false(CheckpointSnapshot.is_valid(snapshot, "res://mission.tscn"))


func test_invalid_tool_count_and_slot_rejected() -> void:
	for value: Variant in [-1, 100001, 1.5, "1", null]:
		var snapshot := _valid()
		snapshot["tools"][0]["count"] = value
		assert_false(CheckpointSnapshot.is_valid(snapshot, "res://mission.tscn"))
	var invalid := _valid()
	invalid["selected_slot"] = 1
	assert_false(CheckpointSnapshot.is_valid(invalid, "res://mission.tscn"))
