class_name CampaignCatalog
extends RefCounted

static func missions() -> Array[MissionDefinition]:
	var result: Array[MissionDefinition] = []
	for night in range(1,11):
		result.append(load("res://data/missions/m%02d.tres" % night) as MissionDefinition)
	return result

static func is_unlocked(id: StringName, campaign: Dictionary) -> bool:
	for night in range(1,11):
		if String(id) == "m%02d" % night:
			return night <= int(campaign.get("unlocked_mission",1))
	return false

static func is_complete(campaign: Dictionary) -> bool:
	return campaign.get("mission_results",{}).has("m10")
