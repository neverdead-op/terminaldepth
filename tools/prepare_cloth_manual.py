import bpy,math,json
from pathlib import Path
from mathutils import Quaternion
R=Path(r'C:/Users/user/Documents/terminal-depth');OUT=R/'art_source/cloth_manual';OUT.mkdir(exist_ok=True);(OUT/'.gdignore').touch()
bpy.ops.wm.open_mainfile(filepath=str(R/'art_source/red_huntress_v1/huntress_rigged.blend'))
hero=bpy.data.objects['RedHuntress'];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
# Select complete connected garment pieces; keep their upper waistband vertices.
n=len(hero.data.vertices);parents=list(range(n))
def root(i):
 while parents[i]!=i:parents[i]=parents[parents[i]];i=parents[i]
 return i
for e in hero.data.edges:
 a,b=map(root,e.vertices);parents[b]=a
parts={}
for v in hero.data.vertices:parts.setdefault(root(v.index),[]).append(v.index)
groups={hero.vertex_groups[x].index for x in ['coat_l','coat_r']}
weighted={v.index for v in hero.data.vertices if any(g.group in groups and g.weight>.02 for g in v.groups)}
chosen=set()
for indices in parts.values():
 if len(weighted.intersection(indices))>max(3,len(indices)*.15):chosen.update(indices)
assert len(chosen)>5000
bpy.ops.object.select_all(action='DESELECT');hero.select_set(True);bpy.context.view_layer.objects.active=hero
for v in hero.data.vertices:v.select=v.index in chosen
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.separate(type='SELECTED');bpy.ops.object.mode_set(mode='OBJECT')
coat=next(o for o in bpy.context.selected_objects if o!=hero);coat.name='Cloth_Podol';hero.name='Body_Rigged'
bpy.ops.object.select_all(action='DESELECT');coat.select_set(True);bpy.context.view_layer.objects.active=coat
before=len(coat.data.vertices)
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.remove_doubles(threshold=.00015);bpy.ops.object.mode_set(mode='OBJECT')
pin=coat.vertex_groups.new(name='PIN_Waist')
zmax=max(v.co.z for v in coat.data.vertices)
for v in coat.data.vertices:
 w=max(0,min(1,(v.co.z-(zmax-.16))/.085))
 if w>0:pin.add([v.index],w,'REPLACE')
cloth=coat.modifiers.new('Cloth - Manual Practice','CLOTH');cloth.settings.quality=5;cloth.settings.mass=.25;cloth.settings.vertex_group_mass=pin.name
cloth.settings.tension_stiffness=25;cloth.settings.compression_stiffness=25;cloth.settings.shear_stiffness=15;cloth.settings.bending_stiffness=.8
cloth.collision_settings.use_collision=True;cloth.collision_settings.use_self_collision=False;cloth.collision_settings.distance_min=.006
cloth.point_cache.frame_start=1;cloth.point_cache.frame_end=120
hero.modifiers.new('Body Collision','COLLISION');hero.collision.thickness_outer=.005
rig.show_in_front=True;rig.data.display_type='OCTAHEDRAL'
# Gentle test motion of the existing rig; no gameplay clips are altered.
rig.animation_data_clear();rig.rotation_mode='XYZ'
for frame,x,turn in [(1,0,0),(30,.10,.12),(60,-.10,-.12),(90,.10,.12),(120,0,0)]:
 rig.location.x=x;rig.rotation_euler.z=turn;rig.keyframe_insert(data_path='location',frame=frame);rig.keyframe_insert(data_path='rotation_euler',frame=frame)
scene=bpy.context.scene;scene.frame_start=1;scene.frame_end=120;scene.render.fps=30;scene.frame_set(1)
notes=bpy.data.texts.new('START_HERE_RU');notes.write('Копия для ручных проб. Cloth_Podol — подол, PIN_Waist — закрепление у пояса.\nСправа Physics > Cloth. Space — воспроизведение. Shift+Left Arrow — первый кадр.\nИзменили настройки — вернитесь на кадр 1 и снова проиграйте. Cache > Delete Bake, если запекали.\nBody_Rigged содержит Collision. Стек подола: Armature, затем Cloth.\nСкелет HuntressRig уже существует, 68 костей. Небольшое движение добавлено только для этой пробы.\nCloth Blender не переносится в игру автоматически; для игры нужны кости/веса или отдельная физика Godot.\nИгровые файлы не изменены. Не экспортируйте эту копию поверх huntress.glb без проверки.\n')
for screen in bpy.data.screens:
 for area in screen.areas:
  if area.type=='PROPERTIES':area.spaces.active.context='PHYSICS'
  if area.type=='VIEW_3D':
   s=area.spaces.active;s.shading.type='SOLID';s.shading.color_type='MATERIAL';s.overlay.show_extras=False
   s.region_3d.view_distance=3.2;s.region_3d.view_location=(0,0,.98);s.region_3d.view_rotation=Quaternion((1,0,0),math.radians(78))
# Resolve original relative image references before moving the blend to another folder.
for image in bpy.data.images:
 if image.filepath:image.filepath=bpy.path.abspath(image.filepath)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'huntress_cloth_manual.blend'))
report={'coat_vertices_before_weld':before,'coat_vertices':len(coat.data.vertices),'body_vertices':len(hero.data.vertices),'pin_top_z':zmax,'rig_bones':len(rig.data.bones),'cloth_stack':[m.type for m in coat.modifiers]}
(OUT/'setup.json').write_text(json.dumps(report,indent=2));print('CLOTH_MANUAL_READY',report)
