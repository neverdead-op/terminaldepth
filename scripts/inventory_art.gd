extends RefCounted
## Боковые окна утверждённого первого варианта; центр открыт для игрового мира.
const TEXTURE := preload("res://assets/ui/gothic_v4/inventory_poe.png")
const SIZE := Vector2(1672, 941)
const IMAGE_SIZE := SIZE
const LEFT_PANEL := Rect2(0, 0, 612, 941)
const RIGHT_PANEL := Rect2(1058, 0, 614, 941)
const BAG_X := 1114.0
const BAG_WIDTH := 498.0
const BAG_ROWS := [644.0, 689.0, 734.0, 779.0, 824.0, 869.0]

static func tab_rect(index: int) -> Rect2:
	return Rect2(628 + (index % 2) * 206, 16 + floori(index / 2.0) * 40, 198, 32)

static func bag_rect(pos: Vector2i, item_size := Vector2i.ONE) -> Rect2:
	return Rect2(BAG_X + pos.x * 41.5, BAG_ROWS[pos.y], item_size.x * 41.5, BAG_ROWS[mini(pos.y + item_size.y, 5)] - BAG_ROWS[pos.y])

static func equipment() -> Dictionary:
	return {
		&"helmet": Rect2(1316, 102, 78, 86), &"combat": Rect2(1311, 403, 88, 40),
		&"implant1": Rect2(1195, 192, 56, 49), &"body": Rect2(1311, 228, 88, 138),
		&"implant2": Rect2(1458, 192, 56, 49), &"gloves": Rect2(1176, 292, 76, 106),
		&"boots": Rect2(1461, 292, 76, 106),
	}

static func weapon_rect(index: int, large := false) -> Rect2:
	return Rect2(88, 119 + index * 310, 449, 123) if large else Rect2(1121 + index * 254, 490, 220, 130)

static func skill_rect(index: int, secondary := false) -> Rect2:
	var center := Vector2(180, 357 + index * 310) if secondary else Vector2(157, 292 + index * 310)
	return Rect2(center - Vector2.ONE * 28, Vector2.ONE * 56)

static func socket_center(index: int, slot: int, secondary := false) -> Vector2:
	return Vector2(250 + slot * 60, 357 + index * 310) if secondary else Vector2(239 + slot * 57.5, 292 + index * 310)

static func module_rect(index: int) -> Rect2:
	return Rect2(77 + (index % 9) * 54, 713 + floori(index / 9.0) * 44, 45, 34)

static func action_rect(index: int) -> Rect2:
	return Rect2(1171 + index * 145, 877, 132, 24)

static func draw_layout(ci: CanvasItem, map: Callable) -> void:
	ci.draw_texture_rect(TEXTURE, map.call(Rect2(Vector2.ZERO, IMAGE_SIZE)), false)
