"""Derived-only Catacomb envelope comparison; original source geometry and files stay exact."""
import argparse,hashlib,importlib.util,json,math,re,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent
BASE=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'
PREFIX='EnvelopePilot_'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text(encoding='utf-8-sig'))
def load(name,file,expected):
    assert sha(file)==expected,('Changed helper',file)
    spec=importlib.util.spec_from_file_location(name,file)
    mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);return mod
def inside(p,poly):
    x,y=p;c=False
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:c=not c
    return c

def main():
    import bpy
    from mathutils import Vector,Matrix
    parser=argparse.ArgumentParser();parser.add_argument('--output',required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:])
    output=(ROOT/args.output).resolve()
    assert output.is_relative_to(BASE.resolve()) and not output.exists()
    source=HERE/'Output/WarrensVariantC_Diorama.blend'
    assert Path(bpy.data.filepath).resolve()==source.resolve()
    assert sha(source)=='fb1e49fc6a634b329a31722dd480f1c68ce583b34a5d3af4dbfd0b6e06c56ba3'
    sync=load('_envelope_sync',HERE/'sync_art_libraries.py','5de7683ebf5829952c0b31b39d3d28ff34b070019ab61fc2da01462ca3bbbad6')
    guards=sync.immutable_files()
    paths=dict(fit=HERE/'Output/fitted_instances.json',plan=ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json',
        selection=BASE/'catacomb-slate-painterly-r05-current-source/dark_slate_wall_coverage_r04.json',
        diagnosis=ROOT/'Saved/WarrensCGameplay-20261024/slate_raster_face_diagnosis_r01.json',
        views=BASE/'catacomb-slate-painterly-r02/dark_slate_views_r01.json',
        image=BASE/'catacomb-reference-match-r01/Stone_PainterlyDirectional_Albedo_r01.png')
    expected={'fit':'67f8e8d87ab166ab7fd0cd5e285a08e02b8643c856de3bf028130271021b9d34',
        'selection':'dda914f599fa16244b15688106080044ee01cf53cc2e52d598c3446ed6709a61',
        'diagnosis':'588732a721e52db32defae21e848f1b38518646a5a76a59cf739c0789d65d40c',
        'image':'efa686ed165cf26afc2c044a0436d1ccf9514e1107d71369ec6755a2a7347672'}
    for k,p in paths.items():
        if k in expected:assert sha(p)==expected[k],k
        guards[p.relative_to(ROOT).as_posix()]=sha(p)
    rows=read(paths['fit'])['placements'];plan=read(paths['plan'])
    room=next(r for r in plan['rooms'] if r['id']=='catacomb')
    poly=room.get('poly',room.get('polygon'));assert poly,room
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    before={o.name:[list(r) for r in o.matrix_world] for o in scene.objects}
    originals={m.name:sync.stable(sync.nodes(m.node_tree)) for m in bpy.data.materials if m.use_nodes}
    byname={re.sub(r'\.\d{3}$','',o.name):o for o in scene.objects if o.instance_type=='COLLECTION'}
    aliases={o.name.removesuffix('_Library'):o.instance_collection for o in bpy.data.scenes['01_VariantCLibrary'].objects if o.instance_type=='COLLECTION'}
    # The cutaway intentionally omits ceilings. Recreate their original ledger
    # poses from the exact floor mesh, with the authored TX01 ceiling alias.
    ceiling_col=aliases['CCS13'].copy();ceiling_col.name=PREFIX+'AuthoredCeilingPrototype'
    for p in list(ceiling_col.objects):ceiling_col.objects.unlink(p)
    # Seam backings are assembly utility prototypes, not catalogue cards.
    assert rows[29435]['id']=='BACKING_TX01'
    aliases['BACKING_TX01']=byname['BACKING_TX01_Assembly_29435'].instance_collection
    original_tx01=aliases['BACKING_TX01'].objects[0].material_slots[0].material
    for old in aliases['CCS13'].objects:
        part=old.copy();part.data=old.data;ceiling_col.objects.link(part)
        for slot in part.material_slots:
            assert slot.material.get('catalog_key')=='TX02'
            slot.link='OBJECT';slot.material=original_tx01
    selected=[];restored=[]
    for key,row in enumerate(rows):
        if row['tile']!='Catacomb' or 'ceiling' not in row['role']:continue
        col=ceiling_col if row['id']=='CCS13_TX01' else aliases[row['id']]
        obj=sync.add_instance(scene,col,PREFIX+'SourceCeiling_'+str(key),row,'ceiling_'+str(key))
        restored.append(key);byname[row['id']+'_Assembly_'+str(key)]=obj
    strict=read(paths['selection']);diagnosis=read(paths['diagnosis'])
    pairs=[p for p in strict['pairs'] if p.get('room_id',p.get('room'))=='catacomb']
    # Measured raster-floor witnesses are experimental membership, explicitly
    # recorded; they do not authorize changes to source assets or other rooms.
    additions=[p for p in diagnosis['proposal'] if p['room']=='catacomb']
    assert len(pairs)==33 and len(additions)==19,(len(pairs),len(additions))
    wallkeys={k for p in pairs+additions for k in p['source_keys']}
    axes={k:p['axis'] for p in pairs+additions for k in p['source_keys']}
    for key,row in enumerate(rows):
        if row['tile']!='Catacomb':continue
        role=row['role'];kind=None
        if key in wallkeys:kind='walls'
        elif inside(row['at'][:2],poly) and role in ('source floor veneer','source floor seam backing'):kind='floor'
        elif inside(row['at'][:2],poly) and 'ceiling' in role:kind='ceiling'
        elif row['id'] in ('WVC026','WVC081') and inside(row['at'][:2],poly):kind='stone_props'
        if kind:
            obj=byname[row['id']+'_Assembly_'+str(key)];sync.check_pose(obj,row)
            selected.append((key,row,obj,kind))
    assert len(wallkeys)==104 and sum(k=='ceiling' for _,_,_,k in selected)==462
    image=bpy.data.images.load(str(paths['image']),check_existing=False);image.pack()
    # A warm pigment study only. Existing Catacomb slate/amber palette is not
    # overridden: no import or source promotion is performed by this tool.
    image.colorspace_settings.name='sRGB'
    materials={};wrappers={};deltas=[]
    def candidate(old,kind,axis):
        cache=(old.name,kind,axis)
        if cache in materials:return materials[cache]
        m=old.copy();m.name=PREFIX+kind+'_'+str(axis)+'_'+old.name
        tree=m.node_tree;bsdf=next(n for n in tree.nodes if n.type=='BSDF_PRINCIPLED')
        mix=bsdf.inputs['Base Color'].links[0].from_node
        assert mix.type=='MIX_RGB'
        mix.inputs[0].default_value=.85
        tex=mix.inputs[2].links[0].from_node;assert tex.type=='TEX_IMAGE'
        tex.image=image;tex.extension='REPEAT'
        geom=tree.nodes.new('ShaderNodeNewGeometry');sep=tree.nodes.new('ShaderNodeSeparateXYZ');combine=tree.nodes.new('ShaderNodeCombineXYZ')
        tree.links.new(geom.outputs['Position'],sep.inputs[0])
        # Blender world space is metres; 2 m pigment repeat on all surfaces.
        components=('X','Y') if kind in ('floor','ceiling') else (('Y','Z') if axis==0 else ('X','Z'))
        for target,component in zip(('X','Y'),components):
            scale=tree.nodes.new('ShaderNodeMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=.5
            tree.links.new(sep.outputs[component],scale.inputs[0]);tree.links.new(scale.outputs[0],combine.inputs[target])
        if kind=='stone_props':
            # Box projection covers carved horizontal and vertical surfaces;
            # a fixed wall plane would stretch the tomb lid.
            v=tree.nodes.new('ShaderNodeVectorMath');v.operation='SCALE';v.inputs['Scale'].default_value=.5
            tree.links.new(geom.outputs['Position'],v.inputs[0]);tree.links.new(v.outputs[0],tex.inputs['Vector'])
            tex.projection='BOX';tex.projection_blend=.15
        else:tree.links.new(combine.outputs[0],tex.inputs['Vector'])
        # Normal/roughness remain exactly as in the source. This is a
        # base-color/style test, not a fabricated PBR completion claim.
        materials[cache]=m;return m
    for key,row,obj,kind in selected:
        oldcol=obj.instance_collection;axis=axes.get(key,-1);cache=(oldcol.name,kind,axis)
        if cache not in wrappers:
            col=oldcol.copy();col.name=PREFIX+kind+'_'+str(axis)+'_'+oldcol.name
            for old in list(col.objects):col.objects.unlink(old)
            for old in oldcol.objects:
                part=old.copy();part.data=old.data;col.objects.link(part)
                for i,slot in enumerate(part.material_slots):
                    oldmat=old.material_slots[i].material
                    if oldmat and oldmat.get('catalog_key') in ('TX01','TX02'):
                        slot.link='OBJECT';slot.material=candidate(oldmat,kind,axis)
            wrappers[cache]=col
        deltas.append((obj,oldcol,wrappers[cache]))
    cameras=[]
    record=next(v for v in read(paths['views'])['views'] if v['id']=='catacomb_standing')['camera_record']
    for label,eye,target in [('standing',None,None),('ceiling',[-22,74,1.6],[-17,80,3.45])]:
        data=bpy.data.cameras.new(PREFIX+label);data.lens=28;data.sensor_width=36;data.clip_start=.05;data.clip_end=180
        obj=bpy.data.objects.new(data.name,data);scene.collection.objects.link(obj)
        if eye is None:obj.matrix_world=Matrix(record['camera_matrix'])
        else:
            eye=Vector((eye[0]-58,55-eye[1],eye[2]));target=Vector((target[0]-58,55-target[1],target[2]))
            obj.location=eye;obj.rotation_euler=(target-eye).to_track_quat('-Z','Y').to_euler()
        cameras.append((label,obj))
    # Matched neutral room-review lights sit BELOW the restored ceiling.
    # Existing high cutaway lights cannot illuminate a closed room faithfully.
    lights=[]
    for name,at,energy,size in [('key',[-18,78,3.15],950,5),('fill',[-22,73,2.8],240,3)]:
        d=bpy.data.lights.new(PREFIX+name,'AREA');d.energy=energy;d.shape='DISK';d.size=size;d.color=(1,1,1)
        o=bpy.data.objects.new(d.name,d);scene.collection.objects.link(o);o.location=(at[0]-58,55-at[1],at[2]);lights.append(dict(name=o.name,at=list(o.location),energy=energy,size=size,color=list(d.color)))
    scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=1250;scene.render.resolution_y=813;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';output.mkdir(parents=True)
    frames=[]
    for stage in ('A_source_complete_geometry','B_directional_pigment_complete_geometry'):
        if stage.startswith('B'):
            for obj,old,new in deltas:assert obj.instance_collection==old;obj.instance_collection=new
        for label,camera in cameras:
            scene.camera=camera;bpy.context.view_layer.update();p=output/(stage+'_'+label+'.png');scene.render.filepath=str(p)
            bpy.ops.render.render(write_still=True)
            frames.append(dict(stage=stage,view=label,file=p.name,sha256=sha(p),camera_matrix=[list(r) for r in camera.matrix_world]))
            print('ENVELOPE_FRAME',p.name,flush=True)
    assert all([list(r) for r in scene.objects[n].matrix_world]==pose for n,pose in before.items())
    assert all(sync.stable(sync.nodes(bpy.data.materials[n].node_tree))==g for n,g in originals.items())
    assert all(sha(ROOT/p)==h for p,h in guards.items())
    derived=output/'CatacombEnvelopeStudy.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True,relative_remap=False)
    assert all(sha(ROOT/p)==h for p,h in guards.items())
    receipt=dict(status='DERIVED_COMPLETE_ENVELOPE_PIGMENT_STUDY_NOT_ADOPTED',tool_sha256=sha(__file__),
        source_sha256=sha(source),guards=guards,original_poses_unchanged=len(before),original_material_graphs_unchanged=len(originals),
        restored_original_ceiling_keys=restored,selected=[dict(source_key=k,kind=t,source_row=r) for k,r,o,t in selected],
        experimental_raster_floor_wall_keys=[k for p in additions for k in p['source_keys']],
        material_mix=.85,repeat_metres=2,normal_roughness='Source unchanged; no new maps or PBR acceptance',
        palette='Warm pigment style study; not approval to replace authored slate/amber Catacomb palette',
        lights=lights,frames=frames,derived_sha256=sha(derived),
        boundary='Offline EEVEE review with source ceilings restored. Neutral test lights are not game lighting. No Unreal/editor call, source asset update, library promotion or acceptance proof.')
    (output/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print('ENVELOPE_DONE',sha(output/'receipt.json'),flush=True)

if __name__=='__main__':main()
