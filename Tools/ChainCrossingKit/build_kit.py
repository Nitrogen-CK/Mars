"""Deterministic headless Blender production: 88 assets, linked library, FBXs and diorama."""
import argparse,hashlib,importlib,json,math,random,sys,time,uuid
from pathlib import Path
import bpy,bmesh
from mathutils import Vector

HERE=Path(__file__).resolve().parent
REPO=HERE.parents[1]
ART=REPO/'docs/art/warrens-c-dressing-r01'
OUT=HERE/'Output'
SEED=1031
CATEGORIES={name:str(uuid.uuid5(uuid.NAMESPACE_URL,'ChainCrossingKit/'+name)) for name in ['Architecture','Mechanisms','Water','Dressing']}
sys.path.insert(0,str(HERE))
for folder in ['FBX','Previews','Renders','Reports']: (OUT/folder).mkdir(parents=True,exist_ok=True)
parts=json.loads((ART/'sections/chain-crossing-sluice/model_catalog.json').read_text())
specs={m['id']:m for m in json.loads((ART/'materials.json').read_text())}
aliases={'Wear_Salt':'Wear_SaltResidue','Wear_Damp':'Wear_DampLeak'}

def write(name,data):
    (OUT/name).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')

def load_materials():
    manifest=json.loads((ART/'blender/library_manifest.json').read_text())
    names=list(set(manifest['materials'].values()))
    with bpy.data.libraries.load(str(ART/'blender/WarrensC_MaterialLibrary.blend'),link=False) as (src,dst):dst.materials=names
    mats={k:bpy.data.materials[n] for k,n in manifest['materials'].items()}
    def plain(key,color,rough=.8,metal=0,alpha=1):
        m=bpy.data.materials.new('CCK_'+key);m.use_nodes=True;m.diffuse_color=(*color,alpha)
        bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal;bs.inputs['Alpha'].default_value=alpha
        if alpha<1:m.surface_render_method='DITHERED'
        m['catalog_key']=key;mats[key]=m;return m
    plain('Glass',(.55,.64,.55),.12,0,.20)
    plain('Ink',(.025,.032,.024))
    plain('Foam',(.65,.68,.54),.8,0,.65)
    plain('Puddle',(.06,.10,.085),.20,0,.38)
    plain('Waterline',(.15,.20,.13),.9,0,.55)
    plain('Ripple',(.45,.57,.48),.4,0,.45)
    plain('Drip',(.20,.35,.31),.2,0,.45)
    plain('FX_ShallowWater',(.035,.16,.14),.30,0,.72)
    for key,m in mats.items():
        m['catalog_key']=key
        if key in {'TX01','TX02','TX03','TX04','TX17'}:
            # Silhouette/joints come from geometry. A second tiled masonry normal
            # pattern made every physical block read as another grid of blocks.
            bs=m.node_tree.nodes.get('Principled BSDF');base=bs.inputs['Base Color']
            tint=specs[key]['base_srgb_hex'].lstrip('#')
            rgb=[int(tint[i:i+2],16)/255 for i in (0,2,4)]
            linear=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
            mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.inputs[0].default_value=.12;mix.inputs[1].default_value=(*linear,1)
            if base.is_linked:
                old=base.links[0].from_socket;m.node_tree.links.remove(base.links[0]);m.node_tree.links.new(old,mix.inputs[2])
            else:mix.inputs[2].default_value=(*linear,1)
            m.node_tree.links.new(mix.outputs[0],base)
            for socket in ['Normal','Roughness','Metallic']:
                for link in list(bs.inputs[socket].links):m.node_tree.links.remove(link)
            bs.inputs['Roughness'].default_value=.88;bs.inputs['Metallic'].default_value=0
    return mats

class Builder:
    def __init__(self,part,mats,col):
        self.part=part;self.id=part['id'];self.size=tuple(part['dimensions_cm'][k]/100 for k in ('width','depth','height'));self.mats=mats;self.col=col;self.objects=[];self.flags={};self.rng=random.Random(int(''.join(c for c in self.id if c.isdigit()) or '0')+SEED)
    def material(self,key):return self.mats[aliases.get(key,key)]
    def mat(self,index=0):
        if self.id=='CCS61':return self.material('Glass')
        keys=self.part['materials'];return self.material(keys[min(index,len(keys)-1)])
    def flag(self,key,value):self.flags[key]=value
    def _keep(self,obj,name,mat):
        obj.name=self.id+'_'+name
        for c in list(obj.users_collection):c.objects.unlink(obj)
        self.col.objects.link(obj)
        obj.data.materials.append(self.mat() if mat is None else self.material(mat) if isinstance(mat,str) else mat)
        self.objects.append(obj);return obj
    def box(self,name,loc,size,mat=None,bevel=.015):
        bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.dimensions=size
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        if bevel>0:
            mod=o.modifiers.new('BroadSingleBevel','BEVEL');mod.width=min(bevel,min(size)*.18);mod.segments=1;mod.affect='EDGES'
        return self._keep(o,name,mat)
    def cyl(self,name,loc,radius,depth,mat=None,axis='Z',sides=12):return self.cone(name,loc,radius,radius,depth,mat,axis,sides)
    def cone(self,name,loc,radius1,radius2,depth,mat=None,axis='Z',sides=12):
        bpy.ops.mesh.primitive_cone_add(vertices=sides,radius1=radius1,radius2=radius2,depth=depth,location=loc)
        o=bpy.context.object;o.rotation_euler={'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0),'Z':(0,0,0)}[axis]
        return self._keep(o,name,mat)
    def torus(self,name,loc,major,minor,mat=None,axis='Z',major_segments=12,minor_segments=4):
        bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=major_segments,minor_segments=minor_segments,location=loc)
        o=bpy.context.object;o.rotation_euler={'X':(0,math.pi/2,0),'Y':(math.pi/2,0,0),'Z':(0,0,0)}[axis]
        return self._keep(o,name,mat)
    def rod(self,name,a,z,radius,mat=None,sides=8):
        a,z=Vector(a),Vector(z);d=z-a
        o=self.cyl(name,(a+z)/2,radius,d.length,mat,sides=sides);o.rotation_euler=d.to_track_quat('Z','Y').to_euler();return o
    def mesh(self,name,verts,faces,mat=None):
        mesh=bpy.data.meshes.new(self.id+'_'+name);mesh.from_pydata(verts,[],faces);mesh.update()
        o=bpy.data.objects.new(self.id+'_'+name,mesh);return self._keep(o,name,mat)
    def extrude(self,name,points,z0,z1,mat=None):
        n=len(points);vs=[(x,y,z) for z in [z0,z1] for x,y in points]
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        return self.mesh(name,vs,fs,mat)
    def plane(self,name,loc,width,height,mat=None,vertical=False):
        x,y,z=loc
        vs=[(x-width/2,y,z-height/2),(x+width/2,y,z-height/2),(x+width/2,y,z+height/2),(x-width/2,y,z+height/2)] if vertical else [(x-width/2,y-height/2,z),(x+width/2,y-height/2,z),(x+width/2,y+height/2,z),(x-width/2,y+height/2,z)]
        return self.mesh(name,vs,[(0,1,2,3)],mat)

def water(b,part):
    w,d,h=b.size;n=int(b.id[3:]);b.flag('card',True)
    if n==51:b.plane('FlatCanalSurface',(0,0,0),w,d,'FX_Water')
    elif n==52:
        pts=[(-w/2+i*w/12,(-.5 if i%2 else -.25)*d) for i in range(13)]
        pts+=[(w/2-i*w/12,(.5 if i%2 else .25)*d) for i in range(13)]
        b.mesh('SparseFoamEdge',[(x,y,0) for x,y in pts],[tuple(range(len(pts)))],'Foam')
    elif n==53:b.plane('VerticalWaterline',(0,0,h/2),w,h,'Wear_DampLeak',True)
    elif n==54:
        b.box('GutterBase',(0,0,h*.1),(w,d,h*.2),'TX17')
        for y in [-d*.43,d*.43]:b.box('GutterLip',(0,y,h*.5),(w,d*.14,h),'TX17')
    elif n==55:
        spout(b)
    elif n==56:
        vs=[]
        for i in range(7):
            t=i/6;y=-d*.5+d*t;z=h*(1-t)**.7
            vs.extend([(-w*.5,y,z),(w*.5,y,z)])
        b.mesh('BentOutletRibbon',vs,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(6)],'Drip')
    elif n==57:
        for r in [.22,.36,.48]:b.torus('ImpactRing',(0,0,0),w*r,w*.012,'Ripple',major_segments=16)
    elif n==58:
        for i in range(5):
            x=-w*.4+i*w*.2;b.plane('DripFilm',(x,0,h*.5),w*.05,h*(.5+.1*i),'Drip',True)
    elif n==59:
        pts=[(math.cos(i*math.tau/12)*w*.5*(.85+.15*b.rng.random()),math.sin(i*math.tau/12)*d*.5*(.85+.15*b.rng.random()),0) for i in range(12)]
        b.mesh('FlatPuddle',pts,[tuple(range(12))],'Puddle')
    else:raise ValueError(b.id)

def spout(b):
    w,d,h=b.size;vs=[]
    for y in [-d/2,d/2]:
        for radius in [1,.65]:
            vs.extend([(math.cos(i*math.tau/8)*w*.5*radius,y,math.sin(i*math.tau/8)*h*.5*radius+h/2) for i in range(8)])
    fs=[]
    for i in range(8):
        j=(i+1)%8
        fs.extend([(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),(i,i+8,j+8,j),(i+16,j+16,j+24,i+24)])
    b.mesh('HollowOctagonalSpout',vs,fs,'TX17')

def finish(b):
    bpy.ops.object.select_all(action='DESELECT')
    for o in b.objects:
        bpy.context.view_layer.objects.active=o;o.select_set(True)
        for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        o.select_set(False)
    for o in b.objects:o.select_set(True)
    bpy.context.view_layer.objects.active=b.objects[0];bpy.ops.object.join();o=bpy.context.object
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    dims=b.size;coords=[v.co for v in o.data.vertices];low=Vector(tuple(min(v[k] for v in coords) for k in range(3)));high=Vector(tuple(max(v[k] for v in coords) for k in range(3)));extent=high-low
    center_ids={21,22,24,25,27};floor_ids={1,2,13,14,20,51,52,57,59,82,88};n=int(''.join(c for c in b.id if c.isdigit()) or '0')
    declared=b.part.get('production_pivot',b.part.get('pivot'))
    pivot=declared if declared in {'center','top contact','bottom center'} else 'center' if n in center_ids else 'top contact' if n in floor_ids else 'bottom center'
    def fitted_point(point):
        result=[(point[k]-(low[k]+high[k])/2)*(dims[k]/extent[k] if extent[k]>1e-7 else 1) for k in range(3)]
        if pivot=='bottom center':result[2]+=dims[2]/2
        if pivot=='top contact' and extent.z>1e-7:result[2]-=dims[2]/2
        return result
    if b.flags.get('source_sockets_m'):
        b.flags['sockets_m']={key:fitted_point(point) for key,point in b.flags['source_sockets_m'].items()}
    if b.flags.get('socket_centers_m'):
        b.flags['socket_centers_m']=[fitted_point(point) for point in b.flags['socket_centers_m']]
    for v in o.data.vertices:
        for k in range(3):v.co[k]=(v.co[k]-(low[k]+high[k])/2)*(dims[k]/extent[k] if extent[k]>1e-7 else 1)
        if pivot=='bottom center':v.co.z+=dims[2]/2
        if pivot=='top contact' and extent.z>1e-7:v.co.z-=dims[2]/2
    o.data.update()
    bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    uv=o.data.uv_layers.new(name='UVMap') if not o.data.uv_layers else o.data.uv_layers[0]
    uv_lo=[min(v.co[a] for v in o.data.vertices) for a in range(3)]
    uv_hi=[max(v.co[a] for v in o.data.vertices) for a in range(3)]
    cards=bool(b.flags.get('card')) or (b.id.startswith('CCS') and n in [51,52,53,56,57,58,59,64,82,83])
    for f in o.data.polygons:
        axis=max(range(3),key=lambda k:abs(f.normal[k]));axes=[k for k in range(3) if k!=axis]
        m=o.data.materials[f.material_index];key=m.get('catalog_key','TX01');tile=specs.get(key,{}).get('tile_metres',[1,1])
        for li in f.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            if key=='AT01':uv.data[li].uv=m.get('palette_uv',(.5625,.875))
            elif cards:
                # Bottom-contact vertical cards are not centered around Z=0.
                # Project their real bounds so the complete image occupies 0..1.
                uv.data[li].uv=tuple((co[a]-uv_lo[a])/max(uv_hi[a]-uv_lo[a],.000001) for a in axes)
            else:uv.data[li].uv=(co[axes[0]]/tile[0],co[axes[1]]/tile[1])
    for f in o.data.polygons:f.use_smooth=False
    o.name=f"WarrensC_{b.id}_{b.part['name']}_Mars_SM";o.data.name=o.name+'_Mesh'
    o['catalog_id']=b.id;o['collision_policy']='NoCollision visual skin';o['source_brief']=b.part['blender_brief'];o['generator']='ChainCrossingKit procedural family v1'
    for k,v in b.flags.items():o[k]=v
    o.asset_mark();b.col.asset_mark();b.col.use_fake_user=True
    category=b.part.get('category') or ('Architecture' if n<=20 or 43<=n<=50 or n>=86 else 'Mechanisms' if n<=42 else 'Water' if n<=59 else 'Dressing')
    for item in [o,b.col]:
        item.asset_data.catalog_id=CATEGORIES[category]
        item.asset_data.description=b.id+' | '+b.part['name']+' | metres, Z up | visual-only'
        item.asset_data.tags.new(category)
    tris=sum(len(f.vertices)-2 for f in o.data.polygons)
    assert len(o.data.vertices)>=3 and tris>0 and all(math.isfinite(x) for v in o.data.vertices for x in v.co),b.id
    o.data.validate(verbose=False,clean_customdata=False)
    bounds_min=[min(v.co[k] for v in o.data.vertices)*100 for k in range(3)]
    bounds_max=[max(v.co[k] for v in o.data.vertices)*100 for k in range(3)]
    return o,dict(id=b.id,name=o.name,dimensions_cm=[round(x*100,5) for x in dims],actual_dimensions_cm=[round(bounds_max[k]-bounds_min[k],5) for k in range(3)],bounds_min_cm=bounds_min,bounds_max_cm=bounds_max,vertices=len(o.data.vertices),triangles=tris,materials=[m.name for m in o.data.materials],material_keys=[m.get('catalog_key','TX01') for m in o.data.materials],flags=b.flags,pivot=pivot)

def export(o,col):
    bpy.ops.object.select_all(action='DESELECT')
    copy=o.copy();copy.data=o.data.copy();bpy.context.scene.collection.objects.link(copy);copy.name=o.name
    for v in copy.data.vertices:v.co*=100
    copy.select_set(True);bpy.context.view_layer.objects.active=copy
    scale=bpy.context.scene.unit_settings.scale_length;bpy.context.scene.unit_settings.scale_length=.01
    target=OUT/'FBX'/f'{o.name}.fbx'
    bpy.ops.export_scene.fbx(filepath=str(target),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=True,bake_anim=False,path_mode='STRIP',use_custom_props=True)
    bpy.data.objects.remove(copy,do_unlink=True);bpy.context.scene.unit_settings.scale_length=scale
    return str(target.relative_to(OUT))

def instance(scene,col,name,at,scale=(1,1,1),yaw=0,rotation=None):
    o=bpy.data.objects.new(name,None);o.instance_type='COLLECTION';o.instance_collection=col;o.location=at;o.scale=scale;o.rotation_euler=tuple(math.radians(v) for v in (rotation or (0,0,yaw)));scene.collection.objects.link(o);return o

def setup_scene(scene,name,ambient=.45):
    scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.use_denoising=True
    scene.render.resolution_x=1600;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.render.image_settings.file_format='PNG'
    scene.world=bpy.data.worlds.new(name);scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=ambient

def camera(scene,at,target,ortho=None,fov=65):
    data=bpy.data.cameras.new(scene.name+'_Camera');o=bpy.data.objects.new(data.name,data);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO' if ortho else 'PERSP'
    if ortho:data.ortho_scale=ortho
    else:data.angle=math.radians(fov)
    scene.camera=o;return o

def light(scene,name,at,energy,color=(1,1,1),size=5,target=(0,0,0)):
    d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=size
    o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()

def main():
    global OUT,SEED
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true');parser.add_argument('--only');parser.add_argument('--seed',type=int,default=1031);args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    SEED=args.seed
    if args.only:
        requested=set(args.only.split(','));assert requested.issubset({p['id'] for p in parts}),requested
        OUT=HERE/'Output/Subsets'/hashlib.sha256(args.only.encode()).hexdigest()[:10]
    for folder in ['FBX','Previews','Renders','Reports']:(OUT/folder).mkdir(parents=True,exist_ok=True)
    (OUT/'.blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{v}:{k}:{k}' for k,v in CATEGORIES.items())+'\n')
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.name='01_KitLibrary';setup_scene(scene,'NeutralLibrary')
    mats=load_materials();objects={};collections={};report=[]
    modules=[importlib.import_module('generators.'+n) for n in ['architecture','mechanisms','dressing']]
    for part in parts:
        if args.only and part['id'] not in args.only.split(','):continue
        col=bpy.data.collections.new(part['id']+'_'+part['name']);scene.collection.children.link(col);b=Builder(part,mats,col);n=int(part['id'][3:])
        if n<=20 or 43<=n<=50 or n>=86:modules[0].build(b,part)
        elif n<=42:modules[1].build(b,part)
        elif n<=59:spout(b) if n==55 else water(b,part)
        else:modules[2].build(b,part)
        o,row=finish(b);row['fbx']=export(o,col);report.append(row);objects[part['id']]=o;collections[part['id']]=col;scene.collection.children.unlink(col)
        print('ASSET_COMPLETE',part['id'],row['triangles'],flush=True)
    write('asset_manifest.json',{'units':'metres in Blender; explicit centimetre FBX vertices with unit scale .01','catalog_sha256':hashlib.sha256((ART/'sections/chain-crossing-sluice/model_catalog.json').read_bytes()).hexdigest(),'assets':report,'count':len(report)})
    for i,row in enumerate(report):instance(scene,collections[row['id']],row['id']+'_LibraryInstance',((i%11-5)*6,(i//11)*7,0))
    camera(scene,(42,-55,66),(0,23,0),92);light(scene,'LibraryKey',(-15,5,45),35000,size=40,target=(0,22,0));light(scene,'LibraryFill',(25,35,30),22000,size=30,target=(0,22,0))
    # Source-derived shared placement manifest is also consumed by Unreal; diorama is a separate local composition.
    from placement import build_diorama
    diorama=bpy.data.scenes.new('02_ChainCrossingDiorama');setup_scene(diorama,'DioramaWorld',.16)
    placements=build_diorama()
    for i,p in enumerate(placements):
        if p['id'] in collections:instance(diorama,collections[p['id']],p['id']+'_Diorama_'+str(i),p['at'],p.get('scale',(1,1,1)),p.get('yaw',0),p.get('rotation'))
    camera(diorama,(22,-28,23),(5,1,1),43);light(diorama,'WarmKey',(0,-8,15),7500,(1,.66,.35),12,target=(5,1,0));light(diorama,'CoolDepth',(14,10,13),6500,(.32,.55,.70),15,target=(4,1,0))
    for at in [(-13,-.6,2.2),(15,2.5,2.1)]:light(diorama,'LanternStudy',at,100,(1,.45,.13),1,target=(at[0],at[1]+2,0))
    bpy.context.window.scene=scene
    for image in bpy.data.images:
        if image.source=='FILE' and not image.packed_file:image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ChainCrossing_KitLibrary.blend'),compress=True)
    bpy.context.window.scene=diorama;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'ChainCrossing_Diorama.blend'),compress=True)
    write('diorama_instances.json',placements)
    if not args.no_render:
        for sc,name in [(scene,'KIT_LIBRARY'),(diorama,'DIORAMA')]:
            bpy.context.window.scene=sc;sc.render.filepath=str(OUT/'Renders'/f'{name}.png');bpy.ops.render.render(write_still=True)
        preview=bpy.data.scenes.new('03_IndividualAssetReview');setup_scene(preview,'IndividualReview',.6);preview.render.resolution_x=512;preview.render.resolution_y=512;preview.cycles.samples=8
        light(preview,'PreviewKey',(-4,-5,7),600,size=5);light(preview,'PreviewFill',(4,3,5),400,size=4)
        cam=camera(preview,(4,-6,4),(0,0,.5),4)
        bpy.context.window.scene=preview
        for row in report:
            ident=row['id'];o=instance(preview,collections[ident],ident+'_Review',(0,0,0));dims=[x/100 for x in row['dimensions_cm']];z=0 if row['pivot']=='center' else dims[2]/2
            target=Vector((0,0,z));cam.location=target+Vector((4,-6,4))*max(dims)*.8;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(dims)*1.65
            preview.render.filepath=str(OUT/'Previews'/f'{ident}.png');bpy.ops.render.render(write_still=True);bpy.data.objects.remove(o,do_unlink=True)
    print('CHAIN_KIT_BUILD_COMPLETE',len(report),flush=True)

if __name__=='__main__':main()
