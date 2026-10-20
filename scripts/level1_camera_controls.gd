extends CanvasLayer
## Local camera trial panel. Settings survive F7 for this running session.
const DEFAULT_SETTINGS := Vector3(10.5, 52, 60)
static var settings := DEFAULT_SETTINGS
var rig: Node3D
var camera: Camera3D
var panel: PanelContainer
var toggle: Button
var sliders: Dictionary = {}
var values: Dictionary = {}
var syncing := false
var was_paused := false
var opened := false

func _ready() -> void:
 process_mode = Node.PROCESS_MODE_ALWAYS
 layer = 90
 rig = get_parent().get_node("CameraRig")
 camera = rig.get_node("Camera3D")
 toggle = Button.new()
 toggle.text = "Камера · F8"
 toggle.position = Vector2(950, 175)
 toggle.size = Vector2(310, 34)
 toggle.pressed.connect(func():set_open(not opened))
 add_child(toggle)
 panel = PanelContainer.new()
 panel.position = Vector2(930, 215)
 panel.custom_minimum_size = Vector2(330, 0)
 var margin := MarginContainer.new()
 for side in ["left", "right", "top", "bottom"]:margin.add_theme_constant_override("margin_" + side, 14)
 panel.add_child(margin)
 var box := VBoxContainer.new()
 box.add_theme_constant_override("separation", 10)
 margin.add_child(box)
 var title := Label.new();title.text = "Настройка камеры";box.add_child(title)
 _slider(box, "distance", "Расстояние", 6, 25, .1)
 _slider(box, "angle", "Угол сверху", 25, 75, 1)
 _slider(box, "height", "Высота", 3, 24, .1)
 _slider(box, "fov", "Угол обзора", 40, 80, 1)
 var note := Label.new()
 note.text = "Высота связана с расстоянием и наклоном.\nБой на паузе, камера меняется сразу.\nНастройки остаются после F7 до выхода."
 note.add_theme_font_size_override("font_size", 13)
 box.add_child(note)
 var reset := Button.new();reset.text = "Сбросить";reset.pressed.connect(func():settings=DEFAULT_SETTINGS;_apply());box.add_child(reset)
 var close := Button.new();close.text = "Продолжить игру · F8";close.pressed.connect(func():set_open(false));box.add_child(close)
 add_child(panel)
 panel.hide()
 _apply()
 get_viewport().size_changed.connect(_layout)
 _layout()

func _layout() -> void:
 var right: float = get_viewport().get_visible_rect().size.x - 20
 toggle.position.x = right - 310
 panel.position.x = right - 330

func _slider(box: VBoxContainer, key: String, caption: String, low: float, high: float, step: float) -> void:
 var label := Label.new();box.add_child(label);values[key] = [label, caption]
 var slider := HSlider.new();slider.min_value=low;slider.max_value=high;slider.step=step
 slider.custom_minimum_size=Vector2(300, 22)
 slider.value_changed.connect(func(value:float):_change(key,value))
 sliders[key]=slider;box.add_child(slider)

func _change(key: String, value: float) -> void:
 if syncing:return
 match key:
  "distance":settings.x=value
  "angle":settings.y=value
  "height":settings.x=clampf(value/sin(deg_to_rad(settings.y)),6,25)
  "fov":settings.z=value
 _apply()

func _apply() -> void:
 rig.use_distance_angle=true
 rig.distance=settings.x
 rig.elevation_degrees=settings.y
 camera.fov=settings.z
 camera.position=rig._camera_offset()
 camera.look_at(rig.global_position,Vector3.UP)
 syncing=true
 var current: Dictionary={"distance":settings.x,"angle":settings.y,"height":camera.position.y,"fov":settings.z}
 for key in current:
  sliders[key].set_value_no_signal(current[key])
  values[key][0].text="%s: %.1f%s" % [values[key][1], current[key], "°" if key in ["angle","fov"] else " м"]
 syncing=false

func set_open(value: bool) -> void:
 if opened==value:return
 opened=value
 panel.visible=value
 toggle.text="Закрыть камеру · F8" if value else "Камера · F8"
 if value:
  was_paused=get_tree().paused
  get_tree().paused=true
 else:get_tree().paused=was_paused

func _input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F8:
  set_open(not opened)
  get_viewport().set_input_as_handled()

func _exit_tree() -> void:
 if opened:get_tree().paused=was_paused
