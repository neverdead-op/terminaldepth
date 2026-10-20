"""Экспорт ручной правки скелета без пересоздания костей и весов."""
import bpy
import json
import shutil
import struct
from datetime import datetime
from pathlib import Path
from mathutils import Matrix

root = Path(__file__).resolve().parents[1]
source = root / 'art_source/model1_v1/model1_rigged111.blend'
out = root / 'assets/characters/model1/v1'
backup = root / 'art_source' / ('model1_before_user_rig_' + datetime.now().strftime('%Y%m%d_%H%M%S'))
backup.mkdir()
(backup / '.gdignore').touch()
for path in [out / 'model1.glb', out / 'asset_report.json', root / 'assets/animations/model1_shooter.tres']:
    shutil.copy2(path, backup / path.name)
bpy.ops.wm.open_mainfile(filepath=str(source))
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
hero = bpy.data.objects['Model1Hero']
rig = bpy.data.objects['Model1Rig']
assert any(m.type == 'ARMATURE' and m.object == rig for m in hero.modifiers)
assert all(p.matrix_basis.is_identity for p in rig.pose.bones)
bpy.ops.object.select_all(action='DESELECT')
hero.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
# Убираем случайный сдвиг объекта скелета относительно меша.
# Ручные локальные положения костей и мировое положение меша сохраняем.
mesh_world = hero.matrix_world.copy()
rig.matrix_world = Matrix.Identity(4)
hero.matrix_world = mesh_world
bpy.context.view_layer.update()
path = out / 'model1.glb'
bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
    export_yup=True, export_animations=False, export_skins=True,
    export_apply=False, export_image_format='NONE')
blob = path.read_bytes()
size = struct.unpack_from('<I', blob, 12)[0]
doc = json.loads(blob[20:20 + size])
binary = blob[20 + size:]
doc['images'] = [{'uri':n} for n in ['model1_albedo.png','model1_normal.png','model1_orm.png']]
doc['samplers'] = [{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]
doc['textures'] = [{'source':i,'sampler':0} for i in range(3)]
doc['materials'] = [{'name':'Model1 supplied PBR','doubleSided':True,
    'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':1.0,'roughnessFactor':1.0},
    'normalTexture':{'index':1},'occlusionTexture':{'index':2,'strength':.6}}]
js = json.dumps(doc,separators=(',',':')).encode()
js += b' ' * (-len(js) % 4)
path.write_bytes(struct.pack('<III',0x46546C67,2,20+len(js)+len(binary)) + struct.pack('<II',len(js),0x4E4F534A) + js + binary)
report = json.loads((out / 'asset_report.json').read_text())
report.update(source=str(source.relative_to(root)), bones=len(rig.data.bones),
    vertices=len(hero.data.vertices), game_triangles=sum(len(p.vertices)-2 for p in hero.data.polygons), backup=str(backup.relative_to(root)))
(out / 'asset_report.json').write_text(json.dumps(report,indent=2))
print('USER_RIG_EXPORT_OK', json.dumps(report), flush=True)
