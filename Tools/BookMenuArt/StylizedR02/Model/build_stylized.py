"""Standalone Blender 5.2 build. All coordinates are metres; no external packages.

New slim rig: deliberately not compatible with Anim_Book_Skeleton rest pose.
Run: blender -b --factory-startup --python <this script>
"""
import bpy, math, os, json, random, importlib.util
from mathutils import Vector
from math import sin, cos, pi

OUT=os.path.dirname(os.path.abspath(__file__))
PAGE_W=.25; PAGE_H=.36; BOARD_W=.267; BOARD_H=.384
HINGE_Z=.014; SURFACE_Z=.013; TURN_Z=.0148; BOARD_T=.003
SLOTS=['Cover','PagesBase','PageA','PageB','PageC','PageD','PageFirst','PageLast']
COLORS={
 'Cover':(.16,.205,.075,1),'PagesBase':(.69,.50,.29,1),
 'PageA':(.93,.81,.59,1),'PageB':(.93,.81,.59,1),'PageC':(.93,.81,.59,1),
 'PageD':(.93,.81,.59,1),'PageFirst':(.80,.65,.40,1),'PageLast':(.80,.65,.40,1),
 'Leather':(.25,.09,.035,1),'LeatherLight':(.39,.16,.06,1),'Thread':(.78,.57,.27,1),
 'Brass':(.63,.36,.105,1),'BrassLight':(.79,.52,.20,1),'Emblem':(.83,.65,.30,1),
 'Patch':(.54,.34,.15,1),'Scuff':(.24,.265,.09,1),'Bookmark':(.61,.045,.033,1),
 'BookmarkLight':(.83,.10,.065,1),'PageEdgeLight':(.86,.71,.47,1),'CoverDark':(.095,.13,.038,1)}

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
for x in list(bpy.data.materials): bpy.data.materials.remove(x)
MATS={}
for name,color in COLORS.items():
 m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=color
 bs.inputs['Roughness'].default_value=.78 if 'Brass' not in name else .56
 MATS[name]=m
for slot,file in [('PageA','PageLeft.png'),('PageB','PageRight.png'),('PageC','PageLeft.png'),('PageD','PageRight.png'),('PageFirst','PageRight.png'),('PageLast','PageLeft.png')]:
 path=os.path.normpath(os.path.join(OUT,'..','Textures',file))
 if os.path.exists(path):
  m=MATS[slot]; tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(path,check_existing=True)
  m.node_tree.links.new(tex.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color']); tex.image.pack()

# Bone orientation is global +Y, so its local Y is the physical book hinge.
armdata=bpy.data.armatures.new('Cookbook_Slim_Skeleton'); arm=bpy.data.objects.new('Cookbook_Slim_Armature',armdata)
bpy.context.collection.objects.link(arm); bpy.context.view_layer.objects.active=arm; arm.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,parent=None):
 b=armdata.edit_bones.new(name); b.head=head; b.tail=Vector(head)+Vector((0,.07,0))
 if parent: b.parent=armdata.edit_bones[parent]
 return b
bone('Master',(0,0,0)); bone('Cover_L',(0,0,HINGE_Z),'Master'); bone('Cover_R',(0,0,HINGE_Z),'Master'); bone('Spine',(0,0,HINGE_Z),'Master')
for i in range(8): bone('PageTurn_%02d'%(i+1),(.007+PAGE_W*i/8,0,TURN_Z),'Master' if i==0 else 'PageTurn_%02d'%i)
bpy.ops.object.mode_set(mode='OBJECT'); arm.select_set(False)
for b in arm.pose.bones: b.rotation_mode='XYZ'
PARTS=[]

def objmesh(name,verts,faces,mat='Cover',group='Cover_L',uvs=None):
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.materials.append(MATS[mat]); me.update()
 ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
 uv=me.uv_layers.new(name='UVMap')
 for p in me.polygons:
  for li in p.loop_indices:
   vi=me.loops[li].vertex_index
   uv.data[li].uv=uvs[vi] if uvs else ((verts[vi][0]+BOARD_W)/(BOARD_W*2),(verts[vi][1]+BOARD_H/2)/BOARD_H)
 if group:
  vg=ob.vertex_groups.new(name=group); vg.add(list(range(len(verts))),1,'REPLACE')
 mod=ob.modifiers.new('Cookbook skin','ARMATURE'); mod.object=arm; ob.parent=arm
 PARTS.append(ob); return ob

def bevel_apply(ob,width=.0015,segments=2):
 bpy.context.view_layer.objects.active=ob; ob.select_set(True)
 mod=ob.modifiers.new('Rounded handcrafted edges','BEVEL'); mod.width=width; mod.segments=segments
 bpy.ops.object.modifier_move_up(modifier=mod.name)
 bpy.ops.object.modifier_apply(modifier=mod.name); ob.select_set(False)
 return ob

def prism(name,poly,z0,z1,mat,group,bev=0):
 n=len(poly); v=[(x,y,z) for z in [z0,z1] for x,y in poly]
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 ob=objmesh(name,v,f,mat,group)
 if bev: bevel_apply(ob,bev)
 return ob

def rounded_rect(x0,x1,y0,y1,r=.007):
 pts=[]
 for cx,cy,a0 in [(x1-r,y1-r,0),(x0+r,y1-r,90),(x0+r,y0+r,180),(x1-r,y0+r,270)]:
  for a in range(a0,a0+91,30):
   # counterclockwise outline
   pts.append((cx+r*cos(math.radians(a)),cy+r*sin(math.radians(a))))
 return pts

def tube(name,points,r,mat,group,sides=6):
 verts=[]
 for i,p in enumerate(points):
  p=Vector(p); tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
  tangent.normalize(); ref=Vector((0,0,1)) if abs(tangent.z)<.9 else Vector((0,1,0))
  u=tangent.cross(ref).normalized(); v=tangent.cross(u).normalized()
  verts += [tuple(p+r*(u*cos(j*2*pi/sides)+v*sin(j*2*pi/sides))) for j in range(sides)]
 faces=[]
 for i in range(len(points)-1):
  for j in range(sides): faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
 faces += [tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))]
 return objmesh(name,verts,faces,mat,group)

def ellipse(cx,cy,rx,ry,n=20): return [(cx+rx*cos(i*2*pi/n),cy+ry*sin(i*2*pi/n)) for i in range(n)]

# Cover boards, faceted edge bands, corner protectors and intentionally large painted scuffs.
for side in [-1,1]:
 g='Cover_L' if side<0 else 'Cover_R'; x0,x1=(-BOARD_W,-.006) if side<0 else (.006,BOARD_W)
 prism('Front board' if side<0 else 'Back board',rounded_rect(x0,x1,-BOARD_H/2,BOARD_H/2),-.003,0,'Cover',g,.0013)
 # inset cloth field on exterior; dark edge rim remains legible
 prism('Inset cloth field',rounded_rect(x0+.006,x1-.006,-.186,.186),-.0037,-.003,'CoverDark',g,.001)
 prism('Olive cloth',rounded_rect(x0+.009,x1-.009,-.183,.183),-.00395,-.0037,'Cover',g,.0007)
 for ysign in [-1,1]:
  outer=side*(BOARD_W-.001); inner=side*(BOARD_W-.033); yy=ysign*(BOARD_H/2-.001)
  poly=[(outer,yy),(inner,yy),(inner+side*.005,yy-ysign*.012),(outer-side*.014,yy-ysign*.016),(outer-side*.014,yy-ysign*.034),(outer,yy-ysign*.034)]
  prism('Forged corner',poly,-.0052,.001,'Brass',g,.0016)
  poly2=[(outer-side*.003,yy-ysign*.003),(inner+side*.007,yy-ysign*.003),(outer-side*.005,yy-ysign*.015)]
  prism('Corner highlight',poly2,-.0054,-.0052,'BrassLight',g)
 rng=random.Random(44+side)
 for i in range(11):
  x=side*rng.uniform(.035,.24); y=rng.uniform(-.16,.16); sx=rng.uniform(.007,.022); sy=rng.uniform(.007,.021)
  if side<0 and abs(x+.145)<.075 and abs(y)<.08: continue
  poly=[(x-sx,y),(x-sx*.5,y+sy),(x+sx*.6,y+sy*.7),(x+sx,y-sy*.3),(x,y-sy)]
  prism('Broad cloth wear',poly,-.00405,-.00398,'Scuff',g)
 # patch on front lower corner, rear higher offset
 px=side*.079; py=-.112 if side<0 else .12
 prism('Sewn repair patch',rounded_rect(px-.027,px+.027,py-.033,py+.033,.004),-.0051,-.0041,'Patch',g,.0004)
 for i in range(5):
  xx=px-.023+i*.0115
  for yy in [py-.033,py+.033]: tube('Patch stitches',[(xx-.0014,yy-.003,-.0056),(xx+.0014,yy+.003,-.0056)],.00075,'Thread',g,5)
 for j in range(4):
  yy=py-.023+j*.015
  for xx in [px-.027,px+.027]: tube('Patch stitches',[(xx-.003,yy-.0014,-.0056),(xx+.003,yy+.0014,-.0056)],.00075,'Thread',g,5)

# Raised gold pot and leaf sprigs are actual silhouette geometry on exterior front.
g='Cover_L'; cx=-.146; cy=.025
prism('Pot bowl',[(cx-.041,cy+.013),(cx+.041,cy+.013),(cx+.034,cy-.039),(cx+.021,cy-.047),(cx-.021,cy-.047),(cx-.034,cy-.039)],-.0053,-.0041,'Emblem',g,.0012)
prism('Pot lid',ellipse(cx,cy+.021,.047,.006),-.0056,-.0041,'Emblem',g,.0007)
prism('Pot knob',ellipse(cx,cy+.033,.009,.005,12),-.0056,-.0041,'Emblem',g,.0005)
for sign in [-1,1]:
 tube('Pot handles',[(cx+sign*.041,cy+.007,-.0049),(cx+sign*.054,cy+.011,-.0049),(cx+sign*.055,cy-.002,-.0049),(cx+sign*.041,cy-.008,-.0049)],.0024,'Emblem',g)
 bx=cx+sign*.07
 tube('Leaf stems',[(bx-sign*.009,cy-.045,-.0047),(bx,cy-.02,-.0047),(bx+sign*.005,cy+.019,-.0047)],.0011,'Emblem',g,5)
 for j in range(3):
  yy=cy-.028+j*.019; xx=bx+sign*j*.002
  poly=[(xx,yy),(xx+sign*.014,yy+.007),(xx+sign*.015,yy+.019),(xx+sign*.005,yy+.014)]
  prism('Emblem leaves',poly,-.005,-.0042,'Emblem',g,.0003)

# Rounded leather spine with broad raised sewn bands.
verts=[]; faces=[]; rings=3; seg=20
for j in range(rings):
 yy=-BOARD_H/2+j*BOARD_H/(rings-1)
 for i in range(seg):
  a=i*2*pi/seg; verts.append((.011*cos(a),yy,.011+.013*sin(a)))
for j in range(rings-1):
 for i in range(seg): faces.append((j*seg+i,j*seg+(i+1)%seg,(j+1)*seg+(i+1)%seg,(j+1)*seg+i))
faces += [tuple(reversed(range(seg))),tuple((rings-1)*seg+i for i in range(seg))]
objmesh('Rounded leather spine',verts,faces,'Leather','Spine')
for yy in [-.155,-.075,.025,.125,.177]:
 pts=[(.0116*cos(a),yy,.011+.0136*sin(a)) for a in [pi/2+i*pi/8 for i in range(17)]]
 tube('Raised spine binding',pts,.0019,'LeatherLight','Spine')
 # visible cream saddle stitch follows spine across its exposed top
 pts=[(.0123*cos(a),yy-.001,.011+.0141*sin(a)) for a in [pi*.18+i*pi*.64/9 for i in range(10)]]
 tube('Saddle stitch',pts,.0011,'Thread','Spine')
for yy in [i*.026-.17 for i in range(14)]:
 for side in [-1,1]: tube('Hinge stitches',[(side*.018,yy-.004,-.0048),(side*.018,yy+.004,-.0048)],.0009,'Thread','Cover_L' if side<0 else 'Cover_R',5)

# Page blocks and visible ridged signatures. All edge grooves are modeled.
for side in [-1,1]:
 g='Cover_L' if side<0 else 'Cover_R'; x0,x1=(-.257,-.012) if side<0 else (.012,.257)
 prism('Ivory page block',rounded_rect(x0,x1,-.182,.182,.006),.0012,.012,'PagesBase',g,.0013)
 for i in range(9):
  z=.0017+i*.00114; inset=.0005 if i%3 else .001
  poly=rounded_rect(x0+inset,x1-inset,-.181+inset,.181-inset,.005)
  prism('Paper signature ridge',poly,z,z+.00036,'PageEdgeLight',g,.00012)
 # grid page for full UV0 widget target
 nx,ny=24,32; verts=[]; uvs=[]; faces=[]
 for j in range(ny+1):
  for i in range(nx+1):
   u=i/nx; v=j/ny
   x=(.011+u*PAGE_W)*side; y=(v-.5)*PAGE_H
   # small gutter roll below page plane, edges remain flat and quad mapped
   z=SURFACE_Z-.0011*math.exp(-u*14)
   verts.append((x,y,z)); uvs.append((u if side>0 else 1-u,v))
 for j in range(ny):
  for i in range(nx):
   a=j*(nx+1)+i; face=(a,a+1,a+nx+2,a+nx+1)
   faces.append(face if side>0 else tuple(reversed(face)))
 objmesh('Left widget page' if side<0 else 'Right widget page',verts,faces,'PageA' if side<0 else 'PageD',g,uvs)
 # Endpapers kept in the specified separate slots, on inside board margin.
 poly=rounded_rect(x0+.002,x1-.002,-.18,.18,.004)
 endpaper=prism('Endpaper',poly,.0008,.0011,'PageLast' if side<0 else 'PageFirst',g)
 for p in endpaper.data.polygons:
  for li in p.loop_indices:
   v=endpaper.data.vertices[endpaper.data.loops[li].vertex_index].co
   u=(v.x-(x0+.002))/(x1-x0-.004)
   endpaper.data.uv_layers[0].data[li].uv=(u,(v.y+.18)/.36)

# Red swallowtail bookmark, seated in spine and hanging past the tail.
prism('Red ribbon', [(-.006,-.10),(.006,-.10),(.008,-.226),(0,-.218),(-.008,-.226)],.009,.0096,'Bookmark','Spine',.0003)
prism('Ribbon highlight',[(-.005,-.15),(-.001,-.15),(.002,-.220),(-.006,-.224)],.00965,.0098,'BookmarkLight','Spine')

# Double sided turning leaf with actual rim, UV0 normalized separately per face.
nx,ny=32,32; verts=[]; uvs=[]; faces=[]
for layer in range(2):
 for j in range(ny+1):
  for i in range(nx+1):
   u=i/nx; v=j/ny; x=.011+PAGE_W*u; y=(v-.5)*PAGE_H
   verts.append((x,y,TURN_Z+(1 if layer==0 else -1)*.00015)); uvs.append((u if layer==0 else 1-u,v))
N=(nx+1)*(ny+1)
for layer in range(2):
 for j in range(ny):
  for i in range(nx):
   a=layer*N+j*(nx+1)+i; f=(a,a+1,a+nx+2,a+nx+1); faces.append(f if layer==0 else tuple(reversed(f)))
surface_count=len(faces)
boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
for k,a in enumerate(boundary):
 b=boundary[(k+1)%len(boundary)]; faces.append((a,b,b+N,a+N))
turn=objmesh('Turning leaf',verts,faces,'PageB',None,uvs); turn.data.materials.append(MATS['PageC']); turn.data.materials.append(MATS['PagesBase'])
for p in turn.data.polygons: p.material_index=0 if p.index<nx*ny else 1 if p.index<surface_count else 2
for i in range(8): turn.vertex_groups.new(name='PageTurn_%02d'%(i+1))
for v in turn.data.vertices:
 q=max(0,min(7,(v.co.x-.007)/PAGE_W*8)); lo=int(q); t=q-lo
 turn.vertex_groups[lo].add([v.index],1-t,'REPLACE')
 if lo<7 and t>0: turn.vertex_groups[lo+1].add([v.index],t,'REPLACE')
turn.shape_key_add(name='Basis')
for k in range(1,5):
 key=turn.shape_key_add(name='PageBend_%02d'%k)
 for v in key.data:
  u=(v.co.x-.011)/PAGE_W; yy=v.co.y/(PAGE_H/2)
  bump=sin(pi*u)*.009
  v.co.z += bump * ([1,yy,-yy,cos(pi*u)][k-1])
 # custom property curves survive FBX; Unreal curves must drive the like-named morph targets.
 arm[key.name]=0.; drv=key.driver_add('value').driver; drv.expression='bend'
 var=drv.variables.new(); var.name='bend'; var.targets[0].id=arm; var.targets[0].data_path='["%s"]'%key.name

# Join into one skeletal mesh without collapsing slots or weights.
bpy.ops.object.select_all(action='DESELECT')
for ob in PARTS: ob.select_set(True)
bpy.context.view_layer.objects.active=turn
bpy.ops.object.join(); mesh=bpy.context.object; mesh.name='SK_Cookbook_StylizedR02'
# Normalize material order to the eight runtime slots first; decorative geometry uses appended explicit slots.
old=list(mesh.data.materials); ordered=[MATS[s] for s in SLOTS]+[m for m in old if m.name not in SLOTS]
ordered=list(dict.fromkeys(ordered)); assignments=[ordered.index(old[p.material_index]) for p in mesh.data.polygons]
mesh.data.materials.clear()
for m in ordered: mesh.data.materials.append(m)
for p,idx in zip(mesh.data.polygons,assignments): p.material_index=idx
for m in list(mesh.modifiers)[1:]: mesh.modifiers.remove(m)
mesh['widget_material_contract']='UV0 normalized full rectangles; slot names PageA/B/C/D/PageFirst/PageLast'
mesh['skeleton_compatibility']='NEW skeleton; incompatible with Anim_Book_Skeleton rest pose and legacy clips'
# Author at portable handbook dimensions, with all rest vertices and rest bones
# rebased together. Object and pose scales remain exactly one.
AUTHOR_SCALE=Vector((.68,23/36,.68))
for key in mesh.data.shape_keys.key_blocks:
 for v in key.data: v.co=Vector((v.co.x*AUTHOR_SCALE.x,v.co.y*AUTHOR_SCALE.y,v.co.z*AUTHOR_SCALE.z))
# FBX reads the mesh's base vertices independently of KeyBlock Basis.
# Explicitly synchronize both stores; a rendered Basis alone is insufficient.
for v,basis in zip(mesh.data.vertices,mesh.data.shape_keys.key_blocks['Basis'].data): v.co=basis.co.copy()
mesh.data.update()
bpy.context.view_layer.objects.active=arm; bpy.ops.object.mode_set(mode='EDIT')
for b in armdata.edit_bones:
 b.head=Vector((b.head.x*AUTHOR_SCALE.x,b.head.y*AUTHOR_SCALE.y,b.head.z*AUTHOR_SCALE.z))
 b.tail=Vector((b.tail.x*AUTHOR_SCALE.x,b.tail.y*AUTHOR_SCALE.y,b.tail.z*AUTHOR_SCALE.z))
bpy.ops.object.mode_set(mode='OBJECT')
arm['page_width_cm']=17.; arm['page_height_cm']=23.; arm['rest_pose']='flat open'; arm['units']='metres'

scene=bpy.context.scene; scene.render.fps=60; scene.unit_settings.system='METRIC'; scene.unit_settings.scale_length=1
actions={}
def set_pose(openness,turn_t=None):
 for b in arm.pose.bones: b.rotation_euler=(0,0,0); b.location=(0,0,0); b.scale=(1,1,1)
 # The left cover must cross ABOVE the book: positive Y lifts negative-X geometry.
 arm.pose.bones['Cover_L'].rotation_euler.y=pi*(1-openness)
 # Turning leaf rests over left stack when closed, travels to right as book opens.
 angle=0 if turn_t is None else -pi*turn_t
 arm.pose.bones['PageTurn_01'].rotation_euler.y=angle
 # Rotate around the spine centre, compensating the bend chain's offset rest head.
 root=arm.pose.bones['PageTurn_01']; radius=root.bone.head_local.x
 root.location=root.bone.matrix_local.to_3x3().inverted()@Vector((radius*(cos(angle)-1),0,-radius*sin(angle)))
 for i in range(1,8):
  arm.pose.bones['PageTurn_%02d'%(i+1)].rotation_euler.y=0 if turn_t is None else .105*sin(pi*turn_t)*sin(pi*i/8)
 for k in range(1,5): arm['PageBend_%02d'%k]=0.
 if turn_t is not None:
  arm['PageBend_01']=.7*sin(pi*turn_t); arm['PageBend_02']=.27*sin(2*pi*turn_t)

clips=[('Book_Lying_R_01',24,'closed'),('Book_Lying_Open_01',24,'open'),('Book_Lying_R_to_Open_01',48,'opening'),('Book_Lying_Open_to_R_01',48,'closing'),('Book_Lying_Open_Page_Turn_R_to_L_02',108,'rtl'),('Book_Lying_Open_Page_Turn_L_to_R_02',108,'ltr')]
for name,frames,kind in clips:
 arm.animation_data_create(); act=bpy.data.actions.new(name); arm.animation_data.action=act; act.use_fake_user=True
 for f in range(1,frames+1):
  t=(f-1)/(frames-1); ease=t*t*(3-2*t)
  op=0 if kind=='closed' else 1 if kind in ['open','rtl','ltr'] else ease if kind=='opening' else 1-ease
  turn_t=ease if kind=='rtl' else 1-ease if kind=='ltr' else None
  set_pose(op,turn_t)
  for b in arm.pose.bones: b.keyframe_insert('rotation_euler',frame=f,group=b.name)
  arm.pose.bones['PageTurn_01'].keyframe_insert('location',frame=f,group='PageTurn_01')
  for k in range(1,5): arm.keyframe_insert('["PageBend_%02d"]'%k,frame=f,group='Morph curves')
 actions[kind]=act

def activate(kind,frame):
 arm.animation_data.action=actions[kind]; arm.animation_data.action_slot=actions[kind].slots[0]; scene.frame_set(frame); bpy.context.view_layer.update()
def bounds():
 ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()); pts=[ev.matrix_world@v.co for v in ev.data.vertices]
 lo=Vector([min(p[i] for p in pts) for i in range(3)]); hi=Vector([max(p[i] for p in pts) for i in range(3)])
 return lo,hi

# Validation samples every baked frame; report geometric bounds and analytical hinge clearance.
report={'skeleton_compatible_with_original':False,'reason':'Physical slim hinge rest transforms and new 12-bone skeleton; use supplied six animations. Original thick-tome clips are not interchangeable.',
 'bones':len(arm.data.bones),'bone_names':[b.name for b in arm.data.bones], 'vertices':len(mesh.data.vertices),'polygons':len(mesh.data.polygons),'triangles':sum(len(p.vertices)-2 for p in mesh.data.polygons),
 'material_slots':[m.name for m in mesh.data.materials],'morphs':[k.name for k in mesh.data.shape_keys.key_blocks],
 'unweighted_vertices':sum(not v.groups or sum(g.weight for g in v.groups)<.999 for v in mesh.data.vertices),
 'max_vertex_influences':max(len(v.groups) for v in mesh.data.vertices),'actions':{},'states_cm':{},'page_uv0':{},
 'units':'metres; apply component scale 1.0. FBX exported in centimetres automatically.',
 'page_dimensions_cm':[17,23], 'author_scale_baked_into_geometry_and_bone_rest':list(AUTHOR_SCALE),
 'clearances_mm':{'closed_left_right_page_gap':2*(HINGE_Z-SURFACE_Z)*1000*AUTHOR_SCALE.z,'open_turning_leaf_gap':(TURN_Z-.00015-SURFACE_Z)*1000*AUTHOR_SCALE.z},
 'intersection_test':'Analytical rigid hinge/page clearance plus sampled-frame finite/bounds check. No exhaustive triangle collision proof; rounded spine and sewn-band overlaps are intentional.',
 'textures': {s:bool(MATS[s].node_tree.nodes.get('Image Texture')) for s in SLOTS if s.startswith('Page')},
 'unreal_runtime_verified':False}
for slot in ['PageA','PageB','PageC','PageD','PageFirst','PageLast']:
 mi=mesh.data.materials.find(slot); coords=[mesh.data.uv_layers[0].data[li].uv for p in mesh.data.polygons if p.material_index==mi for li in p.loop_indices]
 report['page_uv0'][slot]={'min':[min(v[i] for v in coords) for i in range(2)],'max':[max(v[i] for v in coords) for i in range(2)]}
for name,frames,kind in clips:
 maxdim=Vector((0,0,0)); nonfinite=0
 for f in range(1,frames+1):
  activate(kind,f); lo,hi=bounds(); dim=hi-lo
  nonfinite+=int(not all(math.isfinite(v) for v in (*lo,*hi)))
  maxdim=Vector([max(maxdim[i],dim[i]) for i in range(3)])
 report['actions'][name]={'frames':frames,'fps':60,'nonfinite_samples':nonfinite,'max_dimensions_cm':[round(v*100,3) for v in maxdim]}
 activate(kind,1); lo,hi=bounds(); report['states_cm'][kind]=[round(v*100,3) for v in hi-lo]

# Use temporary centimetre mesh/key/rest coordinates so stripped Blender dummy
# cannot leave Unreal with rest Master scale100 but animated Master scale1.
spec=importlib.util.spec_from_file_location('cookbook_cm_export',os.path.join(OUT,'export_centimetres.py'))
cm_export=importlib.util.module_from_spec(spec); spec.loader.exec_module(cm_export)
cm_report=cm_export.export_centimetres(mesh,arm)
json.dump(cm_report,open(os.path.join(OUT,'cm_export_report.json'),'w'),indent=2)

# Studio presentation: neutral warm background, large soft lights, explicit camera for each requested state.
scene.render.engine='BLENDER_EEVEE'; scene.eevee.taa_render_samples=64
scene.render.resolution_x=1400; scene.render.resolution_y=1100; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.film_transparent=False
scene.world=bpy.data.worlds.new('Warm studio'); scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.30,.255,.18,1); scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
scene.view_settings.view_transform='AgX'; scene.view_settings.look='AgX - Medium High Contrast'
def area(name,loc,energy,size):
 ob=bpy.data.objects.new(name,bpy.data.lights.new(name,'AREA')); bpy.context.collection.objects.link(ob); ob.location=loc; ob.data.energy=energy; ob.data.shape='DISK'; ob.data.size=size
 ob.rotation_euler=(Vector((.05,0,0))-ob.location).to_track_quat('-Z','Y').to_euler()
area('Softbox key',(-.35,-.25,.8),8,.65); area('Softbox fill',(.5,.25,.6),4,.6); area('Warm edge',(-.2,.5,.4),3,.35)
cam=bpy.data.objects.new('Presentation camera',bpy.data.cameras.new('Presentation camera')); bpy.context.collection.objects.link(cam); scene.camera=cam; cam.data.type='ORTHO'; cam.data.lens=50; cam.data.clip_start=.001
def camera(direction,scale=1):
 lo,hi=bounds(); center=(lo+hi)/2; direction=Vector(direction).normalized(); cam.location=center+direction*1.4
 cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 # Project all eight evaluated-bound corners, so raised/opening pages stay framed.
 corners=[Vector((x,y,z)) for x in (lo.x,hi.x) for y in (lo.y,hi.y) for z in (lo.z,hi.z)]
 rot=cam.rotation_euler.to_matrix().transposed(); projected=[rot@(p-center) for p in corners]
 width=max(p.x for p in projected)-min(p.x for p in projected); height=max(p.y for p in projected)-min(p.y for p in projected)
 cam.data.ortho_scale=max(width,height*scene.render.resolution_x/scene.render.resolution_y)*1.14*scale
os.makedirs(os.path.join(OUT,'Renders'),exist_ok=True)
shots=[('01-closed','closed',1,(.32,-.64,1.25),1),('02-open','open',1,(.1,-.48,1.5),1),('03-rear','closed',1,(.3,.5,-1.2),1),('04-side','closed',1,(1,-.3,.16),1),('05-page-turn','rtl',55,(.12,-.65,1.25),1),('06-turn-early','rtl',30,(.12,-.65,1.25),1),('07-turn-late','rtl',80,(.12,-.65,1.25),1),('08-opening','opening',27,(.3,-.7,1.1),1)]
for name,kind,f,direction,scale in shots:
 activate(kind,f); camera(direction,scale); scene.render.filepath=os.path.join(OUT,'Renders',name+'.png'); bpy.ops.render.render(write_still=True)
 report['states_cm'][name]=[round(v*100,3) for v in bounds()[1]-bounds()[0]]
# Save with packed demo materials. Blank variant swaps only nodes; geometry/slots/animations remain identical.
activate('open',1); scene.frame_start=1; scene.frame_end=108; camera((.1,-.48,1.5))
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'Cookbook_StylizedR02.blend'))
for s in SLOTS:
 if s.startswith('Page') and s!='PagesBase':
  m=MATS[s]
  for n in list(m.node_tree.nodes):
   if n.type=='TEX_IMAGE': m.node_tree.nodes.remove(n)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'Cookbook_StylizedR02_WidgetReady.blend'))
json.dump(report,open(os.path.join(OUT,'validation.json'),'w'),indent=2)
print('COOKBOOK_BUILD_COMPLETE '+json.dumps({'bones':report['bones'],'triangles':report['triangles'],'unweighted':report['unweighted_vertices'],'states_cm':report['states_cm']}))
