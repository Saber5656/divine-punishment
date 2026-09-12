class_name NarrativeText
extends RefCounted

static func oko_report(non_target_kills: int) -> String:
	var key := &"result.oko.quiet" if non_target_kills <= 0 else (&"result.oko.many" if non_target_kills >= 5 else &"result.oko.some")
	return GameText.get_text(key)
