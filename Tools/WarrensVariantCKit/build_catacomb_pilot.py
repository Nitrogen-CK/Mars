"""Headless, derived-only complete-room pilot with source-supported broad stones."""
import argparse,hashlib,importlib.util,json,math,random,re,sys
from collections import defaultdict
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
PREFIX='CatacombPilot_R02_'
PIGMENT={'walls':dict(repeat=1.8,mix=.85,base=(.18,.16,.12,1)),
         'floor':dict(repeat=1.0,mix=.70,base=(.20,.17,.12,1)),
         'ceiling':dict(repeat=1.0,mix=.25,base=(.14,.125,.10,1)),
         'prop':dict(repeat=.65,mix=.45,base=(.20,.18,.14,1))}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def module(name,p):
    s=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def intersection(a,b):
    r=[max(a[0],b[0]),max(a[1],b[1]),min(a[2],b[2]),min(a[3],b[3])]
    return r if r[2]-r[0]>1e-7 and r[3]-r[1]>1e-7 else None
def main():
    import bpy,bmesh
    from mathutils import Vector,Matrix
    p=argparse.ArgumentParser();p.add_argument('--manifest',required=True);p.add_argument('--output',required=True)
    p.add_argument('--stages',nargs='+',default=['A_source_reconstructed','B_broad_courses_neutral','C_angular_pigment_neutral','D_local_warm_lights'])
    a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);mp=(ROOT/a.manifest).resolve();out=(ROOT/a.output).resolve()
    assert mp.is_relative_to(DOC.resolve()) and out.is_relative_to(DOC.resolve()) and not out.exists()
    source=HERE/'Output/WarrensVariantC_Diorama.blend';assert Path(bpy.data.filepath).resolve()==source.resolve()
    guard=read(ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/baseline_guard_r02.json')
    guards=guard['immutable_guards']|guard['collision_hashes']
    assert all(sha(ROOT/k)==v for k,v in guards.items())
    m=read(mp);assert all(sha(ROOT/k)==v for k,v in m['inputs'].items())
    guards.update(m['inputs']);guards[mp.relative_to(ROOT).as_posix()]=sha(mp)
    imgpath=DOC/'Stone_AngularPigment_Albedo_r02.png';guards[imgpath.relative_to(ROOT).as_posix()]=sha(imgpath)
    sync=module('_pilot_sync',HERE/'sync_art_libraries.py');assert sha(HERE/'sync_art_libraries.py')=='5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6'
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene;bpy.context.view_layer.update()
    oldposes={o.name:[list(v) for v in o.matrix_world] for o in scene.objects}
    oldgraphs={v.name:sync.stable(sync.nodes(v.node_tree)) for v in bpy.data.materials if v.use_nodes}
    oldmeshes={v.name:sync.mesh_hash(v) for v in bpy.data.meshes}
    fit=read(HERE/'Output/fitted_instances.json')['placements']
    byname={re.sub(r'\.\d{3}$','',o.name):o for o in scene.objects if o.instance_type=='COLLECTION'}
    aliases={o.name.removesuffix('_Library'):o.instance_collection for o in bpy.data.scenes['01_VariantCLibrary'].objects if o.instance_type=='COLLECTION'}
    aliases['BACKING_TX01']=byname['BACKING_TX01_Assembly_29435'].instance_collection
    stone_old=aliases['BACKING_TX01'].objects[0].material_slots[0].material
    neutral=bpy.data.materials.new(PREFIX+'NeutralStone');neutral.diffuse_color=(.28,.265,.225,1);neutral.use_nodes=True
    neutral.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.28,.265,.225,1)
    neutral.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.9
    mortar=neutral.copy();mortar.name=PREFIX+'QuietMortar';mortar.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.12,.105,.08,1)
    image=bpy.data.images.load(str(imgpath),check_existing=False);image.colorspace_settings.name='sRGB';image.pack()
    paint={}
    for family in ('walls','floor','ceiling','prop'):
        mat=neutral.copy();mat.name=PREFIX+'Paint_'+family;t=mat.node_tree;bs=t.nodes.get('Principled BSDF')
        tex=t.nodes.new('ShaderNodeTexImage');tex.image=image;tex.extension='REPEAT'
        if family=='prop':
            geom=t.nodes.new('ShaderNodeNewGeometry');scale=t.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=1/PIGMENT[family]['repeat']
            t.links.new(geom.outputs['Position'],scale.inputs[0]);t.links.new(scale.outputs[0],tex.inputs[0]);tex.projection='BOX';tex.projection_blend=.1
        else:
            uv=t.nodes.new('ShaderNodeUVMap');uv.uv_map='PigmentUV';t.links.new(uv.outputs[0],tex.inputs[0])
        pigment=t.nodes.new('ShaderNodeMixRGB');pigment.inputs[0].default_value=PIGMENT[family]['mix'];pigment.inputs[1].default_value=PIGMENT[family]['base'];t.links.new(tex.outputs['Color'],pigment.inputs[2])
        mul=t.nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=1
        t.links.new(pigment.outputs[0],mul.inputs[1])
        if family!='prop':
            vc=t.nodes.new('ShaderNodeVertexColor');vc.layer_name='StoneTint';t.links.new(vc.outputs['Color'],mul.inputs[2])
        else:mul.inputs[2].default_value=(.95,.92,.86,1)
        t.links.new(mul.outputs[0],bs.inputs['Base Color']);bs.inputs['Roughness'].default_value=.92 if family=='ceiling' else .88
        paint[family]=mat
    # Source ceiling aliases and exact original native solids reconstruct the
    # baseline. The old cutaway omitted both ceilings and Main's shared walls.
    ceiling_col=aliases['CCS13'].copy();ceiling_col.name=PREFIX+'OriginalCeiling'
    for v in list(ceiling_col.objects):ceiling_col.objects.unlink(v)
    for old in aliases['CCS13'].objects:
        part=old.copy();part.data=old.data;ceiling_col.objects.link(part)
        for s in part.material_slots:s.link='OBJECT';s.material=stone_old
    restored=[]
    for i,row in enumerate(fit):
        if row['tile']=='Catacomb' and 'ceiling'in row['role']:
            col=ceiling_col if row['id']=='CCS13_TX01' else aliases[row['id']]
            o=sync.add_instance(scene,col,PREFIX+'CeilingContext_'+str(i),row,str(i));restored.append(o);byname[row['id']+'_Assembly_'+str(i)]=o
    cube=aliases['BACKING_TX01'].objects[0].data
    solid_objects=[]
    for box in m['source_boxes']:
        # All source solid dimensions/poses are retained, without modifiers.
        o=bpy.data.objects.new(PREFIX+'Source_'+box['key'].replace(':','_'),cube);scene.collection.objects.link(o)
        at=[(x+y)/2 for x,y in zip(box['lo'],box['hi'])];o.location=(at[0]-58,55-at[1],at[2]);o.scale=[b-a for a,b in zip(box['lo'],box['hi'])]
        for s in o.material_slots:s.link='OBJECT';s.material=neutral
        solid_objects.append(o)
    new=[];geometry_records=[]
    def build_family(family,groups,width,height,front,back):
        bm=bmesh.new();uv=bm.loops.layers.uv.new('PigmentUV');color=bm.loops.layers.float_color.new('StoneTint')
        def position(u,v,depth,axis,sign,plane):
            if family in ('floor','ceiling'):return (u-58,55-v,plane+sign*depth)
            p=[0,0,v];p[axis]=plane+sign*depth;p[1-axis]=u;return(p[0]-58,55-p[1],p[2])
        stone_count=0
        for groupindex,g in enumerate(groups):
            axis,sign,plane,regions=g['axis'],g['sign'],g['plane'],g['rects']
            lo=[min(r[i] for r in regions) for i in (0,1)];hi=[max(r[i] for r in regions) for i in (2,3)]
            for iy in range(math.floor(lo[1]/height),math.ceil(hi[1]/height)):
                offset=(iy%2)*width*.5 if family=='walls' else 0
                for ix in range(math.floor((lo[0]-offset)/width),math.ceil((hi[0]-offset)/width)):
                    gap=.012;cell=[ix*width+offset+gap/2,iy*height+gap/2,(ix+1)*width+offset-gap/2,(iy+1)*height-gap/2]
                    pieces=[v for r in regions if (v:=intersection(r,cell))]
                    if not pieces:continue
                    sb=bmesh.new();sourcefaces=[]
                    for r in pieces:
                        vs=[sb.verts.new((r[0],r[1],0)),sb.verts.new((r[2],r[1],0)),sb.verts.new((r[2],r[3],0)),sb.verts.new((r[0],r[3],0))]
                        sourcefaces.append(sb.faces.new(vs))
                    bmesh.ops.remove_doubles(sb,verts=list(sb.verts),dist=1e-6)
                    bmesh.ops.dissolve_limit(sb,angle_limit=.001,verts=list(sb.verts),edges=list(sb.edges),use_dissolve_boundaries=False)
                    rng=random.Random(f'{family}/{groupindex}/{ix}/{iy}');tone=rng.uniform(.80,1.12)*(.73 if family=='ceiling' else 1)
                    tint=(tone*rng.uniform(.97,1.03),tone*rng.uniform(.96,1.02),tone*rng.uniform(.95,1.02),1)
                    phase=(rng.uniform(0,8),rng.uniform(0,8));rot=rng.randrange(4)
                    for sf in list(sb.faces):
                        # Stone extrusion is shallow and stays within declared
                        # clearance bounds. The underlying flat mortar masks old
                        # compressed joints without changing collision geometry.
                        coords=[tuple(v.co[:2]) for v in sf.verts]
                        verts0=[bm.verts.new(position(u,v,back,axis,sign,plane)) for u,v in coords]
                        verts1=[bm.verts.new(position(u,v,front,axis,sign,plane)) for u,v in coords]
                        faces=[]
                        for vs in (list(reversed(verts0)),verts1):faces.append(bm.faces.new(vs))
                        for j in range(len(coords)):faces.append(bm.faces.new((verts0[j],verts0[(j+1)%len(coords)],verts1[(j+1)%len(coords)],verts1[j])))
                        for face in faces:
                            for loop in face.loops:
                                co=loop.vert.co
                                if family in ('floor','ceiling'):u,v=co.x+58,55-co.y
                                else:u,v=(55-co.y if axis==0 else co.x+58),co.z
                                for _ in range(rot):u,v=-v,u
                                loop[uv].uv=((u+phase[0])/PIGMENT[family]['repeat'],(v+phase[1])/PIGMENT[family]['repeat']);loop[color]=tint
                        stone_count+=1
                    sb.free()
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        # Geometric chamfers follow the physical stone faces, not raster cells.
        bevel=bmesh.ops.bevel(bm,geom=list(bm.edges),offset=.0018 if family!='walls' else .0025,segments=1,affect='EDGES',clamp_overlap=True)
        mesh=bpy.data.meshes.new(PREFIX+family+'_Mesh');bm.to_mesh(mesh);bm.free();mesh.update()
        obj=bpy.data.objects.new(PREFIX+family,mesh);scene.collection.objects.link(obj);obj.data.materials.append(neutral)
        obj['collision_policy']='NoCollision';obj['source_manifest']=mp.relative_to(ROOT).as_posix();obj['stone_size_m']=[width,height]
        new.append(obj);geometry_records.append(dict(name=obj.name,kind=family,stone_count=stone_count,vertices=len(mesh.vertices),polygons=len(mesh.polygons),source_groups=groups,mesh_inventory=sync.mesh_hash(mesh)))
        # Flat continuous backing sits beyond old visual skins, below the new
        # blocks. This prevents the old squeezed joints showing in new mortar.
        verts=[];faces=[]
        for g in groups:
            for r in g['rects']:
                n=len(verts);quad=[position(u,v,back+.0001,g['axis'],g['sign'],g['plane']) for u,v in ((r[0],r[1]),(r[2],r[1]),(r[2],r[3]),(r[0],r[3]))];verts+=quad
                normal=(Vector(quad[1])-Vector(quad[0])).cross(Vector(quad[2])-Vector(quad[0]))
                expected=Vector((0,0,g['sign'])) if family in ('floor','ceiling') else (Vector((g['sign'],0,0)) if g['axis']==0 else Vector((0,-g['sign'],0)))
                faces.append((n,n+1,n+2,n+3) if normal.dot(expected)>0 else (n+3,n+2,n+1,n))
        data=bpy.data.meshes.new(PREFIX+family+'_BackingMesh');data.from_pydata(verts,[],faces);data.update()
        obj=bpy.data.objects.new(PREFIX+family+'_Backing',data);scene.collection.objects.link(obj);data.materials.append(mortar);new.append(obj)
    wg=defaultdict(list)
    for f in m['wall_faces']:wg[f['axis'],f['normal_sign'],f['plane']].append([*f['tangent_bounds'][:1],f['z_bounds'][0],f['tangent_bounds'][1],f['z_bounds'][1]])
    groups=[dict(axis=a,sign=s,plane=p,rects=rs) for(a,s,p),rs in wg.items()]
    build_family('walls',groups,.9,.5,.018,.013)
    build_family('floor',[dict(axis=2,sign=1,plane=0,rects=[c['rect'] for c in m['admitted_floor_cells']])],1.0,.8,.012,.009)
    cg=defaultdict(list)
    for c in m['ceiling_faces']:cg[c['z']].append(c['rect'])
    build_family('ceiling',[dict(axis=2,sign=-1,plane=z,rects=rs) for z,rs in cg.items()],1.2,.9,.018,.013)
    oldtargets=[byname[fit[i]['id']+'_Assembly_'+str(i)] for i in m['superseded_fit_keys']]
    props=[byname[fit[i]['id']+'_Assembly_'+str(i)] for i in (36578,36579)]
    prop_original={o.name:o.instance_collection for o in props}
    prop_copies={}
    for o in props:
        col=o.instance_collection.copy();col.name=PREFIX+o.name
        for v in list(col.objects):col.objects.unlink(v)
        for old in o.instance_collection.objects:
            v=old.copy();v.data=old.data;col.objects.link(v)
            for slot in v.material_slots:
                if slot.material and slot.material.get('catalog_key')=='TX01':slot.link='OBJECT';slot.material=paint['prop']
        prop_copies[o.name]=col
    # The new rear practicals reuse the existing fixture kit and attach only to
    # measured source faces. Their transforms are explicit art delta records.
    fixtures=[]
    for label,at,yaw in [('west',[-24,79,0],-90),('rear',[-19,85,0],180)]:
        for key in (37377,37378,37379,37380):
            row=dict(fit[key]);row['at']=list(row['at']);row['at'][0]=at[0]+(.02 if key==37377 else .14) if yaw==-90 else at[0];row['at'][1]=at[1] if yaw==-90 else at[1]-(.02 if key==37377 else .14);row['yaw']=yaw
            obj=sync.add_instance(scene,aliases[row['id']],PREFIX+'Fixture_'+label+'_'+row['id'],row,label+'_'+row['id']);fixtures.append(dict(row=row,object=obj))
    cameras=[]
    records=read(ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-slate-painterly-r02/dark_slate_views_r01.json')
    record=next(r for r in records['views'] if r['id']=='catacomb_standing')['camera_record']
    for label,eye,target in [('standing',None,None),('ceiling',[-22,74,1.6],[-17,80,3.45]),('reverse',[-14,84,1.6],[-22,73,1.5]),('tomb',[-19.2,78.5,1.6],[-18,80,.65])]:
        d=bpy.data.cameras.new(PREFIX+label);d.lens=28;d.sensor_width=36;d.clip_start=.05;d.clip_end=180;o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o)
        if eye is None:o.matrix_world=Matrix(record['camera_matrix'])
        else:
            o.location=(eye[0]-58,55-eye[1],eye[2]);t=Vector((target[0]-58,55-target[1],target[2]));o.rotation_euler=(t-o.location).to_track_quat('-Z','Y').to_euler()
        cameras.append((label,o))
    lights=[]
    def light(name,typ,at,power,color,size,target=None,group='neutral'):
        d=bpy.data.lights.new(PREFIX+name,typ);d.energy=power;d.color=color
        if typ=='AREA':d.shape='DISK';d.size=size
        else:d.shadow_soft_size=size
        o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=(at[0]-58,55-at[1],at[2])
        if target:o.rotation_euler=(Vector((target[0]-58,55-target[1],target[2]))-o.location).to_track_quat('-Z','Y').to_euler()
        lights.append(dict(object=o,group=group,at_plan=at,energy=power,color=color,size=size,type=typ))
    light('NeutralKey','AREA',[-20,75,2.6],650,(1,1,1),4,[-14,82,1.5])
    light('NeutralFill','POINT',[-10,77,1.7],100,(1,1,1),3)
    light('NeutralCeiling','AREA',[-16,80,.8],140,(1,1,1),6,[-16,80,3.5])
    for label,at,power in [('West',[-23.75,79,1.7],260),('Rear',[-19,84.75,1.7],260),('Entry',[-23.75,70,1.7],170),('North',[-15.25,64.75,1.7],170)]:light('Warm'+label,'POINT',at,power,(1,.56,.22),.22,group='warm')
    light('WarmBounce','POINT',[-16,78,2.6],85,(.6,.64,.72),3,group='warm')
    light('WarmCeilingBounce','AREA',[-18,80,.7],35,(1,.68,.38),6,[-18,80,3.5],group='warm')
    light('PlayerLanternReviewProxy','POINT',[-22,74,1.0],180,(1,.62,.26),.15,group='warm')
    player_lantern=lights[-1]['object']
    scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1250;scene.render.resolution_y=813;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG'
    scene.eevee.taa_render_samples=256;scene.eevee.shadow_ray_count=4;scene.eevee.shadow_step_count=12
    out.mkdir(parents=True);frames=[]
    stages=a.stages
    assert all(s in ['A_source_reconstructed','B_broad_courses_neutral','C_angular_pigment_neutral','D_local_warm_lights'] for s in stages)
    for stage in stages:
        new_visible=stage!='A_source_reconstructed';painted=stage.startswith(('C','D'));warm=stage.startswith('D')
        for o in new:o.hide_render=not new_visible
        for rec in fixtures:rec['object'].hide_render=not new_visible
        for o in oldtargets:o.hide_render=new_visible
        for o in props:o.instance_collection=prop_copies[o.name] if painted else prop_original[o.name]
        for o in new:
            family=next((k for k in paint if o.name==PREFIX+k),None)
            if family:o.data.materials[0]=paint[family] if painted else neutral
        for l in lights:l['object'].hide_render=(l['group']=='warm')!=warm
        for label,camera in cameras:
            player_lantern.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)))
            scene.camera=camera;bpy.context.view_layer.update();path=out/(stage+'_'+label+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            frames.append(dict(stage=stage,view=label,file=path.name,sha256=sha(path),camera_matrix=[list(v) for v in camera.matrix_world],review_player_lantern_at=list(player_lantern.location) if warm else None));print('PILOT_FRAME',path.name,flush=True)
    assert all([list(v) for v in scene.objects[k].matrix_world]==v for k,v in oldposes.items())
    assert all(sync.stable(sync.nodes(bpy.data.materials[k].node_tree))==v for k,v in oldgraphs.items())
    assert all(sync.mesh_hash(bpy.data.meshes[k])==v for k,v in oldmeshes.items())
    for record in geometry_records:record['mesh_inventory']=sync.mesh_hash(bpy.data.objects[record['name']].data)
    assert all(sha(ROOT/k)==v for k,v in guards.items())
    derived=out/'CatacombPilot_R02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True,relative_remap=False)
    assert all(sha(ROOT/k)==v for k,v in guards.items())
    result=dict(status='DERIVED_ROOM_PILOT_REVIEW_REQUIRED',manifest_sha256=sha(mp),tool_sha256=sha(__file__),guards=guards,
        source_sha256=sha(source),original_meshes_unchanged=len(oldmeshes),original_materials_unchanged=len(oldgraphs),original_poses_unchanged=len(oldposes),
        added_source_solids=[dict(name=o.name,matrix=[list(v) for v in o.matrix_world]) for o in solid_objects],
        restored_ceiling_count=len(restored),new_geometry=geometry_records,new_objects=[o.name for o in new],
        fixture_art_delta=[r['row'] for r in fixtures],suppressed_original_fit_keys=m['superseded_fit_keys'],
        lights=[{k:v for k,v in l.items() if k!='object'}|dict(name=l['object'].name) for l in lights],
        frames=frames,derived_sha256=sha(derived),pigment_settings=PIGMENT,render_samples=256,shadow_ray_count=4,material_policy='New crisp albedo with per-family hierarchy and per-stone tint/UV phase; roughness constant.88/.92, no fabricated normal/AO. Geometry normals only. Camera-relative lantern is an offline proxy, not actual native lantern proof.',
        clearance_delta_metres=dict(wall_max_projection=.018,wall_original=.012,floor_top=.012,floor_original=.008,ceiling_intrusion=.018,ceiling_original=.012),
        boundary='Offline review only. Actual native player-camera and traversal acceptance still required; no original file or Unreal asset changed.')
    (out/'receipt.json').write_text(json.dumps(result,indent=2)+'\n');print('PILOT_DONE',sha(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
