import bpy,json
from pathlib import Path
root=Path(__file__).resolve().parents[1];out=root/'assets/environment/threshold_skyline/v1'
catalog=json.loads((out/'catalog.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(root/'art_source/threshold_skyline_v1/gothic_skyline.blend'))
assert len([o for o in bpy.context.scene.objects if o.type=='MESH'])==3
assert bpy.data.images['Skyline_albedo_1024'].packed_file
for name,count in catalog.items():
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(out/(name+'.glb')))
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH'];assert len(meshes)==1
    mesh=meshes[0].data;mesh.calc_loop_triangles();assert len(mesh.loop_triangles)==count
    assert all(-.0001<=value<=1.0001 for loop in mesh.uv_layers.active.data for value in loop.uv)
print('SKYLINE_VERIFY_OK: 3 GLBs, packed Blender atlas, UV bounds, triangle counts')
