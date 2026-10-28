"""Reusable Blender mesh tools. Input geometry is UE centimetres, X radial.

The only handedness conversion is here: Blender vertices=(X,-Y,Z)/100.
The catalog manifest and placement recipes remain in UE centimetres.
"""
import math, random, hashlib
import bpy, bmesh
from mathutils import Vector

def rgb(hexcolor):
    raw=[int(hexcolor.lstrip('#')[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in raw)

def materials(spec):
    result={}
    for row in spec['materials']+[dict(id='M09_Emissive',palette='#ffb654',roughness=.4),dict(id='M00',palette='#181d20',roughness=.9)]:
        key=row['id'];m=bpy.data.materials.new('SP_'+key);m.use_nodes=True
        color=rgb(row['palette']);m.diffuse_color=(*color,1)
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=row['roughness']
        bs.inputs['Metallic'].default_value=.45 if key in ['M05','M06'] else 0
        vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='Col'
        mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[1].default_value=(*color,1)
        m.node_tree.links.new(vc.outputs['Color'],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],bs.inputs['Base Color'])
        if key=='M09_Emissive':bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=2
        m['spire_material']=key;result[key]=m
    return result

class Mesh:
    def __init__(self):self.v=[];self.f=[];self.m=[];self.groups=[];self.group=0
    def part(self,vs,fs,mat):
        n=len(self.v);self.v.extend(tuple(float(x) for x in p) for p in vs)
        self.f.extend([n+i for i in face] for face in fs);self.m.extend([mat]*len(fs));self.groups.extend([self.group]*len(fs));self.group+=1
    def box(self,at,size,mat='M04',yaw=0):
        a=math.radians(yaw);c,s=math.cos(a),math.sin(a);x,y,z=at;dx,dy,dz=[v/2 for v in size]
        vs=[]
        for u,v,w in [(-dx,-dy,-dz),(dx,-dy,-dz),(dx,dy,-dz),(-dx,dy,-dz),(-dx,-dy,dz),(dx,-dy,dz),(dx,dy,dz),(-dx,dy,dz)]:vs.append((x+u*c-v*s,y+u*s+v*c,z+w))
        self.part(vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat)
    def tube(self,a,b,r,mat='M05',sides=8,r2=None):
        a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,0,1)))
        if u.length<.01:u=axis.cross(Vector((0,1,0)))
        u.normalize();v=axis.cross(u).normalized();vs=[]
        for p,rad in [(a,r),(b,r if r2 is None else r2)]:
            for i in range(sides):vs.append(tuple(p+rad*(u*math.cos(math.tau*i/sides)+v*math.sin(math.tau*i/sides))))
        fs=[tuple(reversed(range(sides))),tuple(range(sides,2*sides))]
        fs.extend((i,(i+1)%sides,(i+1)%sides+sides,i+sides) for i in range(sides));self.part(vs,fs,mat)
    def lathe(self,profile,mat='M04',sides=12):
        vs=[(r*math.cos(math.tau*i/sides),r*math.sin(math.tau*i/sides),z) for z,r in profile for i in range(sides)]
        fs=[tuple(reversed(range(sides))),tuple(range((len(profile)-1)*sides,len(profile)*sides))]
        for j in range(len(profile)-1):
            for i in range(sides):fs.append((j*sides+i,j*sides+(i+1)%sides,(j+1)*sides+(i+1)%sides,(j+1)*sides+i))
        self.part(vs,fs,mat)
    def torus(self,at,major,minor,mat='M05',axis='Z',segments=12,tube_segments=4,stretch=(1,1)):
        vs=[];x,y,z=at
        for i in range(segments):
            a=math.tau*i/segments
            for j in range(tube_segments):
                b=math.tau*j/tube_segments;p=((major+minor*math.cos(b))*math.cos(a)*stretch[0],(major+minor*math.cos(b))*math.sin(a)*stretch[1],minor*math.sin(b))
                if axis=='X':p=(p[2],p[0],p[1])
                if axis=='Y':p=(p[0],p[2],p[1])
                vs.append((x+p[0],y+p[1],z+p[2]))
        fs=[]
        for i in range(segments):
            for j in range(tube_segments):fs.append((i*tube_segments+j,((i+1)%segments)*tube_segments+j,((i+1)%segments)*tube_segments+(j+1)%tube_segments,i*tube_segments+(j+1)%tube_segments))
        self.part(vs,fs,mat)
    def polygon_prism(self,points,top,depth,mat='M01',holes=()):
        if holes:
            from mathutils.geometry import delaunay_2d_cdt
            from collections import Counter
            def inside(p,poly):
                hit=False;x,y=p
                for i in range(len(poly)):
                    a,b=poly[i],poly[(i+1)%len(poly)]
                    if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:hit=not hit
                return hit
            vv=[];ee=[]
            for loop in [points]+list(holes):
                start=len(vv);vv.extend(Vector(p) for p in loop);ee.extend((start+i,start+(i+1)%len(loop)) for i in range(len(loop)))
            cv,ce,cf,*_=delaunay_2d_cdt(vv,ee,[],0,1e-7)
            keep=[]
            for f in cf:
                mid=(sum(cv[i].x for i in f)/len(f),sum(cv[i].y for i in f)/len(f))
                if inside(mid,points) and not any(inside(mid,h) for h in holes):keep.append(tuple(f))
            n=len(cv);vs=[(v.x,v.y,z) for z in [top-depth,top] for v in cv];fs=[];edgecount=Counter();directions={}
            for f in keep:
                fs.extend([tuple(reversed(f)),tuple(i+n for i in f)])
                for a,b in zip(f,f[1:]+f[:1]):key=tuple(sorted((a,b)));edgecount[key]+=1;directions[key]=(a,b)
            for key,count in edgecount.items():
                if count==1:a,b=directions[key];fs.append((a,b,b+n,a+n))
            self.part(vs,fs,mat);return
        n=len(points);vs=[(x,y,z) for z in (top-depth,top) for x,y in points]
        # Concave polygons are triangulated using Blender's 2D tessellator.
        from mathutils.geometry import tessellate_polygon
        pv=[Vector((x,y,0)) for x,y in points]
        tris=tessellate_polygon([pv]);fs=[]
        for tri in tris:
            ids=list(tri);fs.extend([tuple(reversed(ids)),tuple(i+n for i in ids)])
        fs.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n));self.part(vs,fs,mat)
    def sector(self,ri,ro,a,b,top,depth,mat='M01',max_angle=2,apron=False,holes=()):
        n=max(1,math.ceil(abs(b-a)/max_angle));angles=[a+(b-a)*i/n for i in range(n+1)]
        if apron:
            for t in [-math.degrees(math.atan(150/ro)),math.degrees(math.atan(150/ro)),-math.degrees(math.asin(150/ro)),math.degrees(math.asin(150/ro))]:
                if a<t<b:angles.append(t)
            angles=sorted(set(angles))
        outer=[]
        for t in angles:
            rad=ro;c=math.cos(math.radians(t));s=math.sin(math.radians(t))
            if apron and c>0:
                far=min(ro/c,150/abs(s) if abs(s)>1e-8 else 1e9)
                if far>ro:rad=far
            outer.append((rad*c,rad*s))
        inner=[(ri*math.cos(math.radians(t)),ri*math.sin(math.radians(t))) for t in reversed(angles)]
        if ri==0:inner=[(0,0)]
        self.polygon_prism(outer+inner,top,depth,mat,holes)
    def rod_curve(self,points,r=4,mat='M05',sides=6):
        for a,b in zip(points,points[1:]):self.tube(a,b,r,mat,sides)
    def object(self,name,mats,collection,bevel_cm=0):
        assert self.v and self.f,name
        mesh=bpy.data.meshes.new(name+'_Mesh');mesh.from_pydata([(x/100,-y/100,z/100) for x,y,z in self.v],[],[tuple(reversed(f)) for f in self.f]);mesh.update()
        o=bpy.data.objects.new(name,mesh);collection.objects.link(o)
        keys=list(dict.fromkeys(self.m))
        for key in keys:mesh.materials.append(mats[key])
        for p,key in zip(mesh.polygons,self.m):p.material_index=keys.index(key);p.use_smooth=False
        uv=mesh.uv_layers.new(name='UVMap')
        for p in mesh.polygons:
            axis=max(range(3),key=lambda k:abs(p.normal[k]));axes=[k for k in range(3) if k!=axis]
            for li in p.loop_indices:
                co=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]],co[axes[1]])
        col=mesh.color_attributes.new(name='Col',type='FLOAT_COLOR',domain='CORNER')
        seed=int(hashlib.sha256(name.encode()).hexdigest()[:8],16);rng=random.Random(seed);tints={g:rng.uniform(.78,1) for g in set(self.groups)}
        for p,g in zip(mesh.polygons,self.groups):
            for li in p.loop_indices:col.data[li].color=(tints[g],tints[g],tints[g],1)
        if bevel_cm:
            bpy.context.view_layer.objects.active=o;o.select_set(True)
            mod=o.modifiers.new('SmallWear','BEVEL');mod.width=bevel_cm/100;mod.segments=1
            bpy.ops.object.modifier_apply(modifier=mod.name);o.select_set(False)
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
        o['spire_asset']=name;o['units']='metres; origin is modeling datum';o.asset_mark();o.asset_data.description='Procedural Spire Connector Kit | '+name
        return o

def export_fbx(o,path,convex=False):
    original=o.name;o.name=original+'__SOURCE'
    bpy.ops.object.select_all(action='DESELECT');copy=o.copy();copy.data=o.data.copy();bpy.context.scene.collection.objects.link(copy)
    for v in copy.data.vertices:v.co*=100
    copy.name=original;copy.select_set(True);bpy.context.view_layer.objects.active=copy
    hulls=[]
    if convex:
        neighbors={i:set() for i in range(len(copy.data.vertices))}
        for e in copy.data.edges:a,b=e.vertices;neighbors[a].add(b);neighbors[b].add(a)
        unseen=set(neighbors)
        while unseen:
            todo=[unseen.pop()];part=[]
            while todo:
                i=todo.pop();part.append(i)
                for j in neighbors[i]&unseen:unseen.remove(j);todo.append(j)
            if len(part)<4:continue
            bm=bmesh.new();vs=[bm.verts.new(copy.data.vertices[i].co) for i in part]
            result=bmesh.ops.convex_hull(bm,input=vs,use_existing_faces=False)
            interior=[v for v in result.get('geom_interior',[]) if isinstance(v,bmesh.types.BMVert)]
            if interior:bmesh.ops.delete(bm,geom=interior,context='VERTS')
            mesh=bpy.data.meshes.new('UCXMesh');bm.to_mesh(mesh);bm.free()
            obj=bpy.data.objects.new('UCX_'+original+'_'+str(len(hulls)).zfill(3),mesh);bpy.context.scene.collection.objects.link(obj);obj.select_set(True);hulls.append(obj)
    old=bpy.context.scene.unit_settings.scale_length;bpy.context.scene.unit_settings.scale_length=.01
    try:bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=True,bake_anim=False,path_mode='STRIP',use_custom_props=True)
    finally:
        for obj in hulls:bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.objects.remove(copy,do_unlink=True);bpy.context.scene.unit_settings.scale_length=old;o.name=original
    return len(hulls)

def record(o):
    vs=[(v.co.x*100,-v.co.y*100,v.co.z*100) for v in o.data.vertices]
    lo=[min(p[k] for p in vs) for k in range(3)];hi=[max(p[k] for p in vs) for k in range(3)]
    return {'name':o.name,'bounds_min_cm':lo,'bounds_max_cm':hi,'dimensions_cm':[hi[k]-lo[k] for k in range(3)],'vertices':len(vs),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'material_keys':[m['spire_material'] for m in o.data.materials]}
