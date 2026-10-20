"""Standalone reference huntress study. Blender 5.x, no campaign edits.
Run: blender --background --factory-startup --python tools/blender_build_huntress.py
Anatomical head and hand topology derives from the project's Erika Archer FBX;
all costume, hair, accessories, materials and preview rig are built here.
"""
import bpy, math, random, json
from pathlib import Path
from mathutils import Vector, Matrix
R = Path(__file__).resolve().parents[1]
OUT = R/'assets/characters/huntress/v1'
SRC = R/'art_source/huntress_v1'
OUT.mkdir(parents=True, exist_ok=True); SRC.mkdir(parents=True, exist_ok=True)
(SRC/'.gdignore').touch()
random.seed(22)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system='METRIC'
parts=[]; bindings={}

def mat(name,c,rough=.72,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1)
 p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
 m.diffuse_color=(*c,1);return m
red=mat('01 | Oxide red wool',(.24,.039,.018))
redlight=mat('02 | Worn vermilion edges',(.34,.073,.031))
reddark=mat('03 | Deep red lining',(.095,.014,.010))
black=mat('04 | Charcoal scarf',(.025,.022,.019))
leather=mat('05 | Dark umber leather',(.049,.030,.020),.55)
edge=mat('06 | Leather worn piping',(.11,.068,.037),.63)
pants=mat('07 | Graphite trousers',(.052,.056,.052))
brass=mat('08 | Tarnished brass',(.29,.19,.075),.37,.68)
iron=mat('09 | Blued steel',(.075,.086,.079),.35,.72)
skin=mat('10 | Warm pale skin',(.61,.39,.27),.78)
hair=mat('11 | Near black hair',(.016,.012,.010),.52)
hairlit=mat('12 | Chestnut hair ridges',(.044,.025,.014),.55)
lip=mat('13 | Muted lips',(.24,.074,.051),.66)
eye=mat('14 | Eye ivory',(.63,.62,.51),.4)
iris=mat('15 | Hazel iris',(.10,.12,.056),.38)
thread=mat('16 | Aged linen stitching',(.28,.18,.095))

def finish(o,name,m,bone=None,bevel=0,smooth=True):
 o.name=name;o.data.materials.append(m)
 if smooth:
  for p in o.data.polygons:p.use_smooth=True
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Soft constructed edges','BEVEL');mod.width=bevel;mod.segments=2
  bpy.ops.object.modifier_apply(modifier=mod.name)
 parts.append(o);bindings[o.name]=bone
 return o
def mesh(name,v,f,m,bone=None,thick=0):
 d=bpy.data.meshes.new(name);d.from_pydata(v,[],f);d.update()
 o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);finish(o,name,m,bone)
 if thick:
  mod=o.modifiers.new('Real cloth thickness','SOLIDIFY');mod.thickness=thick
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def box(name,loc,scale,m,bone=None,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=scale
 return finish(o,name,m,bone,bevel)
def ell(name,loc,scale,m,bone=None):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,location=loc)
 o=bpy.context.object;o.scale=scale;return finish(o,name,m,bone)
def tube(name,points,r,m,bone=None,sides=8):
 points=[Vector(p) for p in points];v=[];f=[]
 for j,p in enumerate(points):
  d=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
  a=d.cross(Vector((0,1,0))).normalized()
  if a.length<.1:a=d.cross(Vector((1,0,0))).normalized()
  b=d.cross(a).normalized();rad=r[j] if isinstance(r,list) else r
  for i in range(sides):v.append(p+rad*(a*math.cos(i*math.tau/sides)+b*math.sin(i*math.tau/sides)))
 for j in range(len(points)-1):
  for i in range(sides):f.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
 f += [tuple(reversed(range(sides))),tuple((len(points)-1)*sides+i for i in range(sides))]
 return mesh(name,v,f,m,bone)
def ringbody(name,rings,m,bone=None,n=48,fold=.0):
 v=[];f=[]
 for j,(x,y,z,rx,ry) in enumerate(rings):
  for i in range(n):
   t=math.tau*i/n;w=1+fold*math.sin(t*9+j*.8)
   v.append((x+rx*math.sin(t)*w,y-ry*math.cos(t)*w,z))
 for j in range(len(rings)-1):
  for i in range(n):f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
 if rings[-1][2]<rings[0][2]:f=[tuple(reversed(face)) for face in f]
 return mesh(name,v,f,m,bone, .003)
def ribbon(name,a,b,width,m,bone,depth=.004):
 a=Vector(a);b=Vector(b);d=b-a;side=Vector((d.z,0,-d.x)).normalized()*width/2
 return mesh(name,[a-side,a+side,b+side,b-side],[(0,1,2,3)],m,bone,depth)
def buckle(name,c,w,h,bone,rotation=0):
 x,y,z=c
 o=tube(name,[(x-w/2,y,z-h/2),(x-w/2,y,z+h/2),(x+w/2,y,z+h/2),(x+w/2,y,z-h/2),(x-w/2,y,z-h/2)],.0035,brass,bone)
 tube(name+' tongue',[(x,y-.001,z-h*.38),(x,y-.003,z+h*.25)],.002,brass,bone)
 return o

# Reuse only anatomical topology already owned by the project. No old clothes.
bpy.ops.import_scene.fbx(filepath=str(R/'animation/erika_archer/Erika Archer.fbx'))
imported=list(scene.objects)
source=next(o for o in imported if o.type=='MESH' and o.name=='Erika_Archer_Eyelashes_Mesh')
srcarm=next(o for o in imported if o.type=='ARMATURE')
fingerbones=[]
def handmap(p,s):
 pivot=Vector((s*.713,.055,1.44));dest=Vector((s*.365,-.015,1.005))
 return Matrix.Rotation(s*math.radians(68),4,'Y')@(p-pivot)+dest
for b in srcarm.data.bones:
 if 'Hand' in b.name and not b.name.endswith('Hand'):
  s=1 if 'Left' in b.name else -1
  fingerbones.append((b.name.replace('mixamorig:',''),handmap(srcarm.matrix_world@b.head_local,s),handmap(srcarm.matrix_world@b.tail_local,s),b.parent.name.replace('mixamorig:','')))
def extract(name,predicate,m,bone,transform=None):
 verts=[];faces=[];mapping={}
 for p in source.data.polygons:
  coords=[source.matrix_world@source.data.vertices[i].co for i in p.vertices]
  if not all(predicate(v) for v in coords):continue
  face=[]
  for idx,co in zip(p.vertices,coords):
   if idx not in mapping:
    mapping[idx]=len(verts);verts.append(transform(co) if transform else co)
   face.append(mapping[idx])
  faces.append(face)
 return mesh(name,verts,faces,m,bone)
head=extract('Face and neck | anatomical topology',lambda v:v.z>1.49,skin,'Head')
# Sculpted face retains actual nose, eyelids, ears and jaw; lips get a separate region.
head.data.materials.append(lip)
for p in head.data.polygons:
 c=p.center
 if 1.598<c.z<1.617 and c.y<-.084 and abs(c.x)<.025:p.material_index=1
for s in [-1,1]:
 extract(('Left' if s==1 else 'Right')+' articulated glove',lambda v:s*v.x>.715,leather,('Left' if s==1 else 'Right')+'Hand',lambda p:handmap(p,s))
 # Real eye sockets from the head receive inset eyes, iris and small glints.
 ell('Eye white', (s*.031,-.086,1.664),(.020,.013,.011),eye,'Head')
 ell('Hazel iris',(s*.031,-.0985,1.664),(.007,.002,.0075),iris,'Head')
 ell('Pupil',(s*.031,-.100,1.664),(.0034,.001,.005),hair,'Head')
 ell('Eye glint',(s*.029,-.101,1.667),(.0016,.0008,.0016),eye,'Head')
 tube('Upper eyelid',[(s*.011,-.093,1.665),(s*.025,-.100,1.675),(s*.041,-.098,1.673),(s*.050,-.088,1.667)],.0023,hair,'Head')
 tube('Angled eyebrow',[(s*.012,-.094,1.688),(s*.030,-.097,1.691),(s*.050,-.086,1.685)],[.002,.004,.001],hair,'Head')
for o in imported:
 if o.name in bpy.data.objects:bpy.data.objects.remove(o,do_unlink=True)

# Tailored torso. Broad color masses are kept intentionally close to the drawing.
ringbody('Charcoal fitted undershirt',[(0,0,.99,.145,.102),(0,0,1.10,.125,.086),(0,0,1.23,.153,.102),(0,.003,1.35,.174,.113),(0,.014,1.425,.17,.080),(0,0,1.48,.056,.055)],black,'Spine2')
ringbody('Structured leather corset',[(0,0,1.015,.148,.105),(0,0,1.065,.138,.100),(0,0,1.14,.124,.091),(0,0,1.215,.143,.103),(0,0,1.25,.154,.106)],leather,'Spine1')
for i in range(12):
 t=math.tau*i/12
 tube('Corset raised boning',[(.148*math.sin(t),-.107*math.cos(t),1.025),(.126*math.sin(t),-.093*math.cos(t),1.14),(.15*math.sin(t),-.108*math.cos(t),1.24)],.0023,edge,'Spine1')
for z in [1.06,1.095,1.13,1.165,1.20]:
 for s in [-1,1]:
  ell('Brass corset eyelet',(s*.023,-.103,z),(.004,.002,.004),brass,'Spine1')
 tube('Crossed corset lacing',[(-.023,-.109,z),(.023,-.110,z+.03)],.0016,thread,'Spine1')
 tube('Crossed corset lacing',[(.023,-.110,z),(-.023,-.109,z+.03)],.0016,thread,'Spine1')
for s in [-1,1]:
 v=[(s*.055,-.110,1.405),(s*.155,-.085,1.444),(s*.198,-.012,1.423),(s*.177,-.108,1.32),(s*.155,-.107,1.257),(s*.08,-.121,1.283),(s*.105,-.129,1.348)]
 mesh('Cropped red jacket front',v,[tuple(range(7))],red,'Spine2',.008)
 mesh('Turned angular lapel',[(s*.055,-.120,1.418),(s*.110,-.139,1.397),(s*.145,-.132,1.329),(s*.084,-.134,1.359)],[(0,1,2,3)],redlight,'Spine2',.004)
 tube('Jacket tailored seam',[(s*.166,-.093,1.427),(s*.154,-.116,1.35),(s*.145,-.111,1.27)],.0019,reddark,'Spine2')
 ell('Lapel brass pin',(s*.12,-.144,1.398),(.005,.003,.005),brass,'Spine2')
mesh('Jacket back', [(-.18,.045,1.43),(0,.095,1.46),(.18,.045,1.43),(.163,.095,1.29),(0,.111,1.255),(-.163,.095,1.29)],[(0,1,2,3,4,5)],red,'Spine2',.008)
for s in [-1,1]:
 tube('Back jacket seam',[(s*.12,.094,1.421),(s*.11,.109,1.34),(s*.07,.115,1.28)],.002,reddark,'Spine2')
ell('Back jacket button',(0,.117,1.27),(.006,.003,.006),brass,'Spine2')

# Sleeves follow a relaxed A pose; folds are modelled, not painted-on cylinders.
for s in [-1,1]:
 side='Left' if s==1 else 'Right'
 rings=[]
 for j in range(20):
  t=j/19;x=s*(.17+.145*t);z=1.43-.275*t;y=.005
  rad=(.070*(1-t)+.044*t)*(1+.12*math.sin(t*math.pi*8))
  rings.append((x,y,z,rad,rad*.83))
 ringbody(side+' gathered red sleeve',rings,red,None,32,.07)
 tube(side+' sleeve seam',[(s*.218,-.055,1.38),(s*.255,-.050,1.29),(s*.30,-.043,1.18)],.002,reddark,None)
 ringbody(side+' rolled cuff',[(s*.31,0,1.19,.051,.049),(s*.32,0,1.15,.054,.050),(s*.324,0,1.137,.048,.046)],redlight,None,32,.04)
 ringbody(side+' forearm bracer',[(s*.322,-.004,1.144,.047,.044),(s*.35,-.01,1.05,.039,.038),(s*.365,-.015,1.015,.035,.033)],leather,side+'ForeArm',32)
 for z,x in [(1.13,.328),(1.04,.354)]:
  ringbody(side+' bracer binding',[(s*x,-.01,z+.009,.049 if z>1.1 else .040,.046 if z>1.1 else .039),(s*(x+.003),-.01,z-.009,.048 if z>1.1 else .039,.045 if z>1.1 else .038)],edge,side+'ForeArm',32)
  buckle('Bracer clasp',(s*x,-.057 if z>1.1 else -.049,z),.018,.015,side+'ForeArm')
 tube('Bracer longitudinal seam',[(s*.33,-.049,1.127),(s*.347,-.050,1.07),(s*.361,-.046,1.027)],.002,edge,side+'ForeArm')

# Pants and knee folds, with boots, shaped toes, separate soles and modest heels.
for s in [-1,1]:
 side='Left' if s==1 else 'Right'
 ringbody(side+' trouser leg',[(s*.075,0,1.025,.086,.095),(s*.086,0,.94,.092,.093),(s*.10,0,.82,.078,.078),(s*.112,0,.68,.062,.061),(s*.12,-.006,.56,.058,.059),(s*.124,0,.51,.061,.056),(s*.127,.006,.48,.050,.048),(s*.13,0,.435,.049,.046)],pants,None,36,.055)
 for j in range(4):
  z=.49+j*.025
  tube('Trouser knee crease',[(s*.08,-.045,z),(s*.115,-.062,z-.01),(s*.155,-.048,z+.008)],.0035,black,side+'Leg')
 tube('Trouser outer seam',[(s*.161,.003,.94),(s*.178,.005,.80),(s*.18,.005,.67),(s*.177,.005,.52)],.0018,black,side+'UpLeg')
 ringbody(side+' tall boot',[(s*.14,.01,.09,.040,.045),(s*.14,.014,.16,.038,.045),(s*.135,.012,.28,.045,.048),(s*.13,.006,.39,.055,.052),(s*.13,0,.46,.058,.055)],leather,side+'Leg',32,.025)
 ringbody(side+' folded boot cuff',[(s*.13,0,.46,.065,.061),(s*.132,0,.42,.069,.063),(s*.134,0,.365,.063,.060)],edge,side+'Leg',32)
 mesh('Cuff front overlap',[(s*.08,-.067,.462),(s*.173,-.067,.454),(s*.172,-.071,.351),(s*.125,-.073,.376)],[(0,1,2,3)],leather,side+'Leg',.005)
 ell('Cuff rivet',(s*.159,-.077,.415),(.004,.002,.004),brass,side+'Leg')
 boot=ell(side+' shaped boot foot',(s*.145,-.045,.065),(.052,.113,.054),leather,side+'Foot')
 box(side+' stacked heel',(s*.145,.027,.028),(.074,.066,.057),leather,side+'Foot',.006)
 sole=ell(side+' leather outsole',(s*.145,-.047,.026),(.055,.116,.017),black,side+'Foot')
 tube('Boot vamp stitched seam',[(s*.098,-.04,.09),(s*.114,-.095,.094),(s*.146,-.12,.09),(s*.18,-.095,.087),(s*.192,-.04,.08)],.0017,edge,side+'Foot')
 ribbon('Ankle cross strap',(s*.102,-.060,.142),(s*.182,-.068,.080),.017,edge,side+'Foot')
 buckle('Boot buckle',(s*.165,-.080,.113),.023,.018,side+'Foot')

# Nine flared coat gores, open at the front, with asymmetric torn silhouettes.
gores=9
for k in range(gores):
 a0=.58+(math.tau-1.16)*k/gores;a1=.58+(math.tau-1.16)*(k+1)/gores
 v=[];f=[];N=12;M=14
 def cp(u,t):
  a=a0+(a1-a0)*u
  rx=.151+.36*t**1.35;ry=.115+.125*t
  ripple=(.008+.018*t)*math.sin(u*math.tau*1.5+k*.9)*math.sin(t*math.pi*.85)
  hem=.33+.055*math.sin(k*2.4+u*4)+.04*math.sin(u*24+k)
  if k in [0,8]:hem-=.045
  z=1.035*(1-t)+hem*t
  return ((rx+ripple)*math.sin(a),-(ry+ripple)*math.cos(a)+.045*t*t,z)
 for j in range(M+1):
  for i in range(N+1):v.append(cp(i/N,j/M))
 for j in range(M):
  for i in range(N):
   # Small edge losses are genuine gaps, with lining visible through them.
   if j==M-1 and (i+k*3)%9==0:continue
   f.append((j*(N+1)+i,j*(N+1)+i+1,(j+1)*(N+1)+i+1,(j+1)*(N+1)+i))
 o=mesh('Coat gore %02d | ragged double sided wool'%k,v,f,red if k%3 else redlight,'Hips',.004)
 o.data.materials.append(reddark)
 # Solidify back faces form a darker lining.
 for p in o.data.polygons:
  if p.normal.y>0.4 and k in [0,8]:p.material_index=1
 for u in [.01,.99]:tube('Coat panel felled seam',[cp(u,j/16) for j in range(17)],.0017,reddark,'Hips')
 if k in [0,2,5,8]:
  for j in range(7):
   t=.84+j*.018;a=Vector(cp(.12,t));b=Vector(cp(.20,t+.007));tube('Visible hem repair stitch',[a,b],.001,thread,'Hips',6)

# Hip belt: tilted oval band, brass buckle, punched holes and keeper loops.
v=[];f=[]
for j in range(2):
 for i in range(96):
  t=math.tau*i/96;x=.168*math.sin(t);y=-.124*math.cos(t)
  v.append((x,y,1.045+.08*x+j*.044))
for i in range(96):f.append((i,(i+1)%96,96+(i+1)%96,96+i))
mesh('Slanted equipment belt',v,f,edge,'Hips',.009)
buckle('Large rectangular belt buckle',(.025,-.135,1.073),.062,.043,'Hips')
for x in [-.11,-.085,-.06,.09,.115]:
 ell('Belt punched hole',(x,-.133,1.068+x*.08),(.002,.001,.002),black,'Hips')
for x in [-.135,.080]:box('Belt leather keeper',(x,-.13,1.069),(.011,.016,.053),leather,'Hips',.002)
for s in [-1,1]:
 for i in range(2 if s==1 else 1):
  x=s*(.165+i*.019);y=.01+i*.065;z=1.0
  box('Belt ammunition pouch',(x,y,z),(.068,.061,.098),leather,'Hips',.009)
  box('Pouch overlapping flap',(x,y-.036,z+.028),(.073,.013,.049),edge,'Hips',.006)
  ell('Pouch snap',(x,y-.045,z+.017),(.005,.002,.005),brass,'Hips')
# The reference's right hip holster carries a compact antique sidearm.
hol=box('Shaped right hip holster',(-.205,-.050,.921),(.075,.060,.177),edge,'Hips',.013)
hol.rotation_euler.y=-.12
tube('Holster edge piping',[(-.241,-.085,1.008),(-.25,-.085,.94),(-.231,-.085,.839),(-.19,-.085,.842),(-.17,-.085,.99)],.0024,leather,'Hips')
box('Holster retaining strap',(-.206,-.089,.981),(.080,.012,.024),leather,'Hips',.003)
ell('Holster snap',(-.205,-.098,.98),(.006,.003,.006),brass,'Hips')
box('Antique pistol grip',(-.212,-.04,1.035),(.031,.034,.069),leather,'Hips',.004)
tube('Sidearm metal spine',[(-.236,-.046,.91),(-.238,-.046,1.059),(-.212,-.045,1.068)],.010,iron,'Hips',12)
buckle('Holster harness ring',(-.212,-.093,1.013),.031,.025,'Hips')

# Sculpted short hair, asymmetrical pointed bangs and ear-side locks.
ell('Short hair cap',(0,.015,1.698),(.092,.082,.102),hair,'Head')
for s in [-1,1]:
 for j in range(4):
  x=s*(.048+j*.011)
  tube('Temple layered hair',[(x,.0,1.736),(s*(.073+j*.006),-.023,1.66),(s*(.071+j*.006),-.042,1.578-j*.006)],[.024,.019,.001],hair if j%2 else hairlit,'Head',10)
for j in range(7):
 x=-.068+j*.020
 tip=x-.026 if j<4 else x-.012
 tube('Swept pointed fringe',[(x,.0,1.774),(x*.8,-.075,1.728),(tip,-.100,1.68+(j%3)*.013)],[.022,.017,.0008],hair if j%3 else hairlit,'Head',10)

# Hood: a real open cavity, peaked crown, seam and thick rolled rim.
v=[];f=[];N=48;M=20
def hoodp(u,t):
 # Opening ellipse in XZ; each ring recedes toward the back of the skull.
 angle=math.tau*u
 x=.139*math.sin(angle)*(1-.45*t)
 z=1.673+.172*math.cos(angle)*(1-.32*t)+.015*t
 y=-.084+.204*t
 # Raised pointed forehead peak and slumped back crown.
 z+=.033*max(0,math.cos(angle))**7*(1-t)
 y-=.035*max(0,math.cos(angle))**5*(1-t)
 y+=.009*math.sin(angle*5)*math.sin(t*math.pi)
 return (x,y,z)
for j in range(M+1):
 for i in range(N):v.append(hoodp(i/N,j/M))
for j in range(M):
 for i in range(N):f.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
f.append(tuple(M*N+i for i in range(N)))
hood=mesh('Deep open pointed red hood',v,f,red,'Head',.006)
tube('Hood rolled opening',[hoodp(i/96,0) for i in range(97)],.0045,redlight,'Head')
tube('Hood crown seam',[hoodp(0,j/30) for j in range(31)],.0018,reddark,'Head')
for u in [.19,.81]:tube('Hood side dart',[hoodp(u,j/20) for j in range(4,19)],.0016,reddark,'Head')

# Folded scarf sits below the face, spreads over shoulders and trails behind.
ringbody('Black scarf neck wrap',[(0,.008,1.477,.075,.065),(0,.008,1.50,.094,.075),(0,.006,1.527,.087,.070)],black,'Neck',48,.035)
mesh('Asymmetric scarf shoulder mantle',[(-.218,.02,1.456),(-.115,-.103,1.479),(.025,-.117,1.457),(.18,-.046,1.47),(.214,.038,1.444),(.085,.123,1.38),(-.045,.147,1.387),(-.19,.085,1.427)],[(0,1,2,3,4,5,6,7)],black,'Spine2',.007)
tube('Mantle folded hem',[(-.214,.02,1.456),(-.11,-.105,1.479),(.025,-.12,1.457),(.18,-.046,1.47),(.21,.038,1.444)],.003,edge,'Spine2')
for j in range(3):
 tube('Scarf folded ridge',[(-.065,-.071-j*.008,1.51-j*.012),(.018,-.083-j*.01,1.495-j*.012),(.084,-.057-j*.007,1.51-j*.012)],.0035,black,'Neck')
for k in range(2):
 pts=[(-.06+k*.10,.108,1.47),(-.10+k*.13,.17,1.36),(-.14+k*.16,.22,1.24),(-.22+k*.24,.25,1.13),(-.25+k*.22,.28,1.05+k*.05)]
 v=[]
 for j,p in enumerate(pts):
  width=[.095,.10,.085,.06,.004][j]
  v.extend([(p[0]-width/2,p[1],p[2]),(p[0]+width/2,p[1]+.008,p[2]-.015)])
 mesh('Tapered wind caught scarf tail',v,[(i,i+1,i+3,i+2) for i in range(0,8,2)],black,'Spine2',.005)

# Useful humanoid preview rig. It does not replace the game's Erika skeleton.
armdata=bpy.data.armatures.new('Huntress editable humanoid rig');rig=bpy.data.objects.new('Huntress_Rig',armdata);scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active=rig;bpy.ops.object.mode_set(mode='EDIT')
def bone(name,a,b,parent=None):
 e=armdata.edit_bones.new(name);e.head=a;e.tail=b
 if parent:e.parent=armdata.edit_bones[parent]
bone('Root',(0,0,0),(0,0,.18))
bone('Hips',(0,0,.96),(0,0,1.075),'Root')
bone('Spine',(0,0,1.075),(0,0,1.19),'Hips')
bone('Spine1',(0,0,1.19),(0,0,1.31),'Spine')
bone('Spine2',(0,0,1.31),(0,0,1.45),'Spine1')
bone('Neck',(0,0,1.45),(0,0,1.56),'Spine2')
bone('Head',(0,0,1.56),(0,0,1.80),'Neck')
for s in [-1,1]:
 side='Left' if s==1 else 'Right'
 bone(side+'Shoulder',(s*.04,0,1.44),(s*.17,0,1.43),'Spine2')
 bone(side+'Arm',(s*.17,0,1.43),(s*.305,0,1.16),side+'Shoulder')
 bone(side+'ForeArm',(s*.305,0,1.16),(s*.365,-.015,1.005),side+'Arm')
 bone(side+'Hand',(s*.365,-.015,1.005),(s*.399,-.016,.92),side+'ForeArm')
 bone(side+'UpLeg',(s*.08,0,.96),(s*.12,0,.54),'Hips')
 bone(side+'Leg',(s*.12,0,.54),(s*.14,.015,.115),side+'UpLeg')
 bone(side+'Foot',(s*.14,.015,.115),(s*.145,-.12,.05),side+'Leg')
for name,a,b,parent in fingerbones:
 if parent in armdata.edit_bones:bone(name,a,b,parent)
bpy.ops.object.mode_set(mode='OBJECT')

def segdist(p,b):
 a=b.head_local;d=b.tail_local-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-a-t*d).length
for o in parts:
 bname=bindings[o.name]
 if bname:
  g=o.vertex_groups.new(name=bname);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
 else:
  side='Left' if o.location.x>=0 else 'Right'
  # Object geometry is mostly in world coordinates; use the mean to identify side.
  center=sum((o.matrix_world@v.co for v in o.data.vertices),Vector())/max(1,len(o.data.vertices))
  side='Left' if center.x>0 else 'Right'
  candidates=[armdata.bones[side+n] for n in (['Arm','ForeArm'] if center.z>1.03 else ['UpLeg','Leg'])]
  gs={b.name:o.vertex_groups.new(name=b.name) for b in candidates}
  for vert in o.data.vertices:
   p=o.matrix_world@vert.co;ds=[1/max(.015,segdist(p,b))**4 for b in candidates];total=sum(ds)
   for b,d in zip(candidates,ds):gs[b.name].add([vert.index],d/total,'REPLACE')
 mod=o.modifiers.new('Humanoid skin','ARMATURE');mod.object=rig;o.parent=rig

# A small breathing preview clip; no claim of locomotion/coat physics compatibility.
rig.animation_data_create()
for frame,val in [(1,0),(49,.012),(97,0)]:
 pb=rig.pose.bones['Spine2'];pb.rotation_mode='XYZ';pb.rotation_euler.y=val;pb.keyframe_insert('rotation_euler',frame=frame,group='Breathing')
 pb=rig.pose.bones['Head'];pb.rotation_mode='XYZ';pb.rotation_euler.z=-val*.5;pb.keyframe_insert('rotation_euler',frame=frame,group='Breathing')
rig.animation_data.action.name='Huntress_Breathing_Preview'
scene.frame_start=1;scene.frame_end=97;scene.render.fps=24;scene.frame_set(1)

# Convert topology detail to the GLB itself. UVs are provided for subsequent painting.
for o in parts:
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 if not o.data.uv_layers:
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
  bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
 o.data.update()
bpy.ops.object.select_all(action='DESELECT')
for o in parts+[rig]:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=str(OUT/'huntress.glb'),export_format='GLB',use_selection=True,export_yup=True,export_animations=True,export_skins=True,export_apply=False)
triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in parts)
report={'triangles':triangles,'mesh_parts':len(parts),'bones':len(armdata.bones),'height_m':round(max((o.matrix_world@v.co).z for o in parts for v in o.data.vertices),3),'materials':16,'animation':'Huntress_Breathing_Preview','source_anatomy':'Existing project Erika Archer FBX, head and gloves only','status':'Standalone visual test; campaign untouched; locomotion retarget and coat physics pending approval'}
(OUT/'asset_report.json').write_text(json.dumps(report,indent=2),encoding='utf8')

# Neutral presentation studio, deliberately excluded from export.
studio=bpy.data.collections.new('STUDIO | not exported');scene.collection.children.link(studio)
def studio_obj(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 studio.objects.link(o);return o
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002));floor=studio_obj(bpy.context.object);floor.name='Studio ground'
floor.data.materials.append(mat('Studio warm grey',(.12,.105,.085)))
world=bpy.data.worlds.new('Neutral studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.25,.24,.22,1);world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
def area(name,loc,power,color,size):
 d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
 o=bpy.data.objects.new(name,d);studio.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
area('Large soft key',(-3,-4,5),400,(1,.87,.72),4)
area('Cool soft fill',(3,-2,2.7),210,(.75,.85,1),3)
area('Warm rim',(1,3,4),500,(1,.65,.36),3)
bpy.ops.object.camera_add(location=(2,-5,2.3));cam=studio_obj(bpy.context.object);scene.camera=cam
cam.data.type='ORTHO';cam.data.ortho_scale=2.18
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
for screen in bpy.data.screens:
 for a in screen.areas:
  if a.type=='VIEW_3D':
   a.spaces.active.region_3d.view_distance=2.8;a.spaces.active.region_3d.view_location=(0,0,.95);a.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'huntress.blend'))
for name,loc in [('front',(0,-5,1.36)),('three_quarter',(2.8,-5,1.7)),('back',(2.4,5,1.6)),('face',(1,-4,1.9))]:
 target=Vector((0,0,1.65 if name=='face' else .94));cam.location=loc;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.55 if name=='face' else 2.13
 scene.render.filepath=str(OUT/('preview_'+name+'.png'));bpy.ops.render.render(write_still=True)
print('HUNTRESS_BUILD_OK',json.dumps(report))
