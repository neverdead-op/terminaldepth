extends Control
## Компактные строки целей: название, счётчик и настоящие значки наград.
const Style := preload("res://scripts/ui_style.gd")
const UiIcons := preload("res://scripts/ui_icons.gd")
@export var row_height := 38.0
var _quests: Array = []
var _check := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0:
		_check = 0.3
		var node := get_tree().get_first_node_in_group("zone_quests")
		_quests = node.quests if node != null and node.is_inside_tree() else []
	queue_redraw()

func _draw() -> void:
	for i in _quests.size():
		var q: Dictionary = _quests[i]
		var r := Rect2(0, i * row_height, size.x, row_height - 4)
		Style.plate(self, r)
		var dim := 0.45 if q.finished else 1.0
		var rewards := int(q.get("reward_xp", false)) + int(q.get("reward_loot", false))
		var title: String = Loc.t(q.title)
		draw_string(Loc.MAIN_FONT, r.position + Vector2(12, 23), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 62 - rewards * 23, 14, Color(Style.TEXT, dim))
		var count := "×" if q.get("failed", false) else ("✓" if q.finished else "%d/%d" % [q.done, q.need])
		draw_string(Loc.MAIN_FONT, Vector2(size.x - 42 - rewards * 23, r.position.y + 23), count, HORIZONTAL_ALIGNMENT_LEFT, 40, 12, Color(Style.TEXT, dim))
		var x := size.x - 27
		for kind in ["xp", "loot"]:
			if q.get("reward_" + kind, false):
				UiIcons.draw_texture_fit(self, UiIcons.texture("res://assets/icons/rewards/" + kind + ".png"), Rect2(x, r.position.y + 5, 22, 22), Color(1, 1, 1, dim))
				x -= 23
