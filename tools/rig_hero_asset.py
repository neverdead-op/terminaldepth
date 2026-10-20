"""Export the approved 68-bone hero with the projecting scarf tail removed.

The cloth experiment is archived in art_source/red_huntress_cloth_experiment.
The approved rig and the exact removable islands are saved beside the .blend.
"""
import bpy, json, struct
from pathlib import Path
R=Path(__file__).resolve().parents[1]
ART=R/'art_source/red_huntress_v1';OUT=R/'assets/characters/red_huntress/v1'
bpy.ops.wm.open_mainfile(filepath=str(ART/'huntress_before_scarf_removal.blend'))
hero=bpy.data.objects['RedHuntress'];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
selection=json.loads((ART/'scarf_tail_selection.json').read_text())
assert len(hero.data.vertices)==selection['source_vertex_count'], 'Update scarf selection for a changed source mesh'
before=len(hero.data.polygons)
bpy.ops.object.select_all(action='DESELECT');hero.select_set(True);bpy.context.view_layer.objects.active=hero
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='DESELECT');bpy.ops.object.mode_set(mode='OBJECT')
for i in selection['vertices']:hero.data.vertices[i].select=True
bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.delete(type='VERT');bpy.ops.object.mode_set(mode='OBJECT')
# The close-fitting collar remains; only six disconnected projecting surfaces go.
bpy.ops.object.select_all(action='DESELECT');hero.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'huntress.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_skins=True,export_apply=False,export_image_format='NONE')
path=OUT/'huntress.glb';blob=path.read_bytes();size=struct.unpack_from('<I',blob,12)[0]
doc=json.loads(blob[20:20+size]);binary=blob[20+size:]
doc['images']=[{'uri':n} for n in ['huntress_albedo.png','huntress_normal.png','huntress_orm.png']]
doc['samplers']=[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}]
doc['textures']=[{'source':i,'sampler':0} for i in range(3)]
doc['materials']=[{'name':'Huntress supplied PBR','doubleSided':True,'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':1.0,'roughnessFactor':1.0},'normalTexture':{'index':1},'occlusionTexture':{'index':2,'strength':.6}}]
js=json.dumps(doc,separators=(',',':')).encode();js+=b' '*(-len(js)%4)
path.write_bytes(struct.pack('<III',0x46546C67,2,12+8+len(js)+len(binary))+struct.pack('<II',len(js),0x4E4F534A)+js+binary)
bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ART/'huntress_rigged.blend'))
report={'source_figures':6,'selected_figure':0,'source_total_triangles':1961561,'selected_triangles':363508,'game_triangles':len(hero.data.polygons),'vertices':len(hero.data.vertices),'bones':len(rig.data.bones),'removed_scarf_vertices':len(selection['vertices']),'removed_scarf_triangles':before-len(hero.data.polygons),'cloth_physics':False,'collar_preserved':True}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2))
print('HUNTRESS_SCARF_REMOVED',json.dumps(report),flush=True)
