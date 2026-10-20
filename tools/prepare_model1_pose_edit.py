"""Отдельная копия со скелетом и игровыми позами для ручной настройки; без экспорта в игру."""
import bpy,json,math
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
R=Path(__file__).resolve().parents[1];OUT=R/'art_source/model1_pose_edit'
OUT.mkdir(parents=True,exist_ok=True);(OUT/'.gdignore').touch()
bpy.ops.wm.open_mainfile(filepath=str(R/'art_source/model1_v1/model1_rigged.blend'))
data=json.loads((OUT/'game_poses.json').read_text())
rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.context.scene.objects if o.type=='MESH')
names={'Hips':'pelvis','Spine':'spine_01','Spine1':'spine_02','Spine2':'spine_03','Neck':'neck_01','Head':'Head','HeadTop_End':'head_leaf'}
for side,suffix in [('Left','l'),('Right','r')]:
 for src,dst in [('Shoulder','clavicle'),('Arm','upperarm'),('ForeArm','lowerarm'),('Hand','hand'),('UpLeg','thigh'),('Leg','calf'),('Foot','foot'),('ToeBase','ball'),('Toe_End','ball_leaf')]:names[side+src]=dst+'_'+suffix
 for finger in ['Index','Middle','Ring','Pinky','Thumb']:
  for joint in range(1,5):names[f'{side}Hand{finger}{joint}']=f'{finger.lower()}_{joint:02d}'+('_leaf' if joint==4 else '')+'_'+suffix
def matrix(values):return Matrix([values[i:i+4] for i in range(0,16,4)])
C=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
Ci=C.inverted()
rig.animation_data_clear()
actions={}
for clip,frames in data['actions'].items():
 action=bpy.data.actions.new('01_Стойка_из_игры' if clip=='SP_idle' else '02_Ходьба_из_игры')
 action.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=action
 for f,frame in enumerate(frames,1):
  for pb in rig.pose.bones:
   alias=names.get(pb.name,pb.name)
   if alias not in frame:continue
   rest=matrix(data['rest'][alias]);pose=matrix(frame[alias])
   pb.matrix=C@pose@rest.inverted()@Ci@pb.bone.matrix_local
   pb.rotation_mode='QUATERNION'
   pb.keyframe_insert('location',frame=f,group=pb.name)
   pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
   pb.keyframe_insert('scale',frame=f,group=pb.name)
 actions[clip]=action
rig.animation_data.action=actions['SP_idle']
scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=1;scene.frame_end=len(data['actions']['SP_idle']);scene.frame_set(1)
rig.show_in_front=True;rig.data.display_type='OCTAHEDRAL';rig.data.show_names=False
for bone in rig.data.bones:
 bone.hide=False
 rig.pose.bones[bone.name].select=False
 if any(s in bone.name for s in ['Thumb','Index','Middle','Ring','Pinky']):bone.hide=True
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='POSE')
bone=rig.data.bones.get('LeftUpLeg');rig.pose.bones[bone.name].select=True;rig.data.bones.active=bone
scene.tool_settings.use_keyframe_insert_auto=True
scene.transform_orientation_slots[0].type='LOCAL'
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='VIEW_3D':
   space=area.spaces.active
   space.shading.type='MATERIAL'
   space.overlay.show_floor=False;space.overlay.show_axis_x=False;space.overlay.show_axis_y=False
   space.show_region_ui=True
   space.region_3d.view_rotation=Quaternion((1,0,0),math.pi/2)
   space.region_3d.view_distance=3.3;space.region_3d.view_location=Vector((0,0,.9));space.region_3d.view_perspective='ORTHO'
  elif area.type=='DOPESHEET_EDITOR':area.spaces.active.mode='ACTION'
notes=bpy.data.texts.new('НАЧНИ_ЗДЕСЬ')
notes.write('Копия для ручной настройки. Игровые файлы она не перезаписывает.\nPose Mode: кости видны поверх модели. Выбрано левое бедро LeftUpLeg.\nЩелчок по кости — выбрать; R — повернуть мышью; ЛКМ — принять; Esc — отменить.\nCtrl+Z — отменить изменение; Ctrl+S — сохранить эту рабочую копию.\nSpace — воспроизведение/пауза; первый кадр — исходная широкая стойка.\nAuto Key включён: вращение кости записывается в текущий кадр.\nВ списке Action есть 01_Стойка_из_игры и 02_Ходьба_из_игры.\nПальцы скрыты для читаемости; Alt+H в Pose Mode покажет все кости.\nПосле настройки напишите в чат — проверим и отдельно перенесём правки в игру.\n')
bpy.ops.file.make_paths_relative()
path=OUT/'model1_manual_pose.blend'
bpy.ops.wm.save_as_mainfile(filepath=str(path))
print('MODEL1_MANUAL_POSE_READY',path,flush=True)
