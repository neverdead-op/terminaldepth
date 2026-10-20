import bpy,json
from pathlib import Path
r=Path(r'C:/Users/user/Documents/terminal-depth')
bpy.ops.wm.open_mainfile(filepath=str(r/'art_source/red_huntress_v1/huntress_rigged.blend'))
hero=bpy.data.objects['RedHuntress'];rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
print('RIG',rig.name,len(rig.data.bones),'BONES',[b.name for b in rig.data.bones if 'coat' in b.name or 'scarf' in b.name])
for name in ['coat_l','coat_r']:
 g=hero.vertex_groups.get(name);v=[v for v in hero.data.vertices if g and any(x.group==g.index and x.weight>.02 for x in v.groups)]
 print('GROUP',name,len(v),[(min(p.co[i] for p in v),max(p.co[i] for p in v)) for i in range(3)])
print('MODIFIERS',[(m.name,m.type) for m in hero.modifiers])
