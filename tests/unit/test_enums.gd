extends GutTest


const EnumsScript := preload("res://src/core/enums.gd")
const NoiseEventScript := preload("res://src/core/noise_event.gd")
const AnomalyScript := preload("res://src/core/anomaly.gd")


func test_alert_state_values_are_fixed() -> void:
	assert_eq(EnumsScript.AlertState.UNAWARE, 0)
	assert_eq(EnumsScript.AlertState.SUSPICIOUS, 1)
	assert_eq(EnumsScript.AlertState.SEARCHING, 2)
	assert_eq(EnumsScript.AlertState.COMBAT, 3)
	assert_eq(EnumsScript.AlertState.RETURN, 4)


func test_noise_and_anomaly_factory_methods_set_required_fields() -> void:
	var source := Node.new()
	add_child(source)
	var noise := NoiseEventScript.create(Vector3.ONE, 6.0, EnumsScript.NoiseKind.TOOL, source)
	assert_eq(noise.position, Vector3.ONE)
	assert_eq(noise.radius, 6.0)
	assert_eq(noise.kind, EnumsScript.NoiseKind.TOOL)
	assert_eq(noise.source, source)
	source.free()

	var marker := Node3D.new()
	add_child(marker)
	var anomaly := AnomalyScript.create(EnumsScript.AnomalyKind.CORPSE, Vector3(1.0, 2.0, 3.0), marker, 3)
	assert_eq(anomaly.kind, EnumsScript.AnomalyKind.CORPSE)
	assert_eq(anomaly.severity, 3)
	marker.free()
