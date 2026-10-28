"""Linked-data scene assembly, asset library, comparison diorama and review views."""
import math,json
from pathlib import Path
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent;OUT=HERE/'Output'
OFFSETS={'HS':(-2200,-2200,0),'BW':(1200,-2200,0),'RW':(-2200,1200,0),'HL':(1200,1200,0)}

def scene(name):
    s=bpy.data.scenes.new(name);s.unit_settings.system='METRIC';s.unit_settings.scale_length=1
    s.render.engine='CYCLES';s.cycles.samples=12;s.cycles.use_denoising=True;s.cycles.device='CPU'
    s.render.resolution_x=1200;s.render.resolution_y=1000;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.view_settings.view_transform='AgX'
    s.world=bpy.data.worlds.new(name+'_World');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.07,.11,.16,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    return s

def instance(s,source,row,offset=(0,0,0)):
    o=bpy.data.objects.new(row.get('source_id',row['asset'])+'_'+str(len(s.objects)),source.data)
    x,y,z=[row['at_cm'][i]+offset[i] for i in range(3)];o.location=(x/100,-y/100,z/100);o.rotation_euler.z=-math.radians(row['yaw_deg']);o.scale=row['scale'];o['source_asset']=row['asset'];o['layer']=row['layer'];o['source_id']=row.get('source_id','')
    # Editable collections expose the roof and front shell as independent toggles.
    col=s.collection.children.get(row['layer'])
    if not col:col=bpy.data.collections.new(row['layer']);s.collection.children.link(col)
    col.objects.link(o);return o

def light(s,name,at,power,color=(1,.74,.46),size=8,target=None):
    data=bpy.data.lights.new(name,'AREA' if target else 'POINT');data.energy=power;data.color=color
    if target:data.shape='DISK';data.size=size
    else:data.shadow_soft_size=.25
    o=bpy.data.objects.new(name,data);s.collection.objects.link(o);o.location=at
    if target:o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o

def camera(s,name,at,target,ortho=None):
    data=bpy.data.cameras.new(name);o=bpy.data.objects.new(name,data);s.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    if ortho:data.type='ORTHO';data.ortho_scale=ortho
    else:data.type='PERSP';data.lens=22
    s.camera=o;return o

def label(s,name,text,at,size=.3):
    data=bpy.data.curves.new(name,'FONT');data.body=text;data.size=size;data.align_x='CENTER'
    o=bpy.data.objects.new(name,data);s.collection.objects.link(o);o.location=at
    mat=bpy.data.materials.get('Spire_Label')
    if not mat:mat=bpy.data.materials.new('Spire_Label');mat.diffuse_color=(.8,.68,.4,1)
    data.materials.append(mat);return o

def build_scenes(spec,manifest,objects,mats,args):
    source=bpy.context.scene;made={};rows={r['id']:r for r in manifest['assets']}
    for c in spec['concepts']:
        cid=c['id'];R=c['geometry']['shaft_outer_radius_cm'];s=scene('Spire_'+cid);made[cid]=s
        for p in manifest['assemblies'][cid]:instance(s,objects[p['asset']],p)
        for p in c['prop_instances']:
            if p['asset']=='P08':
                x,y,z=p['local_origin_cm'];a=math.radians(p['yaw_outward_deg']);light(s,'Lantern_'+p['id'],((x-12*math.cos(a))/100,-(y-12*math.sin(a))/100,(z+21)/100),75)
        target=(R/100,0,-5)
        light(s,cid+'_Key',(-10,-17,12),18000,(1,.74,.5),14,target)
        light(s,cid+'_Cool',(18,12,4),14000,(.28,.55,1),14,target)
        camera(s,'Overview',(-14,-23,13),target,25)
        camera(s,'Entry',(-.8,.1,1.65),(4,-2,-1))
        camera(s,'Return',((2*R+220)/100,0,-10.35),(R/100,0,-6))
        s.camera=s.objects['Overview'] if 'Overview' in s.objects else next(o for o in s.objects if o.type=='CAMERA' and o.name.startswith('Overview'))
    library=scene('Spire_KitLibrary');made['KitLibrary']=library
    # The library presents actual size1:1. Datum offsets recenter previews only.
    cols=10
    for i,row in enumerate(manifest['assets']):
        lo,hi=row['bounds_min_cm'],row['bounds_max_cm'];x=(i%cols)*900;y=(i//cols)*900
        pos=(x-(lo[0]+hi[0])/2,y-(lo[1]+hi[1])/2,-lo[2])
        instance(library,objects[row['id']],dict(asset=row['id'],at_cm=pos,yaw_deg=0,scale=[1,1,1],layer=row['category']))
        label(library,'Label_'+row['id'],row['id'],(x/100,-y/100-4.2,.03),.3)
    height=math.ceil(len(rows)/cols)*9;camera(library,'LibraryCamera',(40,-(height-9)*.5,100),(40,-(height-9)*.5,0),max(110,(height+10)*1.2))
    light(library,'LibraryKey',(25,-height/2,55),180000,(1,.86,.66),90,(40,-height/2,0));light(library,'LibraryFill',(80,-height/2,35),90000,(.5,.7,1),80,(40,-height/2,0))
    dio=scene('Spire_Diorama');made['Diorama']=dio;dio.render.resolution_x=1600;dio.render.resolution_y=1200
    for c in spec['concepts']:
        cid=c['id'];offset=OFFSETS[cid];R=c['geometry']['shaft_outer_radius_cm']
        for p in manifest['assemblies'][cid]:
            if p['layer'] in ['Roof','ShellFront']:continue
            instance(dio,objects[p['asset']],p,offset)
        p=dict(asset='ReviewPlinth',at_cm=[offset[0]+R+150,offset[1],-1240],yaw_deg=0,scale=[(2*R+600)/100,(2*R+400)/100,1],layer='Plinth')
        instance(dio,objects['ReviewPlinth'],p)
        label(dio,cid+'_Name',c['name'],((offset[0]+R)/100,-(offset[1]-R-120)/100,-12.35),.6)
        light(dio,cid+'_Warm',((offset[0]+R-300)/100,-(offset[1]+300)/100,1),300,(1,.62,.25))
    light(dio,'StudioKey',(-25,-55,38),140000,(1,.78,.53),35,(0,0,-5));light(dio,'StudioFill',(45,20,25),100000,(.28,.55,1),35,(0,0,-5));camera(dio,'DioramaCamera',(-46,-63,45),(2,2,-5),78)
    # Source scenes stay fully assembled. Cutaways are review-only visibility.
    for key,s in made.items():
        bpy.context.window.scene=s
        for o in s.objects:
            if o.type=='CAMERA' and (o.name.startswith('Overview') if key in ['HS','BW','RW','HL'] else True):s.camera=o;break
        path=OUT/'Blender'/('Spire_'+key+'.blend');bpy.ops.wm.save_as_mainfile(filepath=str(path),copy=True)
    cats=['Architecture','Props','Hero','Supports','Collision','Presentation']
    import uuid
    catalog='VERSION 1\n\n'+'\n'.join(f'{uuid.uuid5(uuid.NAMESPACE_URL,"SpireConnectorKit/"+x)}:Spire/{x}:{x}' for x in cats)+'\n'
    library_dir=OUT/'AssetLibrary';library_dir.mkdir(exist_ok=True)
    (library_dir/'blender_assets.cats.txt').write_text(catalog)
    bpy.context.window.scene=library;bpy.ops.wm.save_as_mainfile(filepath=str(library_dir/'Spire_Assets.blend'),copy=True)
    report={key:{'scene':s.name,'objects':len(s.objects),'mesh_instances':sum(o.type=='MESH' for o in s.objects),'unique_meshes':len({o.data.name for o in s.objects if o.type=='MESH'})} for key,s in made.items()}
    (OUT/'Reports/blender_scenes.json').write_text(json.dumps(report,indent=2))
    if not args.no_render:
        for key in made:render_scene(made[key],key)

def render_scene(s,key):
    bpy.context.window.scene=s
    hidden=[]
    for o in s.objects:
        if o.get('layer') in ['Roof','ShellFront']:
            hidden.append((o,o.hide_render));o.hide_render=True
    try:
        s.render.filepath=str(OUT/'Renders'/(key+'_Overview.png'));bpy.ops.render.render(write_still=True)
    finally:
        for o,state in hidden:o.hide_render=state
