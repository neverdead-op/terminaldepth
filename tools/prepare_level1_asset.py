import bpy,json,struct,shutil
from pathlib import Path
R=Path(r'C:/Users/user/Documents/terminal-depth');S=Path(r'C:/Users/user/Desktop/MAIN HERO ASSET/1 LEVEl');OUT=R/'assets/environment/level1_supplied';ART=R/'art_source/level1_supplied';OUT.mkdir(exist_ok=True);ART.mkdir(exist_ok=True);(ART/'.gdignore').touch()
bpy.ops.wm.open_mainfile(filepath=str(R/'work/level1_source/source.blend'))
o=bpy.data.objects['Level1Supplied']
# Raise the main floor to game zero; keep the supplied steps and elevated rooms.
for v in o.data.vertices:v.co.z+=6
bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
src=len(o.data.polygons)
mod=o.modifiers.new('Gameplay simplification','DECIMATE');mod.ratio=.20;bpy.ops.object.modifier_apply(modifier=mod.name)
for p in o.data.polygons:p.use_smooth=True
def export(path,obj,material=True):
 bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_image_format='NONE')
 if not material:return
 blob=path.read_bytes();size=struct.unpack_from('<I',blob,12)[0];d=json.loads(blob[20:20+size]);binary=blob[20+size:]
 d['images']=[{'uri':n} for n in ['level1_albedo.png','level1_normal.png','level1_orm.png']];d['textures']=[{'source':i} for i in range(3)]
 d['materials']=[{'name':'Supplied gothic courtyard','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicFactor':0.0,'roughnessFactor':.93},'normalTexture':{'index':1,'scale':.24},'occlusionTexture':{'index':2,'strength':.25}}]
 js=json.dumps(d,separators=(',',':')).encode();js+=b' '*(-len(js)%4);path.write_bytes(struct.pack('<III',0x46546c67,2,20+len(js)+len(binary))+struct.pack('<II',len(js),0x4e4f534a)+js+binary)
for srcname,name in [('8ead50b3-6e8e-4b12-a472-503ddd83c5c4.png','level1_albedo.png'),('36f0d137-ff75-4093-a939-d5a62073236a.png','level1_normal.png'),('a8f0500a-bc08-456b-b28e-8376a5f3fe7c.png','level1_orm.png')]:shutil.copy2(S/srcname,OUT/name)
export(OUT/'level1_visual.glb',o)
visual_count=len(o.data.polygons)
collider=o.copy();collider.data=o.data.copy();bpy.context.collection.objects.link(collider);collider.name='Level1Collision'
bpy.ops.object.select_all(action='DESELECT');collider.select_set(True);bpy.context.view_layer.objects.active=collider
mod=collider.modifiers.new('Collision simplification','DECIMATE');mod.ratio=.20;bpy.ops.object.modifier_apply(modifier=mod.name);collider.data.materials.clear();export(OUT/'level1_collision.glb',collider,False)
collider.hide_set(True);collider.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'level1_game.blend'))
report={'source_triangles':src,'visual_triangles':visual_count,'collision_triangles':len(collider.data.polygons),'source_scale':120,'floor_offset':6,'bounds_godot':[[min(v.co.x for v in o.data.vertices),min(v.co.z for v in o.data.vertices),min(-v.co.y for v in o.data.vertices)],[max(v.co.x for v in o.data.vertices),max(v.co.z for v in o.data.vertices),max(-v.co.y for v in o.data.vertices)]]}
(OUT/'report.json').write_text(json.dumps(report,indent=2));print('LEVEL1_ASSET_OK',report,flush=True)
