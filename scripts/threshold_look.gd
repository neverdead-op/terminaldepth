@tool
extends Resource
## Portable art profile. Saving is explicit in the style window.
@export var cel_enabled := false
@export_range(0.0,1.0) var cel_amount := 0.65
@export_range(2,8) var cel_steps := 4
@export_range(0.01,0.49) var cel_softness := 0.18
@export_range(0.0,1.0) var flat_normals := 0.0
@export_range(0.0,0.7) var rim := 0.08
@export_range(0.0,1.0) var weathering := 0.22
@export_range(0.3,2.0) var exposure := 1.0
@export_range(0.6,1.5) var contrast := 1.07
@export_range(0.0,1.6) var saturation := 1.0
@export_range(-1.0,1.0) var temperature := 0.0
@export_range(0.0,1.0) var split_tone := 0.8
@export_range(0.0,0.4) var vignette := 0.13
@export_range(0.0,0.2) var softness := 0.055
@export_range(0.0,1.0) var posterize := 0.0
@export_range(6,48) var color_steps := 24
@export_range(0.0,1.3) var bloom := 0.55
@export_range(0.6,3.0) var bloom_threshold := 1.15
@export var ssao := true
@export var ssil := true
@export_range(0.0,1.2) var moon := 0.34
@export_range(0.0,0.8) var ambient := 0.16
@export_range(0.0,2.5) var warm_lights := 1.0
@export var warm_color := Color(1,0.55,0.23)
@export_range(0.0,2.0) var courtyard_fog := 1.0
@export_range(0.0,1.5) var background_cards := 0.28
@export_range(0.0,0.3) var volume_density := 0.13
@export_range(0.04,0.5) var cloud_scale := 0.15
@export_range(0.0,2.0) var wind := 0.45
@export var cloud_color := Color(0.43,0.58,0.65)
@export_range(0.0,0.2) var dof := 0.035
@export_range(30.0,100.0) var focus_distance := 55.0

static func schema() -> Array:
	return [
		["Материалы","cel_enabled","Селшейдинг",false],
		["Материалы","cel_amount","Сила селшейдинга",0.0,1.0,.01],
		["Материалы","cel_steps","Ступени освещения",2,8,1],
		["Материалы","cel_softness","Мягкость ступеней",.01,.49,.01],
		["Материалы","flat_normals","Выразительность граней",0.0,1.0,.01],
		["Материалы","rim","Свет по краям",0.0,.7,.01],
		["Материалы","weathering","Пятна влажности",0.0,1.0,.01],
		["Цвет","exposure","Экспозиция",.3,2.0,.01],
		["Цвет","contrast","Контраст",.6,1.5,.01],
		["Цвет","saturation","Насыщенность",0.0,1.6,.01],
		["Цвет","temperature","Теплее / холоднее",-1.0,1.0,.01],
		["Цвет","split_tone","Разделение света и теней",0.0,1.0,.01],
		["Цвет","vignette","Виньетка",0.0,.4,.01],
		["Цвет","softness","Мягкость изображения",0.0,.2,.005],
		["Цвет","posterize","Живописные цветовые ступени",0.0,1.0,.01],
		["Цвет","color_steps","Число цветовых ступеней",6,48,1],
		["Свет","moon","Холодный общий свет",0.0,1.2,.01],
		["Свет","ambient","Заполнение теней",0.0,.8,.01],
		["Свет","warm_lights","Яркость фонарей",0.0,2.5,.01],
		["Свет","warm_color","Цвет фонарей",Color.WHITE],
		["Свет","bloom","Свечение",0.0,1.3,.01],
		["Свет","bloom_threshold","Порог свечения",.6,3.0,.01],
		["Свет","ssao","Контактные тени SSAO",false],
		["Свет","ssil","Рассеянный свет SSIL",false],
		["Туман","courtyard_fog","Клубы на площадке",0.0,2.0,.01],
		["Туман","background_cards","Дымка между объёмами",0.0,1.5,.01],
		["Туман","volume_density","Объёмный задний туман",0.0,.3,.005],
		["Туман","cloud_scale","Масштаб клубов (меньше — крупнее)",.04,.5,.01],
		["Туман","wind","Скорость тумана",0.0,2.0,.05],
		["Туман","cloud_color","Цвет объёмного тумана",Color.WHITE],
		["Камера","dof","Размытие дали",0.0,.2,.005],
		["Камера","focus_distance","Начало размытия, м",30.0,100.0,1.0]
	]
