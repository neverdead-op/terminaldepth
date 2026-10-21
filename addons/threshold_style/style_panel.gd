@tool
extends VBoxContainer
const Look = preload("res://scripts/threshold_look.gd")
var target: Node
var controls := {}
var status: Label
var refreshing := false
## Другая сцена может использовать тот же редактор контролов со своим профилем.
var schema_override: Array = []
var title_override := ""
var note_override := ""
var art_profiles: Array = [["По концепту","res://data/visual/threshold_concept.tres"],["Твой профиль · 16.10","res://data/visual/threshold_user_20261016.tres"]]
var preset_names: Array = ["Мягкий","Графичный"]

func _ready() -> void:
	custom_minimum_size = Vector2(440,440)
	var title := Label.new();title.text = title_override if not title_override.is_empty() else "МАСТЕРСКАЯ СТИЛЯ · TERMINAL DEPTH";add_child(title)
	status = Label.new();status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;add_child(status)
	var fields: Array[Control] = []
	if not schema_override.is_empty():
		var search := LineEdit.new();search.placeholder_text="Найти параметр · например: туман, exposure, SSAO";add_child(search)
		search.text_changed.connect(func(text: String):
			for field in fields: field.visible = text.is_empty() or text.to_lower() in String(field.get_meta("search")).to_lower())
	var tabs := TabContainer.new();tabs.custom_minimum_size.y=220;tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL;add_child(tabs)
	var groups := {}
	for row in (schema_override if not schema_override.is_empty() else Look.schema()):
		if not groups.has(row[0]):
			var scroll := ScrollContainer.new();scroll.name = row[0];scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED;tabs.add_child(scroll)
			var group := VBoxContainer.new();group.size_flags_horizontal = Control.SIZE_EXPAND_FILL;group.add_theme_constant_override("separation",9);scroll.add_child(group);groups[row[0]] = group
		var group := VBoxContainer.new();groups[row[0]].add_child(group)
		group.set_meta("search",String(row[2])+" "+String(row[1]));fields.append(group)
		var id: String = row[1]
		if row[3] is Dictionary:
			var label := Label.new();label.text = row[2];group.add_child(label)
			var option := OptionButton.new();group.add_child(option);controls[id] = option
			for text: String in row[3]: option.add_item(text,int(row[3][text]))
			option.item_selected.connect(func(index: int): _change(id,option.get_item_id(index)))
		elif row[3] is bool:
			var box := CheckBox.new();box.text = row[2];group.add_child(box);controls[id] = box
			box.toggled.connect(func(value: bool): _change(id,value))
		elif row[3] is Color:
			var label := Label.new();label.text = row[2];group.add_child(label)
			var color := ColorPickerButton.new();color.edit_alpha = false;color.custom_minimum_size.y = 28;group.add_child(color);controls[id] = color
			color.color_changed.connect(func(value: Color): _change(id,value))
		else:
			var label := Label.new();label.text = row[2];group.add_child(label)
			var line := HBoxContainer.new();group.add_child(line)
			var slider := HSlider.new();slider.min_value = row[3];slider.max_value = row[4];slider.step = row[5];slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL;line.add_child(slider)
			var spin := SpinBox.new();spin.min_value = row[3];spin.max_value = row[4];spin.step = row[5];spin.custom_minimum_size.x = 95;line.add_child(spin)
			controls[id] = [slider,spin]
			slider.value_changed.connect(func(value: float): spin.set_value_no_signal(value);_change(id,value))
			spin.value_changed.connect(func(value: float): slider.set_value_no_signal(value);_change(id,value))
	var presets := HBoxContainer.new();add_child(presets)
	var art_presets := HBoxContainer.new();add_child(art_presets)
	for entry in art_profiles:
		var art_button := Button.new();art_button.text = entry[0];art_presets.add_child(art_button)
		var profile_path: String = entry[1]
		art_button.pressed.connect(func():
			if is_instance_valid(target): target.reload_profile(profile_path);refresh())
	for item in [[preset_names[0],false],[preset_names[1],true]]:
		var button := Button.new();button.text = item[0];presets.add_child(button)
		var graphic: bool = item[1]
		button.pressed.connect(func():
			if is_instance_valid(target): target.preset(graphic);refresh())
	var save := Button.new();save.text = "Сохранить профиль";presets.add_child(save)
	save.pressed.connect(func():
		if is_instance_valid(target):
			var error: Error = target.save_profile()
			status.text = "Профиль сохранён для следующих запусков." if error == OK else "Не удалось сохранить: "+error_string(error))
	var load_button := Button.new();load_button.text = "Вернуть сохранённый";add_child(load_button)
	load_button.pressed.connect(func():
		if is_instance_valid(target): target.reload_profile();refresh())
	var note := Label.new();note.text = note_override if not note_override.is_empty() else "Селшейдинг и грани — окружение. HUD не меняется. Изменения видны сразу; запись на диск — только кнопкой сохранения.";note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART;add_child(note)
	refresh()

func bind(controller: Node) -> void:
	target = controller
	if is_inside_tree() and status != null: refresh()

func _change(id: String, value: Variant) -> void:
	if refreshing or not is_instance_valid(target): return
	target.profile.set(id,value)
	target.apply()
	status.text = "Изменено в предпросмотре. Чтобы оставить — сохрани профиль."

func refresh() -> void:
	refreshing = true
	var valid := is_instance_valid(target)
	status.text = "Параметры применяются к открытой сцене." if valid else "Открой художественную сцену — здесь появятся её настройки."
	for id in controls:
		var control: Variant = controls[id]
		if control is Array:
			for range_control in control:
				range_control.editable = valid
				if valid: range_control.set_value_no_signal(float(target.profile.get(id)))
		elif control is OptionButton:
			control.disabled = not valid
			if valid:
				for i in control.item_count:
					if control.get_item_id(i)==int(target.profile.get(id)): control.select(i)
		elif control is CheckBox:
			control.disabled = not valid
			if valid: control.set_pressed_no_signal(bool(target.profile.get(id)))
		elif control is ColorPickerButton:
			control.disabled = not valid
			if valid: control.color = target.profile.get(id)
	refreshing = false
