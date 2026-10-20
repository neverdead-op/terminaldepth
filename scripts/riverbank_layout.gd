extends RefCounted
## Общая планировка для сборщика и игрового теста: повороты не дублируются в двух файлах.
const ROUTE := [Vector3(-20,0,12), Vector3(-20,0,-4), Vector3(-38,0,-18),
	Vector3(-38,0,-30), Vector3(-18,0,-44), Vector3(6,0,-44),
	Vector3(22,0,-58), Vector3(22,0,-76), Vector3(2,0,-90),
	Vector3(-22,0,-90), Vector3(-30,0,-108), Vector3(-30,0,-124),
	Vector3(-10,0,-138), Vector3(-10,0,-144)]
const PACKS := [Vector3(-38,0,-24), Vector3(22,0,-64), Vector3(-30,0,-114)]
const POCKET := Vector3(42,0,-64)
const BRIDGE := Vector3(-8,0,-90)
