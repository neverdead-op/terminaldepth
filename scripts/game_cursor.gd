extends Node
## Общая стрелка мыши для игры, меню и паузы. Острие совпадает с точкой клика.

@export_range(24, 96, 1) var cursor_height := 48

const SOURCE := preload("res://assets/ui/gothic_v2/cursor_arrow_source.png")
## Убираем пустые поля исходника, сохраняя прозрачность и сам рисунок.
const SOURCE_RECT := Rect2i(242, 176, 668, 800)
const SOURCE_TIP := Vector2(5, 5)

var texture: ImageTexture
var hotspot := Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var image := SOURCE.get_image().get_region(SOURCE_RECT)
	var scale_factor := float(cursor_height) / SOURCE_RECT.size.y
	image.resize(roundi(SOURCE_RECT.size.x * scale_factor), cursor_height, Image.INTERPOLATE_LANCZOS)
	texture = ImageTexture.create_from_image(image)
	hotspot = (SOURCE_TIP * scale_factor).round()
	# Один рисунок и над кнопками, и над полями: системная рука его не подменяет.
	for shape in range(Input.CURSOR_ARROW, Input.CURSOR_HELP + 1):
		Input.set_custom_mouse_cursor(texture, shape, hotspot)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
