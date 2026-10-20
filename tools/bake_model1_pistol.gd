extends SceneTree
## Отдельные спокойные позы пистолета для MODEL 1; исходные библиотеки не перезаписываются.
const Model = preload("res://scripts/shooter_model.gd")
const Transfer = preload("res://tools/animation_transfer.gd")
func _initialize() -> void:
 run.call_deferred()
func run() -> void:
 var target = Model.new()
 target.source_path = "res://assets/characters/model1/v1/model1.glb"
 root.add_child(target)
 var to:Skeleton3D = target.get_node("Armature/Skeleton3D")
 var source = load("res://assets/characters/base/Superhero_Male_FullBody.gltf").instantiate()
 root.add_child(source)
 var from:Skeleton3D = source.find_child("Skeleton3D",true,false)
 var lib = AnimationLibrary.new()
 var original:AnimationLibrary = load("res://assets/animations/UAL1_Standard.glb")
 # Свободные руки в ожидании и при беге. Боевой хват остаётся в основном профиле.
 for pair in [["Pistol_Rest","Idle"],["Pistol_Move","Jog_Fwd"]]:
  var clip = Transfer.bake(from,to,original.get_animation(pair[1]),true)
  clip.set_meta("source_file","res://assets/animations/UAL1_Standard.glb")
  clip.set_meta("source_clip",pair[1])
  lib.add_animation(pair[0],clip)
 lib.set_meta("pelvis_rest",to.get_bone_rest(to.find_bone("pelvis")).origin)
 assert(ResourceSaver.save(lib,"res://assets/animations/model1_pistol.tres")==OK)
 source.free()
 target.free()
 print("PISTOL_BAKE_OK")
 quit()
