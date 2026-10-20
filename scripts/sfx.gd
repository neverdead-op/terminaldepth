extends Node
## Звуки игры. Доступен из любого скрипта как Sfx: Sfx.play(&"hit_wall", позиция).
## Держит пул проигрывателей и не даёт одному звуку звучать слишком много раз одновременно —
## иначе сотня смертей врагов в один момент превратится в оглушающую кашу.
## Цифры можно менять в Inspector, открыв scenes/sfx.tscn.

const SOUNDS := {
	&"bow_release": preload("res://assets/sounds/combat/bow_release.wav"),
	&"bow_draw": preload("res://assets/sounds/combat/bow_draw.wav"),
	&"bow_impact": preload("res://assets/sounds/combat/bow_impact.wav"),
	&"shot_plasma": preload("res://assets/sounds/combat/plasma_cutter_1.wav"),
	&"shot_pistol": [preload("res://assets/sounds/combat/pistol_1.wav")],
	&"shot_rifle": [preload("res://assets/sounds/combat/rifle_1.wav"), preload("res://assets/sounds/combat/rifle_2.wav"), preload("res://assets/sounds/combat/rifle_3.wav")],
	&"shot_shotgun": [preload("res://assets/sounds/combat/shotgun_1.wav"), preload("res://assets/sounds/combat/shotgun_2.wav"), preload("res://assets/sounds/combat/shotgun_3.wav")],
	&"reload_start": preload("res://assets/sounds/combat/reload_start_1.wav"),
	&"reload_end": preload("res://assets/sounds/combat/reload_end_1.wav"),
	&"empty": preload("res://assets/sounds/empty.wav"),
	&"heal": preload("res://assets/sounds/heal.wav"),
	&"crawler_bite": preload("res://assets/sounds/crawler_bite.wav"),
	&"crawler_death": preload("res://assets/sounds/crawler_death.wav"),
	&"vent": preload("res://assets/sounds/vent.wav"),
	&"door_open": preload("res://assets/sounds/door_open.wav"),
	&"door_close": preload("res://assets/sounds/door_close.wav"),
	&"door_locked": preload("res://assets/sounds/door_locked.wav"),
	&"door_unlock": preload("res://assets/sounds/door_unlock.wav"),
	&"key_pickup": preload("res://assets/sounds/key_pickup.wav"),
	&"spit": preload("res://assets/sounds/spit.wav"),
	&"acid_splash": preload("res://assets/sounds/acid_splash.wav"),
	&"brute_slam": preload("res://assets/sounds/brute_slam.wav"),
	&"brute_death": preload("res://assets/sounds/brute_death.wav"),
	&"ui_click": preload("res://assets/sounds/ui_click.wav"),
	&"ui_open": preload("res://assets/sounds/ui_open.wav"),
	&"portal_open": preload("res://assets/sounds/portal_open.wav"),
	&"portal_enter": preload("res://assets/sounds/portal_enter.wav"),
	&"level_up": preload("res://assets/sounds/level_up.wav"),
	&"zap": preload("res://assets/sounds/zap.wav"),
	# Попадание по врагу: два удара от автора (universfield), вырезаны и выровнены по громкости; выбирается случайный.
	&"hit_flesh": [preload("res://assets/sounds/hit_punch_1.wav"), preload("res://assets/sounds/hit_punch_2.wav")],
	&"hit_wall": preload("res://assets/sounds/hit_wall.wav"),
	&"explosion": preload("res://assets/sounds/explosion.wav"),
	&"dodge": preload("res://assets/sounds/dodge.wav"),
	&"roll_contact": preload("res://assets/sounds/combat/roll_contact_1.wav"),
	&"step": [preload("res://assets/sounds/combat/step_1.wav"), preload("res://assets/sounds/combat/step_2.wav"), preload("res://assets/sounds/combat/step_3.wav"), preload("res://assets/sounds/combat/step_4.wav")],
	&"step_run": [preload("res://assets/sounds/combat/step_run_1.wav"), preload("res://assets/sounds/combat/step_run_2.wav"), preload("res://assets/sounds/combat/step_run_3.wav"), preload("res://assets/sounds/combat/step_run_4.wav")],
	&"shot_smg": preload("res://assets/sounds/shot_smg.wav"),
	&"shot_heavy_pistol": preload("res://assets/sounds/shot_heavy_pistol.wav"),
	&"shot_magnum": preload("res://assets/sounds/shot_magnum.wav"),
	&"shot_machine_pistol": preload("res://assets/sounds/shot_machine_pistol.wav"),
	&"shot_carbine": preload("res://assets/sounds/shot_carbine.wav"),
	&"shot_battle": preload("res://assets/sounds/shot_battle.wav"),
	&"shot_marksman": preload("res://assets/sounds/shot_marksman.wav"),
	&"shot_lmg": preload("res://assets/sounds/shot_lmg.wav"),
	&"shot_sniper": preload("res://assets/sounds/shot_sniper.wav"),
	&"shot_bow": preload("res://assets/sounds/shot_bow.wav"),
	&"shot_stake": preload("res://assets/sounds/shot_stake.wav"),  # коломёт: вырезанный выстрел из звука автора, +6 дБ
	&"shot_grenade": preload("res://assets/sounds/shot_grenade.wav"),
	&"shot_flame": preload("res://assets/sounds/shot_flame.wav"),
	&"chest_open": preload("res://assets/sounds/chest_open.wav"),
	&"unique_drop": preload("res://assets/sounds/unique_drop.wav"),
	&"boss_roar": preload("res://assets/sounds/boss_roar.wav"),
	# Зомби: нарезка из звуков автора (Новая папка, dragon-studio), три рыка и два предсмертных стона.
	&"zombie_growl": [preload("res://assets/sounds/zombie_growl_1.wav"), preload("res://assets/sounds/zombie_growl_2.wav"), preload("res://assets/sounds/zombie_growl_3.wav")],
	&"zombie_death": [preload("res://assets/sounds/zombie_death_1.wav"), preload("res://assets/sounds/zombie_death_2.wav")],
	&"zombie_attack": preload("res://assets/sounds/zombie_attack.wav"),
	&"gore_splat": preload("res://assets/sounds/gore_splat.wav"),
	&"explosion_big": preload("res://assets/sounds/explosion_big.wav"),
	&"alarm": preload("res://assets/sounds/alarm.wav"),
}
## Фоновые петли (из библиотеки Sonniss, tools/import_sonniss.py).
const AMBIENTS := {
	&"station": preload("res://assets/sounds/ambient_station.ogg"),
	&"industrial": preload("res://assets/sounds/ambient_industrial.ogg"),
	&"reactor": preload("res://assets/sounds/ambient_reactor.ogg"),
}
## Фоновая «музыка» (тёмные дроны из Sonniss): база — спокойная, этажи — тревожная (по очереди).
const MUSIC := {
	&"hub": [preload("res://assets/sounds/music_hub.ogg")],
	&"floor": [preload("res://assets/sounds/music_floor.ogg"), preload("res://assets/sounds/music_floor2.ogg")],
}

@export_group("Громкость, дБ (0 — как в файле, −6 — примерно вдвое тише)")
## Громкость выстрелов задаётся в файле оружия (data/weapons), здесь — всё остальное.
@export var hit_flesh_volume := -5.0
@export var hit_wall_volume := -16.0
@export var explosion_volume := -4.0
@export var dodge_volume := -12.0
@export var roll_contact_volume := -14.0
@export var step_volume := -12.0
@export var reload_volume := -10.0
@export var heal_volume := -8.0
@export var enemy_volume := -10.0
@export var door_volume := -12.0
@export var pickup_volume := -8.0
## Громкость фона: гул станции на базе и в отсеках.
@export var ambient_volume := -20.0
## Громкость фоновой музыки (0 — как в файле; −80 — выключить).
@export var music_volume := -16.0

@export_group("Ограничения")
## Сколько проигрывателей всего. Больше — больше звуков сразу, но дороже.
## Викторианский проход: электронные сигналы и роботизированные звуки временно выключены.
@export var victorian_audio := true
const FUTURISTIC_SOUNDS := [&"zap", &"shot_plasma", &"shot_bow", &"shot_lmg", &"alarm", &"portal_open", &"portal_enter", &"door_open", &"door_close", &"level_up", &"heal", &"key_pickup", &"unique_drop"]
@export var pool_size := 32
## Сколько копий одного и того же звука может играть одновременно.
@export var max_same_sound := 3
## Минимальная пауза между запусками одного звука (сек). Склеивает звуки одного кадра.
@export var min_interval := 0.03
## Случайный разброс высоты, чтобы повторы не звучали одинаково (0.08 = ±8%).
@export_range(0.0, 0.3) var pitch_variation := 0.08
@export_range(0.0, 0.1) var shot_pitch_variation := 0.025

@export_group("Слышимость")
## Расстояние, на котором звук играет в полную громкость. Камера висит примерно в 17 м от игрока.
@export var unit_size := 18.0
@export var max_distance := 80.0

var _players: Array[AudioStreamPlayer3D] = []
var _started_at: Dictionary = {}  # проигрыватель -> время запуска
var _last_play: Dictionary = {}   # имя звука -> время последнего запуска
var _ambient: AudioStreamPlayer
var _ambient_id := &""
var _ambient_check := 0.0
var _music: AudioStreamPlayer
var _music_id := &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # звуки интерфейса играют и на паузе
	for i in pool_size:
		var p := AudioStreamPlayer3D.new()
		p.unit_size = unit_size
		p.max_distance = max_distance
		p.attenuation_filter_cutoff_hz = 20500.0  # без «приглушения» вдали
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = music_volume
	add_child(_music)
	_music.finished.connect(func() -> void: _play_music_track())
	_ambient = AudioStreamPlayer.new()
	_ambient.volume_db = ambient_volume
	add_child(_ambient)


## Фон под уровень: на базе — тихий гул корабля, на этажах — индустриальный гул отсеков.
func _process(delta: float) -> void:
	_ambient_check -= delta
	if _ambient_check > 0.0:
		return
	_ambient_check = 0.5
	var scene := get_tree().current_scene
	var want := &""
	if scene != null:
		if "map_rects" in scene:
			want = &"industrial"
		elif scene.name == &"Hub":
			want = &"station"
	set_ambient(want)
	set_music(&"floor" if want == &"industrial" else (&"hub" if want == &"station" else &""))


func set_music(id: StringName) -> void:
	if id == _music_id:
		return
	_music_id = id
	if id == &"":
		_music.stop()
		return
	_play_music_track()


func _play_music_track() -> void:
	if _music_id == &"":
		return
	var tracks: Array = MUSIC[_music_id]
	var stream: AudioStream = tracks.pick_random().duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = tracks.size() == 1
	_music.stream = stream
	_music.volume_db = music_volume
	_music.play()


func set_ambient(id: StringName) -> void:
	if victorian_audio and id in [&"station", &"industrial", &"reactor"]: id = &""
	if id == _ambient_id:
		return
	_ambient_id = id
	_ambient.stop()
	if id == &"":
		return
	var stream: AudioStream = AMBIENTS[id].duplicate()
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	_ambient.stream = stream
	_ambient.volume_db = ambient_volume
	_ambient.play()


## Один контакт ноги — один короткий звук; хвост предыдущего шага не наслаивается.
func play_footstep(at: Vector3, sprinting: bool) -> void:
	for player in _players:
		if player.playing and player.get_meta("sound_id", &"") in [&"step", &"step_run"]:
			player.stop()
	play(&"step_run" if sprinting else &"step", at)


## volume_db — добавка к громкости (например, своя громкость у каждого оружия).
func play(sound: StringName, at: Vector3, volume_db := 0.0) -> void:
	if victorian_audio and sound in FUTURISTIC_SOUNDS: return
	var entry = SOUNDS.get(sound)
	var stream: AudioStream = entry.pick_random() if entry is Array else entry
	if stream == null:
		push_warning("Нет звука: %s" % sound)
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_play.get(sound, -1.0)) < min_interval:
		return

	var same := 0
	var free: AudioStreamPlayer3D = null
	var oldest: AudioStreamPlayer3D = null
	var oldest_same: AudioStreamPlayer3D = null
	for p in _players:
		if p.playing:
			if p.get_meta("sound_id", &"") == sound:
				same += 1
				if oldest_same == null or _started_at[p] < _started_at[oldest_same]:
					oldest_same = p
			if oldest == null or _started_at[p] < _started_at[oldest]:
				oldest = p
		elif free == null:
			free = p
	var player := free if free != null else oldest
	var limit := mini(max_same_sound, 2) if sound in [&"shot_rifle", &"shot_carbine"] else max_same_sound
	if same >= limit:
		# Выстрелы очередью: новый выстрел заменяет самый старый того же звука (хвосты не копятся в кашу).
		# Остальные звуки при переполнении просто пропускаем.
		if not String(sound).begins_with("shot_"):
			return
		player = oldest_same
	if player == null:
		return
	_last_play[sound] = now
	_started_at[player] = now
	player.stream = stream
	player.set_meta("sound_id", sound)
	player.volume_db = _volume_for(sound) + volume_db
	var variation := shot_pitch_variation if String(sound).begins_with("shot_") or sound in [&"step", &"step_run"] else pitch_variation
	player.pitch_scale = 1.0 + randf_range(-variation, variation)
	player.global_position = at
	player.play()


func _volume_for(sound: StringName) -> float:
	match sound:
		&"hit_flesh": return hit_flesh_volume
		&"hit_wall": return hit_wall_volume
		&"explosion": return explosion_volume
		&"dodge": return dodge_volume
		&"roll_contact": return roll_contact_volume
		&"step", &"step_run": return step_volume
		&"reload_start", &"reload_end", &"empty": return reload_volume
		&"heal": return heal_volume
		&"crawler_bite", &"crawler_death", &"vent", &"spit", &"acid_splash", &"zap": return enemy_volume
		&"brute_slam", &"brute_death", &"boss_roar", &"explosion_big": return enemy_volume + 4.0
		&"zombie_growl", &"zombie_attack", &"zombie_death", &"gore_splat": return enemy_volume - 2.0
		&"alarm": return door_volume
		&"chest_open": return door_volume + 4.0
		&"ui_click", &"ui_open": return pickup_volume
		&"door_open", &"door_close", &"door_locked", &"door_unlock": return door_volume
		&"key_pickup": return pickup_volume
		&"portal_open", &"portal_enter": return door_volume + 4.0
	return 0.0


func _exit_tree() -> void:
	# Освобождаем декодеры до уничтожения звукового сервера, включая запуск без окна.
	for player in _players:
		player.stop()
		player.stream = null
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
