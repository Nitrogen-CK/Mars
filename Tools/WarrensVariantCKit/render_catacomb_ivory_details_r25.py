"""Two read-only detail captures from the reopened library; never saves a blend."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    p=argparse.ArgumentParser();p.add_argument('--target',choices=('Diorama','KitLibrary'),required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);r=json.loads((DOC/'catacomb-library-sync-r24'/a.target/'receipt.json').read_text());candidate=ROOT/r['candidate'];assert Path(bpy.data.filepath).resolve()==candidate.resolve() and sha(candidate)==r['candidate_sha256'];out=DOC/'catacomb-library-sync-r25-details'/a.target;out.mkdir(parents=True,exist_ok=False);rows=[]
    for role in ('Bone','Urn'):
        s=bpy.data.scenes.new('CP25_Detail_'+role);s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1200;s.render.resolution_y=900;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.eevee.taa_render_samples=128;s.view_settings.view_transform='AgX';s.world=bpy.data.scenes['CP22_Props'].world;s.collection.objects.link(bpy.data.objects['CP21_Kit_'+role]);bpy.context.window.scene=s;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();points=[item.matrix_world@Vector(v) for item in deps.object_instances if item.object.type=='MESH' for v in item.object.bound_box];assert points;lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)]);centre=(lo+hi)/2;span=max(hi-lo)
        cd=bpy.data.cameras.new('CP25_'+role);cd.lens=45;c=bpy.data.objects.new(cd.name,cd);s.collection.objects.link(c);s.camera=c;back=Vector((.4,1,.4)).normalized();q=(-back).to_track_quat('-Z','Y');c.rotation_euler=q.to_euler();right=q@Vector((1,0,0));up=q@Vector((0,1,0));f=cd.view_frame(scene=s);tx=max(abs(v.x/v.z) for v in f);ty=max(abs(v.y/v.z) for v in f);distance=1.15*max((p-centre).dot(back)+max(abs((p-centre).dot(right))/tx,abs((p-centre).dot(up))/ty) for p in points);c.location=centre+back*distance
        for suffix,offset,power in [('Key',(.5,.6,.7),5.625),('Fill',(-.5,-.4,.3),2.5)]:
            d=bpy.data.lights.new('CP25_'+role+suffix,'AREA');d.energy=power*span*span;d.shape='DISK';d.size=span;o=bpy.data.objects.new(d.name,d);s.collection.objects.link(o);o.location=centre+Vector(offset)*span;o.rotation_euler=(centre-o.location).to_track_quat('-Z','Y').to_euler()
        bpy.context.view_layer.update();f=out/(role.lower()+'.png');s.render.filepath=str(f);bpy.ops.render.render(write_still=True);rows.append(dict(role=role,file=f.name,sha256=sha(f),camera=[list(v) for v in c.matrix_world],source_object='CP21_Kit_'+role))
    assert sha(candidate)==r['candidate_sha256'];receipt=dict(status='READ_ONLY_REOPENED_LIBRARY_IVORY_DETAILS',candidate=r['candidate'],candidate_sha256=sha(candidate),tool_sha256=sha(__file__),frames=rows,blend_saved=False,boundary='Neutral Blender material detail, not native pixel/photometry parity. No geometry/material/pose edits; temporary scenes discarded on process exit.');(out/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n');print('IVORY_DETAILS_READY',sha(out/'receipt.json'))
if __name__=='__main__':main()
