class_name NarrativeTotals
extends RefCounted

static func shura(nontarget_kills: int, civilian_kills: int, detections: int) -> int:
	return maxi(nontarget_kills,0) + maxi(civilian_kills,0)*3 + maxi(detections,0)/2

static func snapshot(stats: MissionStats) -> Dictionary:
	return {"nontarget_kills":maxi(stats.nontarget_kills,0), "civilian_kills":maxi(stats.civilian_kills,0), "detections":maxi(stats.detections,0)}
