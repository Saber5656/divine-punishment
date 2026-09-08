class_name PerceptionProfile
extends RefCounted

## Opt-in wall-clock instrumentation, never enabled by normal gameplay.
static var enabled := false
static var total_usec := 0
static var calls := 0
static var frame_totals: Dictionary = {}
const MAX_FRAMES := 60000

static func record(usec: int) -> void:
	if not enabled: return
	var frame := Engine.get_process_frames()
	if frame_totals.size() >= MAX_FRAMES and not frame_totals.has(frame):
		enabled = false
		return
	var bounded := maxi(usec, 0)
	total_usec += bounded
	calls += 1
	frame_totals[frame] = int(frame_totals.get(frame, 0)) + bounded

static func reset() -> void:
	enabled = false
	total_usec = 0
	calls = 0
	frame_totals.clear()
