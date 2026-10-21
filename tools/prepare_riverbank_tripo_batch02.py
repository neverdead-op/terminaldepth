"""Готовит второй набор Riverbank, включая присланные варианты крыши и контрфорса."""
from pathlib import Path
import json, math, shutil, struct, hashlib
import numpy as np
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/riverbank/tripo_v2/original'
OUT = ROOT / 'assets/environment/riverbank/tripo/v2'
MODULES = ROOT / 'assets/environment/riverbank/modules'
def prepare(folder, asset_id, module, rotate, obj_name=None):
    src = SOURCE / folder
    obj = src / obj_name if obj_name else next(src.glob('*.obj'))
    mtl = obj.with_suffix('.mtl')
    dst = OUT / asset_id
    dst.mkdir(parents=True, exist_ok=True)
    maps = {}
    for line in mtl.read_text(encoding='utf-8').splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            maps[parts[0]] = src / parts[1]
    if not maps['norm'].exists() and (src / 'T_Normal_lantern.png').exists():
        maps['norm'] = src / 'T_Normal_lantern.png'
    stem = 'RB_' + (module.removesuffix('_variant_b').upper() + '_B' if module.endswith('_variant_b') else module.upper() + '_A')
    texture_names = ['T_' + stem + '_BaseColor', 'T_' + stem + '_Normal', 'T_' + stem + '_MetallicRoughness']
    occupied = None
    with Image.open(maps['map_Kd']) as image:
        occupied = image.getbbox()
        # В переданном экспорте 2048-карта лежит в четверти чёрного 4096-холста.
        assert occupied == (0,2048,2048,4096), (asset_id,occupied)
    for tag, name in [('map_Kd','albedo'), ('norm','normal')]:
        with Image.open(maps[tag]) as image:
            assert image.getbbox() == occupied, (asset_id,tag,image.getbbox())
            image.crop(occupied).convert('RGB').save(dst / (texture_names[0 if name == 'albedo' else 1]+'.png'))
    with Image.open(maps['map_Pr']) as image:
        assert image.getbbox() == occupied, (asset_id,'roughness',image.getbbox())
        rough = image.crop(occupied).convert('RGB').getchannel('G')
        packed = Image.merge('RGB', (Image.new('L', rough.size, 255), rough, Image.new('L', rough.size, 0)))
        packed.save(dst/(texture_names[2]+'.png'))

    positions, uvs, normals, faces = [], [], [], []
    for line in obj.read_text(encoding='utf-8').splitlines():
        parts = line.split()
        if not parts: continue
        if parts[0] == 'v': positions.append(tuple(map(float,parts[1:4])))
        elif parts[0] == 'vt': uvs.append(tuple(map(float,parts[1:3])))
        elif parts[0] == 'vn': normals.append(tuple(map(float,parts[1:4])))
        elif parts[0] == 'f':
            poly = []
            for token in parts[1:]:
                ids = token.split('/')
                def index(value, count):
                    n = int(value)
                    return n-1 if n>0 else count+n
                poly.append((index(ids[0],len(positions)), index(ids[1],len(uvs)) if len(ids)>1 and ids[1] else -1,
                             index(ids[2],len(normals)) if len(ids)>2 and ids[2] else -1))
            for i in range(1,len(poly)-1): faces.append((poly[0],poly[i],poly[i+1]))
    verts, texcoords, norms, indices, unique = [], [], [], [], {}
    skipped = 0
    for face in faces:
        if not all(all(math.isfinite(x) for x in positions[key[0]]) for key in face):
            skipped += 1
            continue
        for key in face:
            if key not in unique:
                unique[key] = len(verts)
                p = positions[key[0]]
                n = normals[key[2]] if key[2] >= 0 else (0.,1.,0.)
                if not all(math.isfinite(x) for x in n): n=(0.,1.,0.)
                if rotate:
                    p=(p[2],p[1],-p[0])
                    n=(n[2],n[1],-n[0])
                uv=uvs[key[1]] if key[1]>=0 else (0.,0.)
                verts.append(p)
                norms.append(n)
                texcoords.append((uv[0],1.0-uv[1]))
            indices.append(unique[key])
    assert indices and np.isfinite(verts).all(), asset_id
    vertex_array = np.array(verts, dtype='<f4')
    normal_array = np.array(norms, dtype='<f4')
    normal_array /= np.maximum(np.linalg.norm(normal_array,axis=1,keepdims=True), 1e-8)
    arrays = [vertex_array, normal_array, np.array(texcoords,dtype='<f4'), np.array(indices,dtype='<u4')]
    blob = bytearray()
    views = []
    for i, arr in enumerate(arrays):
        blob.extend(b'\x00' * (-len(blob)%4))
        payload = arr.tobytes()
        views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(payload),'target':34963 if i==3 else 34962})
        blob.extend(payload)
    doc = {
        'asset':{'version':'2.0','generator':'Terminal Depth / author Tripo archive'},
        'scene':0,'scenes':[{'nodes':[0]}],
        'nodes':[{'name':asset_id,'mesh':0}],
        'meshes':[{'name':asset_id,'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'TEXCOORD_0':2},'indices':3,'material':0}]}],
        'buffers':[{'byteLength':len(blob)}], 'bufferViews':views,
        'accessors':[
            {'bufferView':0,'componentType':5126,'count':len(verts),'type':'VEC3','min':vertex_array.min(0).tolist(),'max':vertex_array.max(0).tolist()},
            {'bufferView':1,'componentType':5126,'count':len(verts),'type':'VEC3'},
            {'bufferView':2,'componentType':5126,'count':len(verts),'type':'VEC2'},
            {'bufferView':3,'componentType':5125,'count':len(indices),'type':'SCALAR'}],
        'images':[{'uri':name+'.png'} for name in texture_names],
        'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],
        'textures':[{'source':i,'sampler':0} for i in range(3)],
        'materials':[{'name':'M_'+stem,'doubleSided':True,
            'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':0.0,'roughnessFactor':1.0},
            'normalTexture':{'index':1,'scale':0.45}}]
    }
    encoded = json.dumps(doc,separators=(',',':'),allow_nan=False).encode('utf-8')
    encoded += b' ' * (-len(encoded)%4)
    blob.extend(b'\x00' * (-len(blob)%4))
    binary = struct.pack('<III',0x46546C67,2,28+len(encoded)+len(blob))
    binary += struct.pack('<II',len(encoded),0x4E4F534A)+encoded
    binary += struct.pack('<II',len(blob),0x004E4942)+blob
    (dst/('SM_'+stem+'.glb')).write_bytes(binary)
    path='res://assets/environment/riverbank/tripo/v2/'+asset_id+'/SM_'+stem+'.glb'
    return {'id':asset_id,'source_obj':str(obj.relative_to(ROOT)).replace('\\','/'),
            'source_sha256':__import__('hashlib').sha256(obj.read_bytes()).hexdigest(),
            'triangles':len(indices)//3,'vertices':len(verts),'skipped_invalid_triangles':skipped,
            'source_nonfinite_vertices':sum(not all(map(math.isfinite,p)) for p in positions),
            'rotation_y_90':rotate,'prepared_bbox':np.ptp(vertex_array,axis=0).tolist(),
            'texture_size':2048,'source_texture_content_rect':list(occupied),'module':module,'runtime_glb':path}


def main():
    import argparse, re
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    args = parser.parse_args()
    SOURCE.mkdir(parents=True, exist_ok=True)
    (SOURCE.parent / '.gdignore').touch()
    shutil.copytree(args.source, SOURCE, dirs_exist_ok=True)
    catalog = json.loads((ROOT/'docs/art_direction/riverbank/tripo_batch02/catalog.json').read_text(encoding='utf-8'))['assets']
    catalog.append({'id':'RB02_ROOF_SEGMENT_4M_VARIANT_B','title':'Дополнительная крыша','dimensions':'4 × 3 × 4 м','source_folder':'../additional_roof'})
    reports = []
    duplicates = []
    for row in catalog:
        module = row['id'].removeprefix('RB02_').lower()
        folder = row.get('source_folder', row['title'])
        if module == 'gate_leaf': folder = 'Створка ворот — одна половина'
        if module == 'buttress_4m':
            corrected = SOURCE.parent / 'corrections/buttress_4m'
            if corrected.exists():
                folder = '../corrections/buttress_4m'
            else:
                duplicates.append({'id':row['id'],'reason':'Копия крыши; требуется отдельный контрфорс'})
                continue
        objects = sorted((SOURCE/folder).glob('*.obj'))
        for i,obj in enumerate(objects):
            key = module if i == 0 else module+'_variant_b'
            asset_id = row['id'] if i == 0 else row['id']+'_VARIANT_B'
            # В OBJ длинная ось панелей/пролётов направлена вдоль Z; приводим к каталогу X.
            rotate = module in ['window_wall_4m','gable_end_4m','bank_edge_4m','cliff_face_8m','bridge_span','fallen_log','roots_ground','gate_leaf','buttress_4m','boat','cargo_wagon']
            report = prepare(folder, asset_id, key, rotate, obj.name)
            dimensions = [float(x) for x in re.findall(r'[0-9]+(?:\.[0-9]+)?',row['dimensions'])]
            report.update(title=row['title'], target_size=dimensions, source_folder=folder)
            reports.append(report)
            size = ', '.join(str(x) for x in dimensions)
            module_text = f'''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/riverbank_module.gd" id="1"]
[ext_resource type="PackedScene" path="{report['runtime_glb']}" id="2"]
[node name="RB_{key}" type="Node3D"]
script = ExtResource("1")
model_scene = ExtResource("2")
target_size = Vector3({size})
solid = false
'''
            (MODULES/(key+'.tscn')).write_text(module_text,encoding='utf-8')
    (OUT/'asset_report.json').write_text(json.dumps({'assets':reports,'excluded':duplicates},ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps([{'id':r['id'],'tris':r['triangles'],'bbox':r['prepared_bbox']} for r in reports],indent=2))
    print('Prepared:',len(reports),'Excluded:',len(duplicates))

if __name__ == '__main__': main()
