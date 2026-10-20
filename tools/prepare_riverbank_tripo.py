"""Подготовка авторских OBJ: исходники не меняются, GLB и карты пишутся только в riverbank/tripo/v1."""
from pathlib import Path
import json
import math
import shutil
import struct
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art_source/riverbank/tripo_v1/модели'
OUT = ROOT / 'assets/environment/riverbank/tripo/v1'
MODULES = ROOT / 'assets/environment/riverbank/modules'
ASSETS = [
    ('груда камней', 'RB_ROCK_BANK_A', 'rock_bank_a', False),
    ('груда камней поменьше', 'RB_ROCK_SMALL_B', 'rock_small_b', True),
    ('стена', 'RB_WALL_STRAIGHT_4M', 'wall_straight_4m', True),
    ('поврежденная стена', 'RB_WALL_BROKEN_4M', 'wall_broken_4m', True),
    ('столб от стены', 'RB_PILLAR_CORNER', 'pillar_corner', False),
    ('арка', 'RB_ARCH_GATEWAY', 'arch_gateway', True),
]

def prepare(folder, asset_id, module, rotate):
    src = SOURCE / folder
    obj = next(src.glob('*.obj'))
    mtl = next(src.glob('*.mtl'))
    dst = OUT / asset_id
    dst.mkdir(parents=True, exist_ok=True)
    maps = {}
    for line in mtl.read_text(encoding='utf-8').splitlines():
        parts = line.split(maxsplit=1)
        if len(parts) == 2:
            maps[parts[0]] = src / parts[1]
    occupied = None
    with Image.open(maps['map_Kd']) as image:
        occupied = image.getbbox()
        # В переданном экспорте 2048-карта лежит в четверти чёрного 4096-холста.
        assert occupied == (0,2048,2048,4096), (asset_id,occupied)
    for tag, name in [('map_Kd','albedo'), ('norm','normal')]:
        with Image.open(maps[tag]) as image:
            assert image.getbbox() == occupied, (asset_id,tag,image.getbbox())
            image.crop(occupied).convert('RGB').save(dst / (name+'.png'))
    with Image.open(maps['map_Pr']) as image:
        assert image.getbbox() == occupied, (asset_id,'roughness',image.getbbox())
        rough = image.crop(occupied).convert('RGB').getchannel('R')
        packed = Image.merge('RGB', (Image.new('L', rough.size, 255), rough, Image.new('L', rough.size, 0)))
        packed.save(dst/'metallic_roughness.png')

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
        'images':[{'uri':name+'.png'} for name in ['albedo','normal','metallic_roughness']],
        'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],
        'textures':[{'source':i,'sampler':0} for i in range(3)],
        'materials':[{'name':asset_id+'_painted','doubleSided':True,
            'pbrMetallicRoughness':{'baseColorTexture':{'index':0},'metallicRoughnessTexture':{'index':2},'metallicFactor':0.0,'roughnessFactor':1.0},
            'normalTexture':{'index':1,'scale':0.45}}]
    }
    encoded = json.dumps(doc,separators=(',',':'),allow_nan=False).encode('utf-8')
    encoded += b' ' * (-len(encoded)%4)
    blob.extend(b'\x00' * (-len(blob)%4))
    binary = struct.pack('<III',0x46546C67,2,28+len(encoded)+len(blob))
    binary += struct.pack('<II',len(encoded),0x4E4F534A)+encoded
    binary += struct.pack('<II',len(blob),0x004E4942)+blob
    (dst/(asset_id+'.glb')).write_bytes(binary)
    path='res://assets/environment/riverbank/tripo/v1/'+asset_id+'/'+asset_id+'.glb'
    wrapper = MODULES/(module+'.tscn')
    text = wrapper.read_text(encoding='utf-8')
    import re
    text = re.sub(r'load_steps=(\d+)', lambda m:'load_steps='+str(int(m.group(1))+1),text,count=1)
    at = text.index('[sub_resource') if '[sub_resource' in text else text.index('[node name=')
    text=text[:at]+'[ext_resource type="PackedScene" path="'+path+'" id="Tripo"]\n'+text[at:]
    text=text.replace('reference_model = ExtResource("2")','reference_model = ExtResource("2")\nmodel_scene = ExtResource("Tripo")')
    wrapper.write_text(text,encoding='utf-8')
    return {'id':asset_id,'source_obj':str(obj.relative_to(ROOT)).replace('\\','/'),
            'source_sha256':__import__('hashlib').sha256(obj.read_bytes()).hexdigest(),
            'triangles':len(indices)//3,'vertices':len(verts),'skipped_invalid_triangles':skipped,
            'source_nonfinite_vertices':sum(not all(map(math.isfinite,p)) for p in positions),
            'rotation_y_90':rotate,'prepared_bbox':np.ptp(vertex_array,axis=0).tolist(),
            'texture_size':2048,'source_texture_content_rect':list(occupied),'module':module,'runtime_glb':path}

if __name__ == '__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    # Повторный запуск обновляет только нашу ссылку, не увеличивая список ресурсов.
    for _,_,module,_ in ASSETS:
        p=MODULES/(module+'.tscn')
        s=p.read_text(encoding='utf-8')
        if 'id="Tripo"' in s:
            import re
            s=re.sub(r'\[ext_resource[^\n]+id="Tripo"\]\n','',s)
            s=s.replace('model_scene = ExtResource("Tripo")\n','')
            s=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m.group(1))-1),s,count=1)
            p.write_text(s,encoding='utf-8')
    reports=[prepare(*row) for row in ASSETS]
    (OUT/'asset_report.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(reports,ensure_ascii=True,indent=2))
