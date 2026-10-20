"""Round-trip check of the source, UV atlas, and exported GLB in Blender."""
import bpy, json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
src=root/'art_source/threshold_lantern_v1'
out=root/'assets/environment/threshold_lantern/v1'
bpy.ops.wm.open_mainfile(filepath=str(src/'gothic_lantern.blend'))
model=bpy.data.objects['Gothic_Lantern_Threshold_v1']
assert len(model.data.uv_layers)==1
assert all(-.0001<=value<=1.0001 for loop in model.data.uv_layers.active.data for value in loop.uv)
image=bpy.data.images['Lantern_albedo_2048']
assert image.packed_file is not None and tuple(image.size)==(2048,2048)
assert all(mat.node_tree.nodes.get('Image Texture').image==image for mat in model.data.materials)
model.data.calc_loop_triangles()
triangles=len(model.data.loop_triangles)
assert 2000<triangles<6000
assert 4.2<model.dimensions.z<4.5
assert (src/'lantern_uv_layout.png').stat().st_size>1000
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(out/'gothic_lantern.glb'))
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
total=0
for obj in meshes:
    obj.data.calc_loop_triangles();total+=len(obj.data.loop_triangles)
    assert obj.data.uv_layers
assert total==triangles,(total,triangles)
assert not any(o.type in {'LIGHT','CAMERA'} for o in bpy.context.scene.objects)
print('LANTERN_VERIFY_OK: source reopened, packed 2048 atlas, UV bounds, GLB reimport, triangles',total)
