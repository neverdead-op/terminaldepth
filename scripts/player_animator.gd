extends AnimationTree
## Ноги играют направленное движение, верх тела — действие выбранного оружия.
## Для закреплённого лука Bow_Shot синхронизирован с фазами реального выстрела.

const LIBRARY := preload("res://assets/animations/UAL1_Standard.glb")
## Вторая часть библиотеки Quaternius (зомби, реакции на удар, бросок, позы NPC, щит, меч).
const LIBRARY2 := preload("res://assets/animations/UAL2_Standard.glb")
const SHOOTER := preload("res://assets/animations/shooter_native.tres")
const MIXAMO := preload("res://assets/animations/mixamo_fitted.tres")
const SKELETON_PATH := "Armature/Skeleton3D"

@export_group("Какие анимации играть")
@export var idle_anim := &"SP_idle"
## Обычный бег вперёд; диагонали берутся из Rifle 8-Way.
@export var run_anim := &"SP_run_forward"
## Движение со стрельбой: вперёд; назад и в стороны заданы отдельными клипами.
@export var walk_anim := &"SP_walk_forward"
@export var sprint_anim := &"SP_sprint_forward"
@export var roll_anim := &"SP_dive_roll"
@export var death_anim := &"SP_death_from_the_front"
## Руки в покое (держат оружие у пояса).
@export var hold_anim := &"Pistol_Idle"
## Руки при стрельбе (оружие вытянуто вперёд).
@export var aim_anim := &"Pistol_Aim_Neutral"
## Перезарядка (играет только верх тела, растягивается под время перезарядки оружия).
@export var reload_anim := &"MX_Reloading"
@export var pistol_reload_anim := &"Pistol_Reload"
@export var pistol_run_anim := &"MX_Pistol_Run"
@export var pistol_fire_anim := &"Pistol_Shoot"
@export var pistol_fire_duration := 0.22
@export var roll_blend_in := 0.055
## Движения в стороны — отдельные клипы, а не обратная прокрутка бега вперёд.
@export var backward_anim := &"SP_run_backward"
@export var left_anim := &"SP_run_left"
@export var right_anim := &"SP_run_right"
## Спокойный двуручный хват перед корпусом, без прицеливания.
@export var rifle_hold_anim := &"SP_idle"
@export var rifle_fire_anim := &"SC_firing_rifle"
## Настоящий бросок из второй библиотеки, только для верхней части тела.
@export var throw_anim := &"OverhandThrow"
@export var throw_duration := 0.32

@export_group("Подгонка")
## Скорость (м/с), при которой анимация выглядит «родной».
## Если ноги семенят слишком часто — увеличьте; если «плывут» и не успевают за персонажем — уменьшите.
@export var run_anim_speed := 4.8
@export var walk_anim_speed := 1.92
## При плавном снижении скорости переходим на шаг, независимо от момента выстрела.
@export var walk_switch_speed := 2.6
## Отдельный порог шага для огнестрела; 0 использует общий порог.
@export var firearm_walk_switch_speed := 0.0
@export var use_source_stride_speed := true
@export var sprint_anim_speed := 6.3
## Художественная поправка темпа бега после переноса на другой скелет.
@export_range(0.5, 2.0, 0.05) var run_playback_multiplier := 1.0
## Обычный бег с огнестрелом следует длине шага; спринт сохраняет художественный темп.
@export var firearm_run_stride_sync := false
## Время плавного перехода между анимациями ног (сек).
@export var crossfade := 0.15
## Как быстро руки поднимают и опускают оружие.
@export var arms_blend_speed := 12.0

@export_group("Шаги")
## Звук шага и толчок камеры, когда ступня касается пола.
@export var footsteps_enabled := true
## Высота ступни над полом (м), ниже которой считаем, что нога встала.
@export var step_height := 0.035
## Повторное касание разрешается только после настоящего подъёма ступни.
@export var step_release_height := 0.06
@export var step_min_interval := 0.16
var _last_step := -1.0
var _last_step_foot := -1
var step_count := 0
## Насколько камера «проседает» на каждом шаге (м). 0 — выключить.
@export var step_camera_dip := 0.06
@export var sprint_camera_dip := 0.1

var _player  # скрипт игрока (player.gd)
var _playback: AnimationNodeStateMachinePlayback
var _state := &""
var _was_dodging := false
var _roll_length := 1.0
var _upper := 1.0
var _aim := 0.0
var _rifle_pose := 0.0
var _pistol_move := 0.0
var _reload_node: AnimationNodeAnimation
const DIRECTIONS := ["", "ForwardRight", "Right", "BackRight", "Back", "BackLeft", "Left", "ForwardLeft"]
const CLIP_DIRECTIONS := ["forward", "forward_right", "right", "backward_right", "backward", "backward_left", "left", "forward_left"]
var _skeleton: Skeleton3D
var _feet: Array[int] = []
var _foot_down: Array[bool] = [true, true]
var _bow_action_weight := 0.0
var _bow_pose_time := 0.0


func _ready() -> void:
	_player = owner
	var skeleton := get_node(root_node).get_node(SKELETON_PATH) as Skeleton3D
	_skeleton = skeleton
	if _player.fixed_bow_loadout:
		idle_anim = &"Bow_Idle"
		hold_anim = &"Bow_Rest"
		aim_anim = &"Bow_Idle"
		rifle_hold_anim = &"Bow_Idle"
		rifle_fire_anim = &"Bow_Idle"
		pistol_run_anim = &"Bow_Idle"
		reload_anim = &"Bow_Idle"
		pistol_reload_anim = &"Bow_Idle"
	skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_feet = [skeleton.find_bone("ball_l"), skeleton.find_bone("ball_r")]
	var used := [idle_anim, run_anim, walk_anim, sprint_anim, roll_anim, death_anim, hold_anim, aim_anim, reload_anim, throw_anim, pistol_reload_anim, backward_anim, left_anim, right_anim, rifle_hold_anim, rifle_fire_anim, pistol_fire_anim, pistol_run_anim]
	if _player.fixed_bow_loadout: used.append_array([&"Bow_Shot", &"Bow_Rest", &"Bow_Equip", &"BC_aim_walk_right"])
	for prefix in ["walk", "run", "sprint"]:
		for direction in CLIP_DIRECTIONS:
			used.append(StringName("SP_" + prefix + "_" + direction))
	add_animation_library(&"", fit_library(skeleton, used, [roll_anim, reload_anim, pistol_reload_anim, death_anim, throw_anim, pistol_fire_anim]))
	_roll_length = get_animation(roll_anim).length
	tree_root = _build_tree(skeleton)
	active = true
	_playback = get(&"parameters/legs/playback")
	_playback.start(&"Idle")
	_state = &"Idle"
	_player.reload_started.connect(_on_reload_started)
	_player.reload_cancelled.connect(_on_reload_cancelled)


func _on_reload_started(duration: float) -> void:
	var data: WeaponData = _player.weapon_data(_player.current_weapon_index())
	var clip := pistol_reload_anim if data != null and data.icon == &"pistol" else reload_anim
	_reload_node.animation = clip
	set(&"parameters/reload_speed/scale", get_animation(clip).length / maxf(duration, 0.05))
	set(&"parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_shot(data: WeaponData) -> void:
	if data.icon == &"pistol":
		set(&"parameters/pistol_fire_speed/scale", get_animation(pistol_fire_anim).length / maxf(pistol_fire_duration, 0.05))
		set(&"parameters/pistol_fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func play_throw() -> void:
	set(&"parameters/throw_speed/scale", get_animation(throw_anim).length / maxf(throw_duration, 0.05))
	set(&"parameters/throw/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func _on_reload_cancelled() -> void:
	set(&"parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	var velocity := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	var speed := velocity.length()
	var forward: Vector3 = -_player.global_basis.z
	var data: WeaponData = _player.weapon_data(_player.current_weapon_index())
	var two_handed := data != null and data.icon not in [&"pistol", &"mines"]
	var walk_threshold := firearm_walk_switch_speed if not _player.fixed_bow_loadout and firearm_walk_switch_speed > 0.0 else walk_switch_speed

	var state := &"Idle"
	var time_scale := 1.0
	var upper_target := 1.0
	var dodging: bool = _player.is_dodging()

	if _player.is_dead():
		state = &"Death"
		upper_target = 0.0
	elif _player.is_sprinting():
		state = StringName("Sprint" + _direction(velocity, forward))
		time_scale = maxf(speed / sprint_anim_speed, 0.5)
		# У пистолета свой свободный бег рук; винтовочный спринт оставляем только ногам.
		upper_target = 1.0 if data != null and data.icon == &"pistol" else 0.0
	elif speed > 0.3:
		var threshold := walk_threshold + (0.2 if String(_state).begins_with("Walk") else -0.2)
		var prefix := "Walk" if speed < threshold else "Run"
		state = StringName(prefix + _direction(velocity, forward))
		time_scale = maxf(speed / (walk_anim_speed if prefix == "Walk" else run_anim_speed), 0.15)

	if _player.fixed_bow_loadout and not _player.is_dead() and not _player.is_sprinting():
		upper_target = 1.0 if _player._bow_draw_elapsed > 0 or _player._bow_release_left > 0 or _player._bow_equip_left > 0 or speed < .3 else 0.0
		var legs := (tree_root as AnimationNodeBlendTree).get_node(&"legs") as AnimationNodeStateMachine
		var right_walk := legs.get_node(&"WalkRight") as AnimationNodeAnimation
		right_walk.animation = &"BC_aim_walk_right" if _player.is_firing() else &"SP_walk_right"
	if use_source_stride_speed and (String(state).begins_with("Walk") or String(state).begins_with("Run") or String(state).begins_with("Sprint")):
		var machine := (tree_root as AnimationNodeBlendTree).get_node(&"legs") as AnimationNodeStateMachine
		var clip_node := machine.get_node(state) as AnimationNodeAnimation
		var clip := get_animation(clip_node.animation)
		var source_speed: float = clip.get_meta("locomotion_speed", 0.0)
		if source_speed > 0.1:
			time_scale = maxf(speed / source_speed, 0.15)
	if String(state).begins_with("Run") or String(state).begins_with("Sprint"):
		if not (firearm_run_stride_sync and not _player.fixed_bow_loadout and String(state).begins_with("Run")):
			time_scale *= run_playback_multiplier

	# Ходьба живёт под полным клипом переката и уже готова к моменту подъёма.
	var rolling: bool = (dodging or _player._recovery_left > 0) and not _player.is_dead()
	if dodging and not _was_dodging:
		set(&"parameters/roll_seek/seek_request", 0.0)
		set(&"parameters/pistol_fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)
	if _playback.get_current_node() != state:
		_playback.travel(state)
	_state = &"Roll" if rolling else state
	_was_dodging = dodging
	var roll_duration: float = _player.dodge_duration + _player.dodge_recovery
	# Точная общая шкала времени для полного клипа и физической траектории.
	# Seek не обрезает клип: последовательно проходим все его фазы до последнего кадра.
	set(&"parameters/roll_speed/scale", 0.0 if rolling else 1.0)
	if rolling or _player._roll_elapsed >= roll_duration:
		set(&"parameters/roll_seek/seek_request", _roll_length * _player.roll_source_phase(_player._roll_elapsed))
	var roll_weight := 0.0
	if rolling:
		roll_weight = smoothstep(0.0, roll_blend_in, _player._roll_elapsed)
		roll_weight *= 1.0 - smoothstep(_player.dodge_duration, roll_duration, _player._roll_elapsed)
	set(&"parameters/roll_mix/blend_amount", roll_weight)

	var aim_target := 1.0 if _player.is_firing() and not _player.is_reloading() else 0.0
	_rifle_pose = move_toward(_rifle_pose, 1.0 if two_handed else 0.0, arms_blend_speed * delta)
	set(&"parameters/weapon_pose/blend_amount", _rifle_pose)
	_upper = move_toward(_upper, upper_target, arms_blend_speed * delta)
	_aim = move_toward(_aim, aim_target, arms_blend_speed * delta)
	set(&"parameters/legs_speed/scale", time_scale)
	set(&"parameters/upper/blend_amount", _upper)
	# Бег с пистолетом нужен и без стрельбы. При выстреле его перекрывает слой прицела.
	var pistol_move_target := clampf(speed / maxf(walk_threshold, 0.3), 0, 1)
	_pistol_move = move_toward(_pistol_move, pistol_move_target, arms_blend_speed * delta)
	set(&"parameters/pistol_hold/blend_amount", _pistol_move)
	set(&"parameters/arms/blend_amount", _aim)
	set(&"parameters/rifle_arms/blend_amount", _aim)
	if _player.fixed_bow_loadout:
		var drawing: bool = _player._bow_draw_elapsed > 0
		var releasing: bool = _player._bow_release_left > 0
		if drawing: _bow_pose_time = _player._bow_draw_elapsed
		elif releasing: _bow_pose_time = _player.bow_draw_time + _player.bow_release_time - _player._bow_release_left
		_bow_action_weight = move_toward(_bow_action_weight, 1.0 if drawing or releasing else 0.0, delta * 10.0)
		set(&"parameters/bow_seek/seek_request", _bow_pose_time)
		set(&"parameters/bow_speed/scale", 0.0)
		set(&"parameters/bow_mix/blend_amount", _bow_action_weight)
		set(&"parameters/bow_equip_seek/seek_request", _player._bow_equip_duration - _player._bow_equip_left)
		set(&"parameters/bow_equip_speed/scale", 0.0)
		set(&"parameters/bow_equip_mix/blend_amount", minf(1.0, _player._bow_equip_left / .12))



## Направление относительно прицела: восемь самостоятельных анимаций.
func _direction(velocity: Vector3, forward: Vector3) -> String:
	if velocity.length_squared() < 0.01:
		return ""
	var facing := forward.dot(velocity.normalized())
	var sideways: float = _player.global_basis.x.dot(velocity.normalized())
	var sector := wrapi(roundi(atan2(sideways, facing) / (PI / 4)), 0, 8)
	return DIRECTIONS[sector]


## Читаем окончательную позу после обновления анимации, а не позу прошлого кадра.
func _on_skeleton_updated() -> void:
	_update_footsteps(_state)


## Контакт со сменой порогов и чередованием ног защищает от дрожания и тройных шагов.
func _update_footsteps(state: StringName) -> void:
	if not footsteps_enabled or _skeleton == null:
		return
	var moving := String(state).begins_with("Run") or String(state).begins_with("Walk") or String(state).begins_with("Sprint")
	moving = moving and _player.is_on_floor() and Vector2(_player.velocity.x, _player.velocity.z).length() > 0.35
	if not moving: _last_step_foot = -1
	var floor_y: float = _player.global_position.y
	for i in _feet.size():
		var foot := _skeleton.global_transform * _skeleton.get_bone_global_pose(_feet[i]).origin
		var height := foot.y - floor_y
		var down := height < (step_release_height if _foot_down[i] else step_height)
		if down and not _foot_down[i] and moving and i != _last_step_foot and Time.get_ticks_msec() / 1000.0 - _last_step > step_min_interval:
			_last_step = Time.get_ticks_msec() / 1000.0
			_last_step_foot = i
			step_count += 1
			Sfx.play_footstep(foot, String(state).begins_with("Sprint"))
			var camera := get_viewport().get_camera_3d()
			if camera != null and camera.get_parent().has_method("add_dip"):
				camera.get_parent().add_dip(sprint_camera_dip if String(state).begins_with("Sprint") else step_camera_dip)
		_foot_down[i] = down


## Анимации сделаны на манекене с чуть другими пропорциями. Чтобы модель не перекашивало,
## оставляем только повороты костей, а высоту таза масштабируем под рост нашей модели.
## Общая функция — ей пользуются и игрок, и персонажи на базе (npc_model.gd).
## names — какие анимации взять, once — какие из них не зацикливать.
## Родная библиотека выбранного героя; NPC без профиля продолжают использовать старую.
static func native_library(skeleton: Skeleton3D) -> AnimationLibrary:
	var model := skeleton.get_parent().get_parent()
	var path: String = model.get_meta("animation_library_path", "")
	return load(path) as AnimationLibrary if not path.is_empty() else SHOOTER


static func fit_library(skeleton: Skeleton3D, used: Array, once: Array) -> AnimationLibrary:
	var pelvis_rest := skeleton.get_bone_rest(skeleton.find_bone("pelvis")).origin
	var pelvis_anim := _pelvis_position(LIBRARY.get_animation(&"A_TPose"))
	var ratio := pelvis_rest.length() / pelvis_anim.length() if pelvis_anim.length() > 0.0 else 1.0

	var lib := AnimationLibrary.new()
	var native := native_library(skeleton)
	for anim_name in used:
		if lib.has_animation(anim_name):
			continue
		var native_rig := skeleton.get_bone_parent(skeleton.find_bone("pelvis")) < 0
		var src: AnimationLibrary = native if native_rig and native.has_animation(anim_name) else (MIXAMO if MIXAMO.has_animation(anim_name) else (LIBRARY if LIBRARY.has_animation(anim_name) else LIBRARY2))
		assert(src.has_animation(anim_name), "Не найдена анимация: " + String(anim_name))
		var anim: Animation = src.get_animation(anim_name).duplicate(true)
		var position_ratio := ratio
		if src.has_meta("pelvis_rest"):
			var baked_rest: Vector3 = src.get_meta("pelvis_rest")
			position_ratio = pelvis_rest.length() / baked_rest.length()
		for i in range(anim.get_track_count() - 1, -1, -1):
			var type := anim.track_get_type(i)
			var bone := String(anim.track_get_path(i).get_concatenated_subnames())
			if type == Animation.TYPE_SCALE_3D or (type == Animation.TYPE_POSITION_3D and bone != "pelvis"):
				anim.remove_track(i)
			elif type == Animation.TYPE_POSITION_3D:
				for k in anim.track_get_key_count(i):
					anim.track_set_key_value(i, k, anim.track_get_key_value(i, k) * position_ratio)
		anim.loop_mode = Animation.LOOP_NONE if anim_name in once else Animation.LOOP_LINEAR
		lib.add_animation(anim_name, anim)
	return lib


static func _pelvis_position(anim: Animation) -> Vector3:
	for i in anim.get_track_count():
		if anim.track_get_type(i) == Animation.TYPE_POSITION_3D \
				and String(anim.track_get_path(i).get_concatenated_subnames()) == "pelvis":
			return anim.track_get_key_value(i, 0)
	return Vector3.ZERO


## Схема смешивания:
##   legs (бег/спринт/перекат) → legs_speed (подгонка скорости) ─┐
##   hold + aim → arms (опущено/поднято оружие) → reload (поверх — перезарядка) ─┴→ upper → выход
func _build_tree(skeleton: Skeleton3D) -> AnimationNodeBlendTree:
	var legs := AnimationNodeStateMachine.new()
	var states := {
		&"Idle": [idle_anim, false], &"Death": [death_anim, false],
	}
	for pair in [["Run", "run"], ["Walk", "walk"], ["Sprint", "sprint"]]:
		for i in DIRECTIONS.size():
			var clip := StringName("SP_" + pair[1] + "_" + CLIP_DIRECTIONS[i])
			if pair[0] == "Run":
				clip = {0: run_anim, 2: right_anim, 4: backward_anim, 6: left_anim}.get(i, clip)
			elif i == 0:
				clip = walk_anim if pair[0] == "Walk" else sprint_anim
			states[StringName(pair[0] + DIRECTIONS[i])] = [clip, false]

	for state in states:
		var node := AnimationNodeAnimation.new()
		node.animation = states[state][0]
		if states[state][1]:
			node.play_mode = AnimationNodeAnimation.PLAY_MODE_BACKWARD
		legs.add_node(state, node)
	for from in states:
		for to in states:
			if from != to:
				var transition := AnimationNodeStateMachineTransition.new()
				transition.xfade_time = crossfade
				var moving_from := String(from).begins_with("Walk") or String(from).begins_with("Run") or String(from).begins_with("Sprint")
				var moving_to := String(to).begins_with("Walk") or String(to).begins_with("Run") or String(to).begins_with("Sprint")
				if moving_from and moving_to:
					transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_SYNC
				legs.add_transition(from, to, transition)

	var tree := AnimationNodeBlendTree.new()
	tree.add_node(&"legs", legs)
	tree.add_node(&"legs_speed", AnimationNodeTimeScale.new())
	var hold := AnimationNodeAnimation.new()
	hold.animation = hold_anim
	tree.add_node(&"hold", hold)
	var pistol_run := AnimationNodeAnimation.new()
	pistol_run.animation = pistol_run_anim
	tree.add_node(&"pistol_run", pistol_run)
	tree.add_node(&"pistol_hold", AnimationNodeBlend2.new())
	var aim := AnimationNodeAnimation.new()
	aim.animation = aim_anim
	tree.add_node(&"aim", aim)
	tree.add_node(&"arms", AnimationNodeBlend2.new())
	var rifle_hold := AnimationNodeAnimation.new()
	rifle_hold.animation = rifle_hold_anim
	tree.add_node(&"rifle_hold", rifle_hold)
	var rifle_fire := AnimationNodeAnimation.new()
	rifle_fire.animation = rifle_fire_anim
	tree.add_node(&"rifle_fire", rifle_fire)
	tree.add_node(&"rifle_arms", AnimationNodeBlend2.new())
	tree.add_node(&"weapon_pose", AnimationNodeBlend2.new())
	var pistol_fire := AnimationNodeAnimation.new()
	pistol_fire.animation = pistol_fire_anim
	tree.add_node(&"pistol_fire_anim", pistol_fire)
	tree.add_node(&"pistol_fire_speed", AnimationNodeTimeScale.new())
	var fire := AnimationNodeOneShot.new()
	fire.fadein_time = 0.025
	fire.fadeout_time = 0.06
	tree.add_node(&"pistol_fire", fire)
	var reload := AnimationNodeAnimation.new()
	_reload_node = reload
	reload.animation = reload_anim
	tree.add_node(&"reload_anim", reload)
	tree.add_node(&"reload_speed", AnimationNodeTimeScale.new())
	var reload_shot := AnimationNodeOneShot.new()
	reload_shot.fadein_time = 0.1
	reload_shot.fadeout_time = 0.15
	tree.add_node(&"reload", reload_shot)
	var throw_node := AnimationNodeAnimation.new()
	throw_node.animation = throw_anim
	tree.add_node(&"throw_anim", throw_node)
	tree.add_node(&"throw_speed", AnimationNodeTimeScale.new())
	var throw_shot := AnimationNodeOneShot.new()
	throw_shot.fadein_time = 0.04
	throw_shot.fadeout_time = 0.06
	tree.add_node(&"throw", throw_shot)

	# Верх тела: всё, что растёт от spine_02 (грудь, шея, голова, руки).
	var upper := AnimationNodeBlend2.new()
	upper.filter_enabled = true
	var stack := [skeleton.find_bone("spine_01" if _player.fixed_bow_loadout else "spine_02")]
	while not stack.is_empty():
		var bone: int = stack.pop_back()
		upper.set_filter_path(NodePath("%s:%s" % [SKELETON_PATH, skeleton.get_bone_name(bone)]), true)
		stack.append_array(skeleton.get_bone_children(bone))
	tree.add_node(&"upper", upper)

	tree.connect_node(&"legs_speed", 0, &"legs")
	tree.connect_node(&"pistol_hold", 0, &"hold")
	tree.connect_node(&"pistol_hold", 1, &"pistol_run")
	tree.connect_node(&"arms", 0, &"pistol_hold")
	tree.connect_node(&"arms", 1, &"aim")
	tree.connect_node(&"upper", 0, &"legs_speed")
	tree.connect_node(&"reload_speed", 0, &"reload_anim")
	tree.connect_node(&"rifle_arms", 0, &"rifle_hold")
	tree.connect_node(&"rifle_arms", 1, &"rifle_fire")
	tree.connect_node(&"pistol_fire_speed", 0, &"pistol_fire_anim")
	tree.connect_node(&"pistol_fire", 0, &"arms")
	tree.connect_node(&"pistol_fire", 1, &"pistol_fire_speed")
	tree.connect_node(&"weapon_pose", 0, &"pistol_fire")
	tree.connect_node(&"weapon_pose", 1, &"rifle_arms")
	tree.connect_node(&"reload", 0, &"weapon_pose")
	tree.connect_node(&"reload", 1, &"reload_speed")
	tree.connect_node(&"throw_speed", 0, &"throw_anim")
	tree.connect_node(&"throw", 0, &"reload")
	tree.connect_node(&"throw", 1, &"throw_speed")
	if _player.fixed_bow_loadout:
		var bow_clip := AnimationNodeAnimation.new()
		bow_clip.animation = &"Bow_Shot"
		tree.add_node(&"bow_clip", bow_clip)
		tree.add_node(&"bow_seek", AnimationNodeTimeSeek.new())
		tree.add_node(&"bow_speed", AnimationNodeTimeScale.new())
		var rest := AnimationNodeAnimation.new()
		rest.animation = &"Bow_Rest"
		tree.add_node(&"bow_rest", rest)
		tree.add_node(&"bow_mix", AnimationNodeBlend2.new())
		tree.connect_node(&"bow_seek", 0, &"bow_clip")
		tree.connect_node(&"bow_speed", 0, &"bow_seek")
		tree.connect_node(&"bow_mix", 0, &"bow_rest")
		tree.connect_node(&"bow_mix", 1, &"bow_speed")
		var equip := AnimationNodeAnimation.new()
		equip.animation = &"Bow_Equip"
		tree.add_node(&"bow_equip", equip)
		tree.add_node(&"bow_equip_seek", AnimationNodeTimeSeek.new())
		tree.add_node(&"bow_equip_speed", AnimationNodeTimeScale.new())
		tree.add_node(&"bow_equip_mix", AnimationNodeBlend2.new())
		tree.connect_node(&"bow_equip_seek", 0, &"bow_equip")
		tree.connect_node(&"bow_equip_speed", 0, &"bow_equip_seek")
		tree.connect_node(&"bow_equip_mix", 0, &"bow_mix")
		tree.connect_node(&"bow_equip_mix", 1, &"bow_equip_speed")
		tree.connect_node(&"upper", 1, &"bow_equip_mix")
	else:
		tree.connect_node(&"upper", 1, &"throw")
	var roll_clip := AnimationNodeAnimation.new()
	roll_clip.animation = roll_anim
	tree.add_node(&"roll_clip", roll_clip)
	tree.add_node(&"roll_seek", AnimationNodeTimeSeek.new())
	tree.add_node(&"roll_speed", AnimationNodeTimeScale.new())
	var roll_mix := AnimationNodeBlend2.new()
	roll_mix.sync = true # Полный клип доигрывает даже при плавном уходе в ходьбу.
	tree.add_node(&"roll_mix", roll_mix)
	tree.connect_node(&"roll_seek", 0, &"roll_clip")
	tree.connect_node(&"roll_speed", 0, &"roll_seek")
	tree.connect_node(&"roll_mix", 0, &"upper")
	tree.connect_node(&"roll_mix", 1, &"roll_speed")
	tree.connect_node(&"output", 0, &"roll_mix")
	return tree
