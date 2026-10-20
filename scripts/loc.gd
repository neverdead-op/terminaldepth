extends Node
## Автозагрузка Loc — язык интерфейса: русский (исходный текст в коде) или английский (data/lang/en.gd).
## Loc.t(текст) переводит строку, уже готовую к показу: сначала точное совпадение, потом шаблоны
## («Урон: %d» узнаёт «Урон: 22» и даёт «Damage: 22»; имена внутри %s переводятся тоже),
## потом — по частям через разделители « · », « — », «, ». Результаты запоминаются.
## Выбор языка хранится в user://settings.cfg (меню паузы → «Язык»).

signal language_changed
## Сменилось устройство ввода (геймпад ↔ клавиатура и мышь) — подсказки кнопок перерисовываются.
signal device_changed

## Последнее устройство ввода: true — геймпад. По нему подсказки «A / ✕ / ЛКМ» показывают только нужные кнопки.
var using_gamepad := false
## Геймпад PlayStation (✕ ○ △ □) или Xbox-подобный (A B X Y).
var playstation_pad := false
var _key_cache := {}
var _group := RegEx.new()
const PS_SYMBOLS := ["✕", "○", "△", "□", "L1", "R1", "L2", "R2"]
const XBOX_ONLY := ["LB", "RB", "LT", "RT"]
const PAD_NEUTRAL := ["L3", "R3", "Start", "Back", "Select"]
const XBOX_LETTERS := ["A", "B", "X", "Y"]
## Одна и та же кнопка на разных геймпадах.
const PS_TO_XBOX := {"✕": "A", "○": "B", "△": "Y", "□": "X", "L1": "LB", "R1": "RB", "L2": "LT", "R2": "RT"}
## Если в подсказке только кнопки геймпада — что нажимать на клавиатуре и мыши (как в input_setup.gd / меню).
const PAD_TO_KEYBOARD := {"A": "ЛКМ", "B": "Esc", "Y": "ПКМ", "X": "M", "LB": "PgUp", "RB": "PgDn", "LT": "Alt", "RT": "G", "L3": "H", "R3": "P",
		"Start": "Esc", "Back": "Tab"}

const SETTINGS_PATH := "user://settings.cfg"
const LANGUAGES := ["ru", "en"]
const LANGUAGE_NAMES := {"ru": "Русский", "en": "English"}
const EN := preload("res://data/lang/en.gd")
## Шрифты игры (Google Fonts, OFL): Lora — основной текст, Cormorant Garamond — заголовки.
const MAIN_FONT := preload("res://assets/fonts/main_font.tres")
const TITLE_FONT := preload("res://assets/fonts/title_font.tres")

## Идентификаторы персонажей в сохранениях прежние; отображаемые имена локализованы.
func npc_name(text: String) -> String:
	return t(text).replace("Angie", "Энджи").replace("Mira", "Мира") if language == "ru" else t(text)
const SEPARATORS := ["   ·   ", "  ·  ", " · ", "  —  ", " — ", ", ", ":  ", "   "]

var language := "ru"
## Строки, для которых не нашлось перевода (для проверки).
var missing := {}

var _patterns: Array = []  # [{regex, en, specs}]
var _cache := {}
var _cyrillic := RegEx.new()
var _spec := RegEx.new()


func _ready() -> void:
	# Единый шрифт с засечками, включая текст, который рисуется вручную через _draw.
	ThemeDB.fallback_font = MAIN_FONT
	_group.compile("[^\\s/·—,()]+(?: / [^\\s/·—,()]+)+")
	_cyrillic.compile("[\\x{0400}-\\x{04FF}]")
	_spec.compile("%(?:%|[-+0 ]*\\d*(?:\\.\\d+)?[dsf])")
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		language = config.get_value("game", "language", "ru")
	_build_patterns()


func set_language(value: String) -> void:
	if value == language:
		return
	language = value
	_cache.clear()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("game", "language", language)
	config.save(SETTINGS_PATH)
	language_changed.emit()


func next_language() -> void:
	set_language(LANGUAGES[(LANGUAGES.find(language) + 1) % LANGUAGES.size()])


## Перевести готовую к показу строку на текущий язык (и оставить в ней кнопки только текущего устройства).
func t(text: String) -> String:
	return keys(_t(text))


func _input(event: InputEvent) -> void:
	var pad := using_gamepad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		pad = true
		var name := Input.get_joy_name(event.device).to_lower()
		var ps := name.contains("ps") or name.contains("playstation") or name.contains("dualsense") \
				or name.contains("dualshock") or name.contains("sony")
		if ps != playstation_pad:
			playstation_pad = ps
			_key_cache.clear()
			if pad == using_gamepad:
				device_changed.emit()
	elif event is InputEventKey or event is InputEventMouseButton \
			or (event is InputEventMouseMotion and event.relative.length() > 4.0):
		pad = false
	if pad != using_gamepad:
		using_gamepad = pad
		_key_cache.clear()
		device_changed.emit()


## Клавиша действия для текущего устройства — из InputMap, т. е. с учётом переназначения в настройках.
## Несколько привязок (X и ПКМ) — через « / ».
func action_key(action: String) -> String:
	var out := []
	for e in InputMap.action_get_events(action):
		var n := ""
		if using_gamepad and e is InputEventJoypadButton:
			n = _pad_button_name(e.button_index)
		elif using_gamepad and e is InputEventJoypadMotion:
			n = {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}.get(e.axis, "")
			if n != "":
				n = _pad_style(n)
		elif not using_gamepad and e is InputEventKey:
			n = OS.get_keycode_string(e.physical_keycode if e.physical_keycode != 0 else e.keycode)
		elif not using_gamepad and e is InputEventMouseButton:
			n = {MOUSE_BUTTON_LEFT: "ЛКМ", MOUSE_BUTTON_RIGHT: "ПКМ", MOUSE_BUTTON_MIDDLE: "СКМ"}.get(e.button_index, "")
			if language == "en":
				n = {"ЛКМ": "LMB", "ПКМ": "RMB", "СКМ": "MMB"}.get(n, n)
		if n != "" and not n in out:
			out.append(n)
	return " / ".join(out)


func _pad_button_name(b: int) -> String:
	var xbox := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
			JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
			JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_START: "Start", JOY_BUTTON_BACK: "Back",
			JOY_BUTTON_DPAD_UP: "↑", JOY_BUTTON_DPAD_DOWN: "↓", JOY_BUTTON_DPAD_LEFT: "←", JOY_BUTTON_DPAD_RIGHT: "→"}
	return _pad_style(xbox.get(b, "?"))


## В связках вида «A / ✕ / ЛКМ», «F / ○», «G / RB» оставить кнопки только текущего устройства.
func keys(text: String) -> String:
	if not text.contains(" / "):
		return text
	if _key_cache.has(text):
		return _key_cache[text]
	var out := text
	for m in _group.search_all(text):
		var parts := m.get_string().split(" / ")
		var pad_tokens := []
		var kb_tokens := []
		for i in parts.size():
			var tok: String = parts[i]
			var next: String = parts[i + 1] if i + 1 < parts.size() else ""
			var prev: String = parts[i - 1] if i > 0 else ""
			var is_pad: bool = tok in PS_SYMBOLS or tok in XBOX_ONLY or tok in PAD_NEUTRAL
			# Буква A/B/X/Y — кнопка геймпада, если рядом значок PlayStation или кнопка геймпада (Start).
			if tok in XBOX_LETTERS and (next in PS_SYMBOLS or prev in PAD_NEUTRAL or prev in XBOX_ONLY):
				is_pad = true
			if is_pad:
				pad_tokens.append(tok)
			else:
				kb_tokens.append(tok)
		var keep := []
		if using_gamepad and not pad_tokens.is_empty():
			for tok in pad_tokens:
				var t2: String = _pad_style(tok)
				if keep.is_empty():
					keep.append(t2)  # одна кнопка — первая из подходящих
		elif not using_gamepad and not kb_tokens.is_empty():
			keep = kb_tokens
		elif not using_gamepad:
			var xbox: String = PS_TO_XBOX.get(pad_tokens[0], pad_tokens[0])
			if not PAD_TO_KEYBOARD.has(xbox):
				continue
			var kb: String = PAD_TO_KEYBOARD[xbox]
			if language == "en":
				kb = {"ЛКМ": "LMB", "ПКМ": "RMB"}.get(kb, kb)
			keep = [kb]
		else:
			continue
		out = out.replace(m.get_string(), " / ".join(keep))
	if _key_cache.size() > 4000:
		_key_cache.clear()
	_key_cache[text] = out
	return out


## Кнопка геймпада в стиле подключённого: PlayStation — ✕ ○ △ □, иначе — A B X Y.
func _pad_style(tok: String) -> String:
	if playstation_pad:
		for ps in PS_TO_XBOX:
			if PS_TO_XBOX[ps] == tok:
				return ps
		return tok
	return PS_TO_XBOX.get(tok, tok)


func _t(text: String) -> String:
	if language == "ru" or text.is_empty():
		return text
	if _cache.has(text):
		return _cache[text]
	var result := _translate(text, 0)
	if _cyrillic.search(result):
		missing[text] = true
	if _cache.size() > 6000:
		_cache.clear()
	_cache[text] = result
	return result


func _translate(text: String, depth: int) -> String:
	if not _cyrillic.search(text):
		return text
	if EN.TEXT.has(text):
		return EN.TEXT[text]
	# Шаблоны: «+%d к Armour» ← «+12 к Armour».
	for p in _patterns:
		var m: RegExMatch = p.regex.search(text)
		if m == null:
			continue
		var out: String = p.en
		var args := []
		for i in range(1, m.get_group_count() + 1):
			var value := m.get_string(i)
			args.append(_translate(value, depth + 1) if depth < 3 else value)
		return _fill(out, args)
	# По частям: «Шлем · Rare · Armour и Energy Shield».
	if depth < 3:
		for sep in SEPARATORS:
			if text.contains(sep):
				var parts := text.split(sep)
				var changed := false
				for i in parts.size():
					var tr_part := _translate(parts[i], depth + 1)
					if tr_part != parts[i]:
						parts[i] = tr_part
						changed = true
				if changed:
					return sep.join(parts)
		# Пробелы по краям («  × 8 пуль») — переводим середину.
		var stripped := text.strip_edges()
		if stripped != text and EN.TEXT.has(stripped):
			return text.replace(stripped, EN.TEXT[stripped])
	return text


## Подставить значения в английский шаблон по порядку (%% — знак процента).
func _fill(template: String, args: Array) -> String:
	var out := ""
	var last := 0
	var k := 0
	for m in _spec.search_all(template):
		out += template.substr(last, m.get_start() - last)
		if m.get_string() == "%%":
			out += "%"
		else:
			out += str(args[k]) if k < args.size() else ""
			k += 1
		last = m.get_end()
	return out + template.substr(last)


## Из ключей с %d / %s / %.1f строим регулярные выражения. Длинные шаблоны проверяем раньше —
## они точнее (иначе «%s · база» перехватил бы слишком многое).
func _build_patterns() -> void:
	var keys := EN.TEXT.keys().filter(func(k): return _spec.search(k) != null)
	keys.sort_custom(func(a, b): return _literal_len(a) > _literal_len(b))
	for key in keys:
		var pattern := "^"
		var last := 0
		for m in _spec.search_all(key):
			pattern += _escape(key.substr(last, m.get_start() - last))
			var spec := m.get_string()
			if spec == "%%":
				pattern += "%"
			elif spec.ends_with("s"):
				pattern += "(.*?)"
			else:
				pattern += "([-+−]?\\d+(?:\\.\\d+)?)"
			last = m.get_end()
		pattern += _escape(key.substr(last)) + "$"
		var regex := RegEx.new()
		if regex.compile(pattern) == OK:
			_patterns.append({"regex": regex, "en": EN.TEXT[key]})


func _literal_len(key: String) -> int:
	return _spec.sub(key, "", true).length()


func _escape(s: String) -> String:
	var out := ""
	for c in s:
		out += "\\" + c if "\\^$.|?*+()[]{}".contains(c) else c
	return out
