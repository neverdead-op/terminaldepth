extends RefCounted
## Общая планировка открытого берега. ROUTE — проверочный обход, а не границы дороги.
const SOUTH := 44.0
const NORTH := -176.0
const EAST := 68.0

static func shore_x(z: float) -> float:
	return -66.0 + sin(z * 0.047) * 8.0 + sin(z * 0.11) * 2.5

static func on_land(at: Vector2, margin := 0.0) -> bool:
	return at.y > NORTH + margin and at.y < SOUTH - margin and at.x > shore_x(at.y) + margin and at.x < EAST - margin
const ROUTE := [Vector3(-20,0,12), Vector3(-20,0,-4), Vector3(-38,0,-18),
	Vector3(-38,0,-30), Vector3(-18,0,-44), Vector3(6,0,-44),
	Vector3(22,0,-58), Vector3(22,0,-76), Vector3(2,0,-90),
	Vector3(-22,0,-90), Vector3(-30,0,-108), Vector3(-30,0,-124),
	Vector3(-10,0,-138), Vector3(-10,0,-144)]
const PACKS := [Vector3(-38,0,-24), Vector3(22,0,-64), Vector3(-30,0,-114)]
const POCKET := Vector3(42,0,-64)
const BRIDGE := Vector3(-8,0,-90)
