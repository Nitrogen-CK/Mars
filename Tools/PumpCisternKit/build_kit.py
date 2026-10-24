"""Headless Pump/Cistern kit: reuse the shared Blender construction/export tools."""
import argparse,importlib.util,json,math,sys,uuid
from pathlib import Path
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
sys.path.insert(0,str(HERE))
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true');parser.add_argument('--skip-previews',action='store_true');args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    core=module('warrens_blender_core',ROOT/'Tools/ChainCrossingKit/build_kit.py');core.OUT=HERE/'Output'
    core.CATEGORIES={k:str(uuid.uuid5(uuid.NAMESPACE_URL,'PumpCisternKit/'+k)) for k in core.CATEGORIES}
    for p in ['FBX','Previews','Renders','Reports']:(core.OUT/p).mkdir(parents=True,exist_ok=True)
    (core.OUT/'.blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(f'{v}:{k}:{k}' for k,v in core.CATEGORIES.items())+'\n')
    family=module('pump_family',HERE/'generators/pump_cistern.py')
    # The shared core also has fitted_placement.py; resolve this zone explicitly.
    data=module('pump_source_fitting',HERE/'fitted_placement.py').build();core.write('fitted_instances.json',data)
    parts=json.loads((HERE/'model_catalog.json').read_text())
    bpy.ops.wm.read_factory_settings(use_empty=True);library=bpy.context.scene;library.name='01_PumpCisternLibrary';core.setup_scene(library,'PumpLibrary',.45)
    mats=core.load_materials();cols={};report=[]
    for part in parts:
        col=bpy.data.collections.new(part['id']+'_'+part['name']);library.collection.children.link(col);b=core.Builder(part,mats,col)
        if part['id']=='PWC25':
            poly=[[10,32],[20,32],[21.5,36.5],[15,37],[15,43],[10,42]]
            b.mesh('SourcePolygon',[(x-15.75,-(y-37.5),0) for x,y in poly],[tuple(reversed(range(len(poly))))],'FX_ShallowWater');b.flag('card',True);b.flag('source_polygon',True)
        else:family.build(b,part)
        o,row=core.finish(b);row['fbx']=core.export(o,col);report.append(row);cols[part['id']]=col;library.collection.children.unlink(col)
        print('PUMP_ASSET_COMPLETE',part['id'],row['triangles'],flush=True)
    shared_ids=sorted({p['id'] for p in data['placements'] if p['id'].startswith('CCS')})
    source=ROOT/'Tools/ChainCrossingKit/Output/ChainCrossing_KitLibrary.blend'
    with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.collections=[n for n in src.collections if any(n.startswith(i+'_') for i in shared_ids)]
    for c in dst.collections:cols[c.name.split('_')[0]]=c
    assert all(i in cols for i in shared_ids)
    # Internal seam backings are utility geometry, not duplicate exported art assets.
    for key in ['TX01','TX02']:
        c=bpy.data.collections.new('Utility_BACKING_'+key);library.collection.children.link(c)
        bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object
        for old in list(o.users_collection):old.objects.unlink(o)
        c.objects.link(o);o.data.materials.append(mats[key]);cols['BACKING_'+key]=c;library.collection.children.unlink(c)
    # Context proxies preserve out-of-scope gallery appearance in the live map.
    # They are not art assets and are omitted from the standalone cutaway.
    ids=[r['id'] for r in report]+shared_ids
    for i,ident in enumerate(ids):core.instance(library,cols[ident],ident+'_Library',((i%8-3.5)*4,(i//8)*4,0))
    core.camera(library,(30,-34,42),(0,12,1),55);core.light(library,'LibraryKey',(-10,-6,30),20000,size=25,target=(0,12,0));core.light(library,'LibraryFill',(18,25,20),10000,size=20,target=(0,12,0))
    diorama=bpy.data.scenes.new('02_WaterworksCutaway');core.setup_scene(diorama,'WaterworksDiorama',.25)
    placed=[]
    for i,p in enumerate(data['placements']):
        if p['id']=='SOURCE_GALLERY':continue
        if 'ceiling' in p['role']:continue # Explicit cutaway review; live ceilings remain fitted.
        at=[p['at'][0]-38,-(p['at'][1]-28),p['at'][2]+2.5]
        r=p.get('rotation');rot=[r[2],-r[0],-r[1]] if r else None
        core.instance(diorama,cols[p['id']],p['id']+'_Assembly_'+str(i),at,p['scale'],-p.get('yaw',0),rot);placed.append(p)
    core.camera(diorama,(38,-50,54),(0,0,1),83);core.light(diorama,'WarmKey',(0,-12,28),20000,(1,.74,.48),25);core.light(diorama,'CoolFill',(-15,20,22),16000,(.4,.58,.68),25)
    for im in bpy.data.images:
        if im.source=='FILE' and not im.packed_file:im.pack()
    core.write('asset_manifest.json',dict(count=len(report),assets=report,shared_reuse_ids=shared_ids,library_entries=len(ids),diorama_instances=len(placed),units='Blender metres; FBX explicit centimetres'))
    bpy.context.window.scene=library;bpy.ops.wm.save_as_mainfile(filepath=str(core.OUT/'PumpCistern_KitLibrary.blend'),compress=True)
    bpy.context.window.scene=diorama;bpy.ops.wm.save_as_mainfile(filepath=str(core.OUT/'PumpCistern_Diorama.blend'),compress=True)
    if not args.no_render:
        for sc,name in [(library,'KIT_LIBRARY'),(diorama,'DIORAMA')]:bpy.context.window.scene=sc;sc.render.filepath=str(core.OUT/'Renders'/f'{name}.png');bpy.ops.render.render(write_still=True)
    if not args.no_render and not args.skip_previews:
        preview=bpy.data.scenes.new('03_NewModelReview');core.setup_scene(preview,'PumpModelReview',.5);preview.render.resolution_x=512;preview.render.resolution_y=512;preview.cycles.samples=8
        core.light(preview,'Key',(-4,-5,7),600,size=5);core.light(preview,'Fill',(4,3,5),400,size=4);cam=core.camera(preview,(4,-6,4),(0,0,.5),4);bpy.context.window.scene=preview
        for r in report:
            o=core.instance(preview,cols[r['id']],r['id']+'_Preview',(0,0,0));dims=[n/100 for n in r['dimensions_cm']];z=0 if r['pivot']=='center' else -dims[2]/2 if r['pivot']=='top contact' else dims[2]/2
            at=Vector((0,0,z));cam.location=at+Vector((4,-6,4))*max(dims)*.8;cam.rotation_euler=(at-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(dims)*1.6
            preview.render.filepath=str(core.OUT/'Previews'/f"{r['id']}.png");bpy.ops.render.render(write_still=True);bpy.data.objects.remove(o,do_unlink=True)
    print('PUMP_KIT_BUILD_COMPLETE',len(report),len(shared_ids),len(placed),flush=True)

if __name__=='__main__':main()
