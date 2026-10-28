"""Headless whole-level asset production using the existing shared Blender core."""
import argparse,hashlib,importlib.util,json,math,sys,uuid
from pathlib import Path
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
OUT=HERE/'Output'
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def refuse_promoted_art_overwrite():
    """Refuse the legacy C rebuild once retained art has been promoted."""
    promotion=ROOT/'Saved/WarrensCGameplay-20261024/ArtLibrarySyncCheckpoint/promoted-v3/promotion.json'
    if not promotion.is_file():return
    try:receipt=json.loads(promotion.read_text(encoding='utf-8-sig'))
    except Exception as error:raise RuntimeError('Cannot validate retained-art promotion receipt; refusing legacy rebuild.') from error
    expected={name:'Tools/WarrensVariantCKit/Output/WarrensVariantC_'+name+'.blend' for name in ('KitLibrary','Diorama')}
    targets=receipt.get('targets') if isinstance(receipt,dict) else None
    valid=(isinstance(receipt,dict) and receipt.get('status')=='PROMOTED' and isinstance(targets,dict) and set(targets)==set(expected)
           and all(isinstance(targets[name],dict) and targets[name].get('source')==path
                   and isinstance(targets[name].get('after_sha256'),str) and len(targets[name]['after_sha256'])==64
                   and all(c in '0123456789abcdef' for c in targets[name]['after_sha256'])
                   for name,path in expected.items()))
    if not valid:raise RuntimeError('Retained-art promotion receipt is malformed or has an unexpected status; inspect before rebuilding.')
    raise RuntimeError('Refusing legacy full Blender rebuild: promoted-v3 C art outputs are retained. Use the scoped art-sync and Belfry palette staging tools with explicit review.')

def main():
    p=argparse.ArgumentParser();p.add_argument('--models-only',action='store_true');p.add_argument('--no-render',action='store_true');p.add_argument('--skip-previews',action='store_true');p.add_argument('--render-scenes',help='Comma-separated output scene names; all scenes are still assembled/saved');p.add_argument('--seed',type=int,default=1031)
    args=p.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    # --models-only still saves the KitLibrary blend, so it is also destructive
    # to a promoted retained output and must stop before scene/output mutation.
    refuse_promoted_art_overwrite()
    core=module('variant_c_blender_core',HERE.parent/'ChainCrossingKit/build_kit.py');core.OUT=OUT;core.SEED=args.seed
    core.CATEGORIES={k:str(uuid.uuid5(uuid.NAMESPACE_URL,'WarrensVariantCKit/'+k)) for k in core.CATEGORIES}
    for d in ['FBX','Previews','Renders','Reports']:(OUT/d).mkdir(parents=True,exist_ok=True)
    catalog=json.loads((HERE/'model_catalog.json').read_text());parts=catalog['models']
    families=[module('wvc_'+name,HERE/'generators'/(name+'.py')) for name in ['architecture_interaction','heroes','props','organic_lighting']]
    bpy.ops.wm.read_factory_settings(use_empty=True);library=bpy.context.scene;library.name='01_VariantCLibrary';core.setup_scene(library,'VariantC_Library',.6)
    mats=core.load_materials();cols={};report=[]
    for part in parts:
        family=[f for f in families if part['source_id'] in f.OWNED]
        assert len(family)==1,(part['id'],part['source_id'],len(family))
        col=bpy.data.collections.new(part['id']+'_'+part['name']);library.collection.children.link(col)
        b=core.Builder(part,mats,col);family[0].build(b,part);o,row=core.finish(b)
        row['source_id']=part['source_id'];row['reference_images']=part['reference_images'];row['fbx']=core.export(o,col)
        report.append(row);cols[row['id']]=col;library.collection.children.unlink(col)
        print('VARIANT_C_ASSET_COMPLETE',row['id'],row['source_id'],row['triangles'],flush=True)
    shared=[];catalog_lines=[f'{v}:Warrens Variant C/{k}:{k}' for k,v in core.CATEGORIES.items()]
    for folder,prefix,file in [('ChainCrossingKit','CCS','ChainCrossing_KitLibrary.blend'),('PumpCisternKit','PWC','PumpCistern_KitLibrary.blend')]:
        source=HERE.parent/folder/'Output';manifest=json.loads((source/'asset_manifest.json').read_text())
        for r in manifest['assets']:shared.append({**r,'kit':folder,'unreal_root':'/Game/Mars/Environment/'+folder})
        with bpy.data.libraries.load(str(source/file),link=False) as (src,dst):dst.collections=[n for n in src.collections if n.startswith(prefix) and n.split('_')[0] in {r['id'] for r in manifest['assets']}]
        for c in dst.collections:cols[c.name.split('_')[0]]=c
        catalog_lines.extend(line for line in (source/'.blender_assets.cats.txt').read_text().splitlines() if ':' in line and not line.startswith('#'))
    (OUT/'.blender_assets.cats.txt').write_text('VERSION 1\n\n'+'\n'.join(dict.fromkeys(catalog_lines))+'\n')
    ids=[r['id'] for r in report]+[r['id'] for r in shared]
    assert len(ids)==len(set(ids))==196
    for i,ident in enumerate(ids):core.instance(library,cols[ident],ident+'_Library',((i%14-6.5)*7,(i//14)*7,0))
    core.camera(library,(105,-115,145),(0,45,1),170)
    core.light(library,'LibraryKey',(-25,-10,70),70000,size=100,target=(0,45,0));core.light(library,'LibraryFill',(40,90,50),50000,size=100,target=(0,45,0))
    scenes=[]
    if not args.models_only:
        data=json.loads((OUT/'fitted_instances.json').read_text())
        for key in ['TX01','TX02','TX04','TX17']:
            c=bpy.data.collections.new('Utility_BACKING_'+key);library.collection.children.link(c)
            bpy.ops.mesh.primitive_cube_add(size=1);o=bpy.context.object
            for old in list(o.users_collection):old.objects.unlink(o)
            c.objects.link(o);o.data.materials.append(mats[key]);cols['BACKING_'+key]=c;library.collection.children.unlink(c)
        cols['SOURCE_CUBE_TX01']=cols['BACKING_TX01']
        cols['SOURCE_CUBE_TX02']=cols['BACKING_TX02']
        for zone in ['ALL']+list(data['pivots']):
            sc=bpy.data.scenes.new('02_VariantC_Cutaway' if zone=='ALL' else 'Zone_'+zone);core.setup_scene(sc,'Warrens_'+zone,.35)
            placed=[]
            for i,row in enumerate(data['placements']):
                if zone!='ALL' and row['tile']!=zone:continue
                if 'ceiling' in row['role'] or row.get('context_proxy'):continue
                ident=row.get('mesh_id',row['id']);col=cols[ident]
                if row.get('material') and row['id']!=ident:
                    alias=row['id']
                    if alias not in cols:
                        variant=bpy.data.collections.new('Variant_'+alias)
                        for original in col.objects:
                            obj=original.copy();obj.data=original.data.copy();variant.objects.link(obj)
                            obj.data.materials.clear();obj.data.materials.append(mats[row['material']])
                        cols[alias]=variant
                    col=cols[alias]
                at=[row['at'][0]-58,-(row['at'][1]-55),row['at'][2]]
                r=row.get('rotation');rot=[r[2],-r[0],-r[1]] if r else None
                core.instance(sc,col,row['id']+'_Assembly_'+str(i),at,row.get('scale',(1,1,1)),-row.get('yaw',0),rot);placed.append(row)
            if not placed:continue
            x0=min(p['at'][0] for p in placed)-58;x1=max(p['at'][0] for p in placed)-58
            y0=min(-(p['at'][1]-55) for p in placed);y1=max(-(p['at'][1]-55) for p in placed)
            center=((x0+x1)/2,(y0+y1)/2,1);span=max(x1-x0,y1-y0,16)
            core.camera(sc,(center[0]+span*.5,center[1]-span*.65,span*.8),center,span*1.3)
            energy_scale=max(1,(span/50)**2)
            core.light(sc,'CutawayKey',(center[0]-span*.2,center[1]-span*.2,span*.7),50000*energy_scale,(1,.78,.55),span,target=center)
            core.light(sc,'CutawayFill',(center[0]+span*.3,center[1]+span*.4,span*.5),40000*energy_scale,(.45,.65,.8),span,target=center)
            scenes.append((sc,'DIORAMA' if zone=='ALL' else 'ZONE_'+zone,len(placed)))
    for im in bpy.data.images:
        if im.source=='FILE' and not im.packed_file:im.pack()
    manifest=dict(count=len(report),assets=report,shared_assets=shared,library_entries=len(ids),scenes={name:count for sc,name,count in scenes},stage='models_only' if args.models_only else 'assembled',seed=args.seed,source_catalog_sha256=hashlib.sha256((HERE/'model_catalog.json').read_bytes()).hexdigest(),units='Blender metres; explicit centimetre FBX')
    core.write('asset_manifest.json',manifest)
    bpy.context.window.scene=library;bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'WarrensVariantC_KitLibrary.blend'),compress=True)
    if scenes:
        bpy.context.window.scene=scenes[0][0];bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'WarrensVariantC_Diorama.blend'),compress=True)
    if not args.no_render:
        selected=set(args.render_scenes.split(',')) if args.render_scenes else None
        if selected is None or 'KIT_LIBRARY' in selected:
            bpy.context.window.scene=library;library.render.filepath=str(OUT/'Renders/KIT_LIBRARY.png');bpy.ops.render.render(write_still=True)
        for sc,name,count in scenes:
            if selected is not None and name not in selected:continue
            bpy.context.window.scene=sc;sc.render.filepath=str(OUT/'Renders'/(name+'.png'));bpy.ops.render.render(write_still=True)
    if not args.no_render and not args.skip_previews:
        preview=bpy.data.scenes.new('Model_Review');core.setup_scene(preview,'ModelReview',.55);preview.render.resolution_x=512;preview.render.resolution_y=512;preview.cycles.samples=8
        core.light(preview,'Key',(-4,-5,7),600,size=5);core.light(preview,'Fill',(4,3,5),400,size=4);cam=core.camera(preview,(4,-6,4),(0,0,.5),4);bpy.context.window.scene=preview
        for row in report+shared:
            ident=row['id'];o=core.instance(preview,cols[ident],ident+'_Review',(0,0,0));dims=[x/100 for x in row['actual_dimensions_cm']]
            z=0 if row['pivot']=='center' else -dims[2]/2 if row['pivot']=='top contact' else dims[2]/2;at=Vector((0,0,z))
            cam.location=at+Vector((4,-6,4))*max(dims)*.8;cam.rotation_euler=(at-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=max(dims)*1.6
            preview.render.filepath=str(OUT/'Previews'/(ident+'.png'));bpy.ops.render.render(write_still=True);bpy.data.objects.remove(o,do_unlink=True)
    print('VARIANT_C_KIT_BUILD_COMPLETE',len(report),len(shared),manifest['stage'],flush=True)
if __name__=='__main__':main()
