@tool
extends Resource
## Нативные Environment/CameraAttributes сохраняются целиком, включая LUT и другие ресурсы.
@export var environment: Environment = Environment.new()
@export var camera: CameraAttributesPractical = CameraAttributesPractical.new()
@export_group("Свет")
@export var sun_color := Color(.84,.91,1.0)
@export_range(0,4,.01) var sun_energy := .88
@export_range(-90,0,.1) var sun_elevation := -46.0
@export_range(-180,180,.1) var sun_azimuth := -42.0
@export_range(0,3,.01) var lantern_multiplier := 1.35
@export var lantern_color := Color(1,.57,.24)
@export_group("Цветокоррекция")
@export_range(-1,1,.01) var temperature := -.04
@export_range(-1,1,.01) var tint := 0.0
@export var shadows := Color(.97,1.01,1.04)
@export var highlights := Color(1.04,1.015,.97)
@export var lift := Color(0,0,0)
@export var gamma := Color(1,1,1)
@export var gain := Color(1,1,1)
@export_group("Линза")
@export_range(0,.6,.01) var vignette := .1
@export_range(.1,1,.01) var vignette_softness := .55
@export_range(0,1,.01) var sharpen := .08
@export_range(0,.02,.0001) var chromatic_aberration := 0.0
@export_range(0,.1,.001) var grain := 0.0
@export_range(-.2,.2,.001) var lens_distortion := 0.0
@export_range(0,1,.01) var effect_weight := 1.0

func _get(key: StringName) -> Variant:
	var path := String(key)
	if path.begins_with("env/"): return environment.get(path.substr(4))
	if path.begins_with("camera/"): return camera.get(path.substr(7))
	return null

func _set(key: StringName,value: Variant) -> bool:
	var path := String(key)
	if path.begins_with("env/") or path.begins_with("camera/"):
		var object: Resource = environment if path.begins_with("env/") else camera
		var id := path.substr(4 if path.begins_with("env/") else 7)
		object.set(id,int(value) if typeof(object.get(id))==TYPE_INT else value)
		return true
	return false

static func defaults() -> Resource:
	var result = load("res://scripts/postfx_profile.gd").new()
	result.environment = load("res://data/visual/riverbank_environment.tres").duplicate(true)
	var e: Environment = result.environment
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.ambient_light_color = Color(.48,.61,.74)
	e.ambient_light_energy = .52
	e.tonemap_exposure = 1.05
	e.glow_enabled = true
	e.glow_intensity = .26
	e.glow_hdr_threshold = 1.5
	e.ssao_enabled = true
	e.ssao_radius = 1.1
	e.ssao_intensity = .85
	e.ssao_power = 1.1
	e.ssil_enabled = false
	e.adjustment_enabled = true
	e.adjustment_contrast = 1.04
	e.adjustment_saturation = .96
	# Лёгкая холодная воздушная перспектива, без дорогого объёмного тумана.
	e.fog_enabled = true
	e.fog_light_color = Color(.19,.29,.36)
	e.fog_light_energy = .65
	e.fog_density = .003
	e.fog_sky_affect = 0.0
	return result

static func schema(profile: Resource) -> Array:
	var rows: Array = []
	var names := {"sun_color":"Цвет основного света","sun_energy":"Яркость основного света","sun_elevation":"Наклон света","sun_azimuth":"Поворот света","lantern_multiplier":"Яркость фонарей","lantern_color":"Цвет фонарей","temperature":"Теплее / холоднее","tint":"Зелёный / пурпурный","shadows":"Оттенок теней","highlights":"Оттенок света","lift":"Подъём чёрного","gamma":"Гамма RGB","gain":"Усиление RGB","vignette":"Виньетка","vignette_softness":"Мягкость виньетки","sharpen":"Резкость","chromatic_aberration":"Хроматическая аберрация","grain":"Зерно","lens_distortion":"Искажение объектива","effect_weight":"Вес экранного эффекта"}
	for prefix: String in ["env","camera",""]:
		var object: Resource = profile.environment if prefix=="env" else profile.camera if prefix=="camera" else profile
		for property in object.get_property_list():
			var id: String = property.name
			if not property.usage & PROPERTY_USAGE_STORAGE or id.begins_with("resource_") or id in ["script","environment","camera"]: continue
			if prefix.is_empty() and not names.has(id): continue
			var value: Variant = object.get(id)
			var group := "Камера" if prefix=="camera" else "Свет" if id.begins_with("ambient") or id.begins_with("sun_") or id.begins_with("lantern_") else "Тон" if id.begins_with("tonemap") or id.begins_with("adjustment") or id.begins_with("background") or id.begins_with("reflected") else "Туман" if "fog" in id else "GI" if id.begins_with("sdfgi") else "Эффекты" if not prefix.is_empty() else "Цвет" if id in ["temperature","tint","shadows","highlights","lift","gamma","gain"] else "Линза"
			var key := prefix+"/"+id if not prefix.is_empty() else id
			var title: String = names.get(id,id.capitalize().replace("Ssao","SSAO").replace("Ssil","SSIL").replace("Ssr","SSR").replace("Sdfgi","SDFGI"))
			if value is bool or value is Color:
				rows.append([group,key,title,value])
			elif typeof(value) in [TYPE_FLOAT,TYPE_INT]:
				var hints := String(property.hint_string).split(",")
				if property.hint==PROPERTY_HINT_ENUM:
					var options := {}
					var index := 0
					for hint in hints:
						var pair := hint.split(":")
						if pair.size()>1: index = int(pair[1])
						options[pair[0]] = index
						index += 1
					rows.append([group,key,title,options])
				else:
					var lo := 0.0
					var hi := maxf(5,float(value)*2)
					var step := .01 if typeof(value)==TYPE_FLOAT else 1.0
					if property.hint==PROPERTY_HINT_RANGE and hints.size()>=2:
						lo = float(hints[0]); hi = float(hints[1])
						if hints.size()>2 and hints[2].is_valid_float(): step = float(hints[2])
					rows.append([group,key,title,lo,hi,step])
	var labels := {"env/tonemap_exposure":"Экспозиция","env/tonemap_mode":"Тональная компрессия","env/tonemap_white":"Уровень белого","env/adjustment_enabled":"Цветовые настройки Environment","env/adjustment_brightness":"Яркость","env/adjustment_contrast":"Контраст","env/adjustment_saturation":"Насыщенность","env/ambient_light_energy":"Заполнение теней","env/ambient_light_color":"Цвет заполнения","env/glow_enabled":"Свечение: включить","env/glow_intensity":"Яркость свечения","env/glow_hdr_threshold":"Порог свечения","env/ssao_enabled":"Контактные тени SSAO","env/ssil_enabled":"Непрямой свет SSIL","env/ssr_enabled":"Экранные отражения SSR","env/fog_enabled":"Туман: включить","env/volumetric_fog_enabled":"Объёмный туман: включить","camera/exposure_multiplier":"Множитель экспозиции камеры","camera/auto_exposure_enabled":"Автоэкспозиция","camera/dof_blur_far_enabled":"Размытие дальней зоны","camera/dof_blur_near_enabled":"Размытие ближней зоны","camera/dof_blur_amount":"Сила размытия"}
	var important := ["sun_energy","sun_color","sun_elevation","sun_azimuth","lantern_multiplier","lantern_color","env/ambient_light_energy","env/ambient_light_color","env/tonemap_exposure","env/tonemap_mode","env/adjustment_enabled","env/adjustment_brightness","env/adjustment_contrast","env/adjustment_saturation"]
	var groups := ["Свет","Тон","Цвет","Линза","Эффекты","Туман","Камера","GI","Фон"]
	for row in rows:
		if row[1].begins_with("env/background") or row[1].begins_with("env/reflected"): row[0]="Фон"
		row[2] = labels.get(row[1],row[2])
	rows.sort_custom(func(a,b):
		if a[0]!=b[0]: return groups.find(a[0])<groups.find(b[0])
		var ia := important.find(a[1]);var ib := important.find(b[1])
		return (ia if ia>=0 else 1000)<(ib if ib>=0 else 1000))
	return rows
