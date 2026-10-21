extends RefCounted
## Утверждённая автором петля MapTsukuri. Клетка плана = 3 метра.
const PLAN := "res://docs/art_direction/riverbank/layouts/A_loop.json"
const SOUTH := 18.0
const NORTH := -85.0
const EAST := 60.0
const START := Vector3(-6,0,-4.5)
const FINISH := Vector3(0,0,-63)
const PACKS := [Vector3(-36,0,-16.5),Vector3(33,0,-19.5),Vector3(34.5,0,-48)]
const POCKET := Vector3(-1.5,0,-24)
const DOCK := Vector3(-46.5,0,-4.5)
const BRIDGE := Vector3(-58,0,-6)
const ROUTE := [START, PACKS[0],Vector3(-34,0,-54),FINISH,PACKS[2],PACKS[1],START,POCKET,FINISH]
static var _regions: Array[Rect2] = []

static func regions() -> Array[Rect2]:
	if _regions.is_empty():
		var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
		for r: Array in plan.r:
			_regions.append(Rect2((float(r[0])-20)*3,(float(r[1])-25)*3,float(r[2])*3,float(r[3])*3))
	return _regions

static func shore_x(z: float) -> float:
	return -66.0 + sin(z*.047)*2.0

static func on_land(at: Vector2, margin := 0.0) -> bool:
	for delta in [Vector2.ZERO,Vector2(margin,0),Vector2(-margin,0),Vector2(0,margin),Vector2(0,-margin)]:
		var inside := false
		for area in regions():
			if area.has_point(at+delta):
				inside = true
				break
		if not inside: return false
	return true
