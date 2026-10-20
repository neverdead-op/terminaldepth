extends RefCounted
## Переносит анимации из загруженных FBX-паков на скелеты новых врагов.

const Transfer := preload("res://tools/animation_transfer.gd")
static var _source_scenes: Dictionary = {}

const PROFILES := {
	"zombie_crawl": [
		["Zombie_Idle", "res://assets/animations/scary_zombie_source/zombie idle.fbx", true],
		["Zombie_Crawl", "res://assets/animations/scary_zombie_source/zombie crawl.fbx", true],
		["Running_Crawl", "res://assets/animations/scary_zombie_source/running crawl.fbx", true],
		["Zombie_Scratch", "res://assets/animations/scary_zombie_source/zombie attack.fbx", false],
		["Death01", "res://assets/animations/scary_zombie_source/zombie death.fbx", false],
	],
	"zombie": [
		["Zombie_Idle", "res://assets/animations/scary_zombie_source/zombie idle.fbx", true],
		["Zombie_Walk_Fwd", "res://assets/animations/scary_zombie_source/zombie walk.fbx", true],
		["MX_Zombie_Run", "res://assets/animations/scary_zombie_source/zombie run.fbx", true],
		["Zombie_Scratch", "res://assets/animations/scary_zombie_source/zombie attack.fbx", false],
		["Death01", "res://assets/animations/scary_zombie_source/zombie death.fbx", false],
		["Hit_Knockback", "res://assets/animations/scary_zombie_source/zombie dying.fbx", false],
	],
	"rifle_zombie": [
		["Rifle_Idle", "res://animation/shooter pack/combat/rifle aiming idle.fbx", true],
		["Rifle_Walk", "res://animation/shooter pack/combat/walking.fbx", true],
		["Rifle_Run", "res://animation/shooter pack/combat/rifle run.fbx", true],
		["Rifle_Shoot", "res://animation/shooter pack/combat/firing rifle.fbx", false],
		["Rifle_Death", "res://animation/shooter pack/combat/walking to dying.fbx", false],
	],
	# Некромант: обычная походка, вопль — сотворение заклинания.
	"necromancer": [
		["Zombie_Idle", "res://assets/animations/scary_zombie_source/zombie idle.fbx", true],
		["Necro_Walk", "res://animation/shooter pack/combat/walking.fbx", true],
		["Necro_Cast", "res://assets/animations/scary_zombie_source/zombie scream.fbx", false],
		["Death01", "res://assets/animations/scary_zombie_source/zombie death.fbx", false],
	],
	"mutant": [
		["Mutant_Idle", "res://assets/animations/creature_pack_source/mutant breathing idle.fbx", true],
		["Mutant_Walk", "res://assets/animations/creature_pack_source/mutant walking.fbx", true],
		["Mutant_Run", "res://assets/animations/creature_pack_source/mutant run.fbx", true],
		["Mutant_Attack", "res://assets/animations/creature_pack_source/mutant swiping.fbx", false],
		["Mutant_Jump_Attack", "res://assets/animations/creature_pack_source/mutant jump attack.fbx", false],
		["Mutant_Death", "res://assets/animations/creature_pack_source/mutant dying.fbx", false],
	],
}

static func build(target: Skeleton3D, profile: String) -> AnimationLibrary:
	assert(PROFILES.has(profile), "Неизвестный профиль врага: " + profile)
	var library := AnimationLibrary.new()
	for row in PROFILES[profile]:
		var source_path: String = row[1]
		var source: Node = _source_scene(source_path).instantiate()
		var root := Engine.get_main_loop() as SceneTree
		root.root.add_child(source)
		var skeleton := source.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		assert(skeleton != null and player != null, "В анимации не найден скелет или клип: " + source_path)
		var clip := _first_clip(player)
		assert(clip != null, "В файле нет анимационного клипа: " + source_path)
		var name := StringName(row[0])
		library.add_animation(name, Transfer.bake(skeleton, target, clip, bool(row[2])))
		source.free()
	return library

static func _source_scene(path: String) -> PackedScene:
	if not _source_scenes.has(path):
		_source_scenes[path] = load(path) as PackedScene
	assert(_source_scenes[path] != null, "Не удалось загрузить анимацию: " + path)
	return _source_scenes[path]

static func _first_clip(player: AnimationPlayer) -> Animation:
	for name in player.get_animation_list():
		if name != &"RESET":
			return player.get_animation(name)
	return null
