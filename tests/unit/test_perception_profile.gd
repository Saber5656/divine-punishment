extends GutTest

func test_profile_accumulates_one_frame_and_is_opt_in() -> void:
	var path := "res://src/core/perception_profile.gd"
	assert_true(FileAccess.file_exists(path), "Opt-in perception profiling must exist")
	if not FileAccess.file_exists(path): return
	var profile = load(path)
	profile.reset()
	profile.record(20)
	assert_eq(profile.total_usec, 0)
	profile.enabled = true
	profile.record(20)
	profile.record(30)
	assert_eq(profile.total_usec, 50)
	assert_eq(profile.calls, 2)
	assert_eq(profile.frame_totals.size(), 1)
	profile.reset()
	assert_false(profile.enabled)
	assert_eq(profile.calls, 0)

class ScanMarker extends Node3D:
	var visits := 0
	func current_anomaly() -> Anomaly:
		visits += 1
		return null

func test_scan_budget_is_not_spent_revisiting_an_exhausted_group() -> void:
	var host := Node3D.new()
	add_child_autofree(host)
	var markers: Array = []
	for i in range(70):
		var marker := ScanMarker.new()
		host.add_child(marker)
		marker.add_to_group(&"anomaly_markers")
		markers.append(marker)
	var observer = load("res://src/enemies/enemy_base.tscn").instantiate()
	host.add_child(observer)
	observer.get_node("Perception")._scan_persistent_anomalies()
	var visited := 0
	for marker in markers: visited += marker.visits
	assert_eq(visited, 63, "64-node budget includes the observer once and 63 distinct markers")

func test_total_profile_includes_player_visibility_light_queries() -> void:
	var player = load("res://src/player/player.tscn").instantiate()
	add_child_autofree(player)
	PerceptionProfile.reset()
	PerceptionProfile.enabled = true
	player.get_node("Visibility").recompute()
	assert_eq(PerceptionProfile.calls, 1)
	PerceptionProfile.reset()
