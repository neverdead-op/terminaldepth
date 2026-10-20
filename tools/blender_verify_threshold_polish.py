"""Check the saved editable kit and every exported GLB with external shared atlas."""
import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];src=root/'art_source/threshold_polish_v1';kit=root/'assets/environment/threshold_polish/v1'
catalog=json.loads((kit/'catalog.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(src/'threshold_models.blend'))
assert len([o for o in bpy.context.scene.objects if o.type=='MESH'])==3
atlas=bpy.data.images['Threshold_set_albedo_4096'];assert atlas.packed_file and tuple(atlas.size)==(4096,4096)
bpy.ops.object.select_all(action='SELECT')
for obj in bpy.context.selected_objects:
    if obj.name not in catalog and obj.name.rsplit('.',1)[0] in catalog:obj.name=obj.name.rsplit('.',1)[0]
    assert obj.name in catalog and obj.data.uv_layers
    assert all(-.0001<=v<=1.0001 for loop in obj.data.uv_layers.active.data for v in loop.uv)
bpy.ops.uv.export_layout(filepath=str(src/'threshold_uv_layout.svg'),mode='SVG',size=(4096,4096),opacity=.3,export_all=True)
for name,entry in catalog.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(kit/(name+'.glb')))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(objects)==1
    obj=objects[0];obj.data.calc_loop_triangles();assert len(obj.data.loop_triangles)==entry['triangles']
    for mat in obj.data.materials:
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type=='TEX_IMAGE':
                    assert node.image is not None and Path(bpy.path.abspath(node.image.filepath)).is_file(),name
                    _=node.image.pixels[0]
                    assert tuple(node.image.size)==(4096,4096),name
print('THRESHOLD_BLENDER_VERIFY_OK: 3 GLBs reimported, shared atlas resolves, triangle counts, packed source atlas and UV bounds checked')
