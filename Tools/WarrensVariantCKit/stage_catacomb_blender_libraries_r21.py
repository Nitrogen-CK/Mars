"""Derived-only library candidates. Originals and all unrelated art remain guarded."""
import argparse
from array import array
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
OUT=DOC.parent/'catacomb-library-sync-r21'
OWNER='Mars.WarrensVariantC.Catacomb.LibrarySync.R21';P='CP21_'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def module(name):
    path=HERE/(name+'.py');s=importlib.util.spec_from_file_location('_cp21_'+name,path);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def guards():
    p=RUN/'baseline_guard_after_source_room_r19.json';assert sha(p)=='16ffda7943311dc84077c39a3c3905c3c13e5806d4579b4c1e7dd2919471aa72'
    g=read(p);all_files=g['immutable_guards']|g['collision_hashes'];assert len(all_files)==651 and all(sha(ROOT/k)==v for k,v in all_files.items())
    assert all(sha(ROOT/k)==v for k,v in g['post_test_provenance']['source_sha256'].items())
    a=read(RUN/'candidate_assets_timber_r13.json');assert len(a['assets'])==39 and all(sha(ROOT/('Content/'+k.removeprefix('/Game/')+'.uasset'))==v['package_sha256'] for k,v in a['assets'].items())
def colour_attributes(mesh):
    rows={}
    for a in mesh.color_attributes:
        values=array('f',[0])*(len(a.data)*4);a.data.foreach_get('color',values);rows[a.name]=dict(type=a.data_type,domain=a.domain,sha256=hashlib.sha256(values.tobytes()).hexdigest())
    return rows
def snapshot(sync):
    import bpy
    data=sync.stable(sync.inventory());data['images']={k:v for k,v in data['images'].items() if bpy.data.images[k].source=='FILE'}
    for name,row in data['meshes'].items():row['colours']=colour_attributes(bpy.data.meshes[name])
    return data
def assert_originals(before,after,allowed_refs):
    for key in ('meshes','materials','images','lights','cameras','worlds'):
        for name,row in before[key].items():assert row==after[key][name],('Original datablock changed',key,name)
    for name,row in before['objects'].items():
        expected=copy.deepcopy(row)
        if name in allowed_refs:expected['instance']=allowed_refs[name]
        assert expected==after['objects'][name],('Original object changed',name)
    for name,row in before['collections'].items():assert row==after['collections'][name],('Original collection changed',name)
    for name,row in before['scenes'].items():
        new=copy.deepcopy(after['scenes'][name]);extra=set(new['objects'])-set(row['objects']);assert not set(row['objects'])-set(new['objects'])
        assert not extra or name in ('01_VariantCLibrary','02_VariantC_Cutaway','Zone_Catacomb')
        assert all(v.startswith(P) for v in extra);new['objects']=row['objects'];assert new==row,('Original scene settings changed',name)
    assert before['active_scene']==after['active_scene']
def main():
    import bpy,bmesh
    from mathutils import Quaternion,Vector
    parser=argparse.ArgumentParser();parser.add_argument('--target',required=True,choices=('Diorama','KitLibrary'));args=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);target=args.target
    original=HERE/'Output'/('WarrensVariantC_'+target+'.blend');assert Path(bpy.data.filepath).resolve()==original.resolve();guards()
    selection=read(DOC/'LIBRARY_SELECTION_R21.json');assert sha(DOC/'LIBRARY_SELECTION_R21.json')=='7b8f90006ec304be2481ccefb5659bcb0d455b6f260371ef023622ce65283ce3'
    for path,value in selection['inputs'].items():assert sha(ROOT/path)==value
    sync=module('sync_art_libraries');mat=module('catacomb_blender_materials_r21');assert sha(HERE/'catacomb_blender_materials_r21.py')=='86dfd1be765c4806f78e8f0bed32ae164989f501c69cc22f76c5698fe2193ab8'
    before=snapshot(sync);active=bpy.context.window.scene;names={kind:set(getattr(bpy.data,kind).keys()) for kind in ('meshes','materials','images')}
    folder=OUT/target;folder.mkdir(parents=True,exist_ok=False);(folder/'before.json').write_text(json.dumps(before,indent=2)+'\n')
    asset_source=DOC.parent/'catacomb-forage-props-r04/Catacomb_ForageProps_Source_R01.blend';assert sha(asset_source)==read(RUN/'library_inventory_r17/ForageSource.json')['sha256']
    # Exact source names differ for the clipped horizontal families.
    mesh_names=['CatacombPilot_R02_walls_Mesh','CatacombPilot_R02_walls_BackingMesh','CatacombPilot_R02_floor_SourceClippedMesh','CatacombPilot_R02_floor_BackingMesh','CatacombPilot_R02_ceiling_SourceClippedMesh','CatacombPilot_R02_ceiling_BackingMesh']
    forage_names=['WVC_Forage_'+r+'_R01_SM_Mesh' for r in ('CenserBob','Chain','PepperContents','Fig','Bellnut')]
    with bpy.data.libraries.load(str(asset_source),link=False) as (source,data):
        assert all(n in source.meshes for n in mesh_names+forage_names);data.meshes=mesh_names+forage_names;data.materials=['CatacombPilot_R02_Paint_prop']
    meshes={name:obj for name,obj in zip(mesh_names+forage_names,data.meshes)}
    pigment=next(i for i in bpy.data.images if i.name not in names['images'] and 'Stone_AngularPigment_Albedo_r02' in i.name)
    bone_normal=bpy.data.images['TX06_BoneIvory_NormalGL.png'];assert bone_normal.colorspace_settings.name=='Non-Color'
    materials={'Post':mat.timber('Post'),'Arm':mat.timber('Arm'),'Bone':mat.ivory('Bone',pigment,bone_normal),'Urn':mat.ivory('Urn',pigment,bone_normal),'Fruit':mat.vertex_colour('Fruit'),'Bronze':mat.vertex_colour('Bronze'),'Stone':data.materials[0]}
    for name,mesh in meshes.items():
        if name in forage_names:
            material=materials['Fruit' if any(k in name for k in ('Fig_','Bellnut_','PepperContents_')) else 'Bronze'];assert len(mesh.uv_layers)==1;mesh.materials[0]=material
    for kind in ('meshes','materials','images'):
        for block in list(getattr(bpy.data,kind)):
            if block.name not in names[kind] and not block.name.startswith(P):block.name=P+block.name
    new_objects=[]
    def collection(name):
        c=bpy.data.collections.new(P+name);c['Owner']=OWNER;return c
    def obj(name,mesh,col):
        o=bpy.data.objects.new(P+name,mesh);col.objects.link(o);o['Owner']=OWNER;new_objects.append(o);return o
    def empty(name,col,at,scale=(1,1,1)):
        o=bpy.data.objects.new(P+name,None);o.instance_type='COLLECTION';o.instance_collection=col;o.location=at;o.scale=scale;o['Owner']=OWNER;new_objects.append(o);return o
    cube=bpy.data.meshes.new(P+'UnitCube');bm=bmesh.new();bmesh.ops.create_cube(bm,size=1);bm.to_mesh(cube);bm.free();uv=cube.uv_layers.new(name='UVMap')
    for poly in cube.polygons:
        for li,co in zip(poly.loop_indices,((0,0),(1,0),(1,1),(0,1))):uv.data[li].uv=co
    cube.materials.append(materials['Stone']);assert min(v.co.x for v in cube.vertices)==-.5 and max(v.co.x for v in cube.vertices)==.5
    assemblies={};parts_module=module('catacomb_fixture_execution_r14')
    assert sha(HERE/'catacomb_fixture_execution_r14.py')=='f138dfc5fb8a0a06907f2ad222710cb4fd844ecad149c158e3821d03f6c0a556'
    for role in ('Fig','Censer','Bellnut'):
        c=collection('Forage_'+role);assemblies[role]=c
        for index,row in enumerate(parts_module.expected_parts(role)):
            if row['mesh']=='/Engine/BasicShapes/Cube':mesh=cube;material=materials['Post' if 'TimberPost' in row['material'] else 'Arm' if 'TimberArm' in row['material'] else 'Stone']
            else:
                key=row['mesh'].rsplit('/',1)[1]+'_Mesh';mesh=meshes[key];material=mesh.materials[0]
            o=obj(role+'_Part_'+str(index),mesh,c);o.location=((row['at'][0]+9600)/100,-(row['at'][1]-1900)/100,row['at'][2]/100);o.scale=row['scale']
            o.material_slots[0].link='OBJECT';o.material_slots[0].material=material
    prop_collections={};allowed_refs={}
    for split in selection['diorama_splits']:
        old=bpy.data.collections[split['blender_witnesses'][target+'/02_VariantC_Cutaway']['collection']];assert not old.children
        c=collection('Prop_'+split['ident']);c.instance_offset=old.instance_offset.copy();prop_collections[split['ident']]=c
        for old_obj in old.objects:
            o=old_obj.copy();o.name=P+split['ident']+'_'+old_obj.name;c.objects.link(o);new_objects.append(o);o['Owner']=OWNER
            if o.type=='MESH':
                if split['ident'] in ('WVC052','WVC053'):assert [v.name for v in o.data.uv_layers]==['UVMap']
                o.material_slots[0].link='OBJECT';o.material_slots[0].material=materials['Bone' if split['ident']=='WVC052' else 'Urn' if split['ident']=='WVC053' else 'Stone']
        for scene in ('02_VariantC_Cutaway','Zone_Catacomb'):
            name=split['blender_witnesses'][target+'/'+scene]['object'];bpy.data.objects[name].instance_collection=c;allowed_refs[name]=c.name
    wallfloor=collection('Room_WallsFloor');ceiling=collection('Room_Ceiling')
    for family in ('walls','floor','ceiling'):
        for name in [n for n in mesh_names if '_'+family+'_' in n]:obj(family+'_'+name,meshes[name],ceiling if family=='ceiling' else wallfloor)
    fixtures=collection('NewPracticalFixtures');fit=read(HERE/'Output/fitted_instances.json');aliases={o.name.removesuffix('_Library'):o.instance_collection for o in bpy.data.scenes['01_VariantCLibrary'].objects if o.instance_type=='COLLECTION'}
    for group in selection['fixture_appends']:
        ident=next(k for k in ('CCS60','CCS61','CCS62','CCS64') if '_'+k+'_' in group['mesh'])
        for i,pose in enumerate(group['add_local_poses']):
            xyz=[v+d for v,d in zip(pose['at'],selection['source_to_diorama_translation_cm'])];q=pose['q'];o=empty('Fixture_'+ident+'_'+str(i),aliases[ident],(xyz[0]/100,-xyz[1]/100,xyz[2]/100),pose['scale']);o.rotation_mode='QUATERNION';o.rotation_quaternion=Quaternion((q[3],-q[0],q[1],-q[2]));fixtures.objects.link(o)
    exemplar=collection('Diorama_StaticFigExemplar');o=empty('Diorama_StaticFig_OnePossibleOutcome',assemblies['Fig'],(-84,-19,0));exemplar.objects.link(o)
    def srgb(v):v=v/255;return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    def light(col,name,kind,at,energy,colour,size=1,target=None):
        d=bpy.data.lights.new(P+name,kind);d.energy=energy;d.color=colour
        if kind=='AREA':d.shape='DISK';d.size=size
        else:d.shadow_soft_size=size
        o=obj(name,d,col);o.location=at
        if target is not None:o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
        return o
    local_lights=collection('Room_PresentationLights')
    for r in selection['retained_source_actors']:
        if 'light' not in r:continue
        xyz=[v+d for v,d in zip(r['pose']['at'],selection['source_to_diorama_translation_cm'])];kind='SPOT' if 'inner_cone' in r['light'] else 'POINT';o=light(local_lights,r['label'],kind,(xyz[0]/100,-xyz[1]/100,xyz[2]/100),r['light']['intensity'],tuple(srgb(v) for v in r['light']['color_rgba'][:3]),r['light']['source_radius']/100);q=r['pose']['q'];o.rotation_mode='QUATERNION';o.rotation_quaternion=Quaternion((q[3],-q[0],q[1],-q[2]))
        if kind=='SPOT':
            # Native light points local+X; Blender spot points local-Z.
            o.rotation_quaternion=o.rotation_quaternion@Quaternion((0,1,0),-1.5707963267948966);o.data.spot_size=2*r['light']['outer_cone']*3.141592653589793/180;o.data.spot_blend=1-r['light']['inner_cone']/r['light']['outer_cone']
    for scene_name in ('02_VariantC_Cutaway','Zone_Catacomb'):
        for c in (wallfloor,fixtures,exemplar,local_lights):bpy.data.scenes[scene_name].collection.children.link(c)
    context=collection('Room_ContextCopies')
    for old in list(bpy.data.scenes['Zone_Catacomb'].objects):
        if old.name.startswith(P):continue
        o=old.copy();o.name=P+'Context_'+old.name;context.objects.link(o);new_objects.append(o);o['Owner']=OWNER
    displays=collection('Kit_Exhibits')
    role_ids={'Tomb':'WVC026','Lid':'WVC081','Bone':'WVC052','Urn':'WVC053'}
    for cell in selection['kit_cells']:
        role=cell['role'];at=cell['centre_blender_metres']
        if role in assemblies:o=empty('Kit_'+role,assemblies[role],at);displays.objects.link(o)
        elif role in role_ids:
            display=next(r for r in selection['mesh_displays'] if r['role']==role);p=display['kit_native_actor_pose'];o=empty('Kit_'+role,prop_collections[role_ids[role]],(p['at'][0]/100,-p['at'][1]/100,p['at'][2]/100));displays.objects.link(o)
        elif role in ('Walls','Floor','Ceiling'):
            c=collection('Kit_'+role+'_SourceGeometry')
            for name in [n for n in mesh_names if '_'+role.lower()+'_' in n]:obj('KitGeometry_'+name,meshes[name],c)
            d=next(r for r in selection['mesh_displays'] if r['role']==role);p=d['kit_native_actor_pose'];scale=d['scale'];root_at=[p['at'][0]/100+72*scale,-p['at'][1]/100+21*scale,p['at'][2]/100];o=empty('Kit_'+role,c,root_at,(scale,scale,scale));displays.objects.link(o)
        else:
            o=obj('Kit_'+role,cube,displays);o.location=(at[0],at[1],1.3);o.scale=(.24,.24,2.6) if role=='TimberPost' else (1.2,.12,.12);o.material_slots[0].link='OBJECT';o.material_slots[0].material=materials['Post' if role=='TimberPost' else 'Arm']
        text=bpy.data.curves.new(P+'Label_'+role,'FONT');text.body=role+' / Catacomb';text.size=.30;text.align_x='CENTER'
        label=obj('Label_'+role,text,displays);label.location=(at[0],at[1]+2.8,.02)
    bpy.data.scenes['01_VariantCLibrary'].collection.children.link(displays)
    def scene(name,collections):
        s=bpy.data.scenes.new(P+name);s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1400;s.render.resolution_y=875;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.eevee.taa_render_samples=128;s.eevee.shadow_ray_count=4;s.eevee.shadow_step_count=12;s.view_settings.view_transform='AgX'
        w=bpy.data.worlds.new(P+name+'_World');w.use_nodes=True;w.node_tree.nodes['Background'].inputs['Color'].default_value=(.04,.04,.04,1);w.node_tree.nodes['Background'].inputs['Strength'].default_value=.2;s.world=w
        for c in collections:s.collection.children.link(c)
        return s
    def camera(scene,name,at,target,lens=28):
        d=bpy.data.cameras.new(P+name);d.lens=lens;d.clip_end=2000;o=bpy.data.objects.new(P+name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o['Owner']=OWNER;new_objects.append(o);return o
    cut=scene('Catacomb_Cutaway',[context,wallfloor,fixtures,exemplar,local_lights]);cut.camera=camera(cut,'CutawayCamera',(-92,-4,21),(-73,-21,1.5),30)
    complete=scene('Catacomb_CompleteRoom',[context,wallfloor,ceiling,fixtures,exemplar,local_lights]);complete.camera=camera(complete,'PlayerCamera',(-80,-19,1.12),(-76,-25,1),18)
    kit_scene=scene('Catacomb_Kit',[displays]);cy=selection['kit_cells'][0]['centre_blender_metres'][1];kit_scene.camera=camera(kit_scene,'ForageCamera',(10.5,cy+22,2.2),(10.5,cy,2.2),28)
    labels=collection('Kit_UprightLabels');kit_scene.collection.children.link(labels)
    for cell in selection['kit_cells'][:3]:
        d=bpy.data.curves.new(P+'Upright_'+cell['role'],'FONT');d.body=cell['role']+' / static exemplar';d.size=.30;d.align_x='CENTER'
        o=obj('Upright_'+cell['role'],d,labels);o.location=(cell['centre_blender_metres'][0],cy+1.2,.20);o.rotation_euler=(1.5707963267948966,0,3.141592653589793)
    studio=collection('Kit_StudioLights');kit_scene.collection.children.link(studio);light(studio,'StudioKey','AREA',(10,cy+7,12),2500,(1,.86,.70),12,(10,cy,1));light(studio,'StudioFill','AREA',(18,cy-7,8),1800,(.70,.80,1),12,(10,cy,1));light(studio,'MaterialRowsFill','AREA',(55,cy+3,12),5000,(1,.92,.82),30,(55,cy,0))
    overview_camera=camera(kit_scene,'KitOverviewCamera',(40,cy+38,28),(40,cy,1),24)
    # Presentation lantern proxy belongs only to the derived complete-room scene.
    lamp=collection('Room_ReviewLantern');complete.collection.children.link(lamp);light(lamp,'ReviewLantern','POINT',(-79.8,-18.8,.8),55,(1,.66,.34),.08)
    bpy.context.window.scene=active;bpy.context.view_layer.update();after=snapshot(sync);assert_originals(before,after,allowed_refs);guards()
    candidate=folder/('WarrensVariantC_'+target+'_Catacomb_R21.blend');bpy.ops.wm.save_as_mainfile(filepath=str(candidate),compress=True,relative_remap=False)
    frames=[]
    for label,s,c in [('cutaway',cut,cut.camera),('room',complete,complete.camera),('forage_kit',kit_scene,kit_scene.camera),('material_kit',kit_scene,overview_camera)]:
        bpy.context.window.scene=s;s.camera=c;bpy.context.view_layer.update();s.render.filepath=str(folder/(label+'.png'));bpy.ops.render.render(write_still=True);frames.append(dict(view=label,file=label+'.png',sha256=sha(folder/(label+'.png')),scene=s.name,camera=[list(v) for v in c.matrix_world]))
    bpy.context.window.scene=active;bpy.context.view_layer.update();assert_originals(before,snapshot(sync),allowed_refs);guards()
    report=dict(status='DERIVED_LIBRARY_CANDIDATE_AND_PREVIEWS_ORIGINALS_UNCHANGED',target=target,original=original.relative_to(ROOT).as_posix(),original_sha256=sha(original),candidate=candidate.relative_to(ROOT).as_posix(),candidate_sha256=sha(candidate),selection_sha256=sha(DOC/'LIBRARY_SELECTION_R21.json'),material_tool_sha256=sha(HERE/'catacomb_blender_materials_r21.py'),old_meshes=len(before['meshes']),old_materials=len(before['materials']),old_object_count=len(before['objects']),allowed_collection_reference_changes=allowed_refs,new_objects=[o.name for o in new_objects],frames=frames,boundary='Derived Blender presentation, not native photometric/pixel equivalence. Watts-per-candela1 is a presentation calibration only. Static exemplars are not authored selections; original library promotion remains pending review. Earlier Sluice library sync remains outstanding.')
    (folder/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('DERIVED_LIBRARY_READY',target,sha(folder/'receipt.json'))
if __name__=='__main__':main()
