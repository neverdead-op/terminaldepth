import bpy,json
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(R/'work/hero_source/extracted.blend'))
o=bpy.data.objects['RedHuntress'];m=o.data
adj=[[] for v in m.vertices]
for e in m.edges:
    a,b=e.vertices;adj[a].append(b);adj[b].append(a)
seen=set();parts=[]
for v in m.vertices:
    if v.index in seen:continue
    stack=[v.index];seen.add(v.index);ids=[]
    while stack:
        i=stack.pop();ids.append(i)
        for n in adj[i]:
            if n not in seen:seen.add(n);stack.append(n)
    ps=[m.vertices[i].co for i in ids];center=sum(ps,Vector())/len(ps)
    parts.append({'ids':ids,'n':len(ids),'center':list(center),'min':[min(p[i] for p in ps) for i in range(3)],'max':[max(p[i] for p in ps) for i in range(3)]})
parts.sort(key=lambda p:-p['n'])
for i,p in enumerate(parts):p['id']=i
(R/'work/hero_source/parts.json').write_text(json.dumps(parts))
for p in parts[:80]:print(p['id'],p['n'],[round(x,3) for x in p['center']],[round(x,3) for x in p['min']],[round(x,3) for x in p['max']])
