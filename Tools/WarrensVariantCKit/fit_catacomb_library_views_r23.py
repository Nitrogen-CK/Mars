"""Frame actual evaluated geometry and labels; add local presentation lamps only."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def module(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_cp23_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def main():
    import bpy
    from mathutils import Vector
    parser=argparse.ArgumentParser();parser.add_argument('--target',choices=('Diorama','KitLibrary'),required=True);a=parser.parse_args(sys.argv[sys.argv.index('--')+1:]);target=a.target
    previous=DOC/'catacomb-library-sync-r22'/target;r=json.loads((previous/'receipt.json').read_text());source=ROOT/r['candidate'];assert Path(bpy.data.filepath).resolve()==source.resolve() and sha(source)==r['candidate_sha256']
    writer=module('stage_catacomb_blender_libraries_r21');sync=module('sync_art_libraries');writer.guards();baseline=json.loads((ROOT/r['original_baseline']).read_text());active=bpy.context.window.scene
    before=writer.snapshot(sync);writer.assert_originals(baseline,before,r['allowed_collection_reference_changes'])
    out=DOC/'catacomb-library-sync-r23'/target;out.mkdir(parents=True,exist_ok=False)
    views=[('forage_kit','CP21_Catacomb_Kit'),('props','CP22_Props'),('surfaces','CP22_Surfaces'),('ceiling','CP22_CeilingUnderside'),('timber','CP22_Timber'),('fig_detail','CP22_Fig_Detail'),('censer_detail','CP22_Censer_Detail'),('bellnut_detail','CP22_Bellnut_Detail')]
    frames=[]
    for name,scene_name in views:
        s=bpy.data.scenes[scene_name];bpy.context.window.scene=s;bpy.context.view_layer.update()
        if name in ('props','surfaces'):
            for o in s.objects:
                if o.type=='FONT':o.rotation_euler=(1.5707963267948966,0,3.141592653589793);o.location.z=-.3
        deps=bpy.context.evaluated_depsgraph_get();points=[];mesh_points=[]
        for item in deps.object_instances:
            o=item.object
            if o.type not in ('MESH','FONT') or o.hide_render:continue
            corners=[item.matrix_world@Vector(p) for p in o.bound_box];points+=corners
            if o.type=='MESH':mesh_points+=corners
        assert points and mesh_points
        lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)));centre=(lo+hi)/2
        c=s.camera;c.data.lens=45
        back=Vector((0,1,-.22 if name=='ceiling' else .28)).normalized();q=(-back).to_track_quat('-Z','Y');c.rotation_euler=q.to_euler();right=q@Vector((1,0,0));up=q@Vector((0,1,0))
        frame=c.data.view_frame(scene=s);tx=max(abs(v.x/v.z) for v in frame);ty=max(abs(v.y/v.z) for v in frame)
        distance=max((p-centre).dot(back)+max(abs((p-centre).dot(right))/tx,abs((p-centre).dot(up))/ty) for p in points)*1.12
        c.location=centre+back*max(distance,1);c.data.clip_end=2000
        ml=Vector(tuple(min(p[i] for p in mesh_points) for i in range(3)));mh=Vector(tuple(max(p[i] for p in mesh_points) for i in range(3)));mc=(ml+mh)/2;span=max((mh-ml).x,(mh-ml).y,(mh-ml).z,1)
        # These lights belong only to this review scene; originals and art are immutable.
        for suffix,offset,power,tint in [('Key',(0,.65,-.45 if name=='ceiling' else .65),180,(1,.91,.8)),('Fill',(-.65,-.25,-.35 if name=='ceiling' else .35),80,(.8,.87,1))]:
            d=bpy.data.lights.new('CP23_'+name+'_'+suffix,'AREA');d.energy=power*span*span;d.shape='DISK';d.size=span
            o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o);o.location=mc+Vector(offset)*span;o.rotation_euler=(mc-o.location).to_track_quat('-Z','Y').to_euler();d.color=tint;o['Owner']='Mars.WarrensVariantC.LibraryViews.R23'
        frames.append(dict(view=name,scene=s.name,file=name+'.png',camera=[list(v) for v in c.matrix_world],fit_bounds=[list(lo),list(hi)],fit_distance=distance,local_lamp_span=span))
    bpy.context.window.scene=active;bpy.context.view_layer.update();after=writer.snapshot(sync);writer.assert_originals(baseline,after,r['allowed_collection_reference_changes'])
    for key in ('meshes','materials'):
        assert before[key]==after[key],('Art changed',key)
    for n,o in before['objects'].items():
        if bpy.data.objects[n].type in ('MESH','EMPTY'):assert o==after['objects'][n],('Art transform changed',n)
    writer.guards();candidate=out/('WarrensVariantC_'+target+'_Catacomb_R23.blend');bpy.ops.wm.save_as_mainfile(filepath=str(candidate),compress=True,relative_remap=False)
    for row in frames:
        s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;bpy.context.view_layer.update();s.render.filepath=str(out/row['file']);bpy.ops.render.render(write_still=True);row['sha256']=sha(out/row['file'])
    bpy.context.window.scene=active;bpy.context.view_layer.update();writer.assert_originals(baseline,writer.snapshot(sync),r['allowed_collection_reference_changes']);writer.guards()
    report=dict(r,status='BOUNDS_FITTED_LOCAL_STUDIO_LIBRARY_SUCCESSOR',source=source.relative_to(ROOT).as_posix(),source_sha256=sha(source),candidate=candidate.relative_to(ROOT).as_posix(),candidate_sha256=sha(candidate),writer_sha256=sha(__file__),prior_receipt_sha256=sha(previous/'receipt.json'),frames=frames,room_frames_unchanged_from_r22=True)
    (out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('BOUNDS_FIT_READY',target,sha(out/'receipt.json'))
if __name__=='__main__':main()
