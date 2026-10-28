"""Correct only inspection scene units; preserve the exported closed-jar FBX."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    source=DOC/'closed-storage-jar-r01';out=DOC/'closed-storage-jar-r02';assert not out.exists();r=json.loads((source/'receipt.json').read_text());assert Path(bpy.data.filepath).resolve()==source/'ClosedStorageJar_Study_R01.blend' and sha(source/'ClosedStorageJar_Study_R01.blend')==r['derived_blend_sha256'];fbx=ROOT/r['fbx'];assert sha(fbx)==r['fbx_sha256']
    scene=bpy.context.scene;before={o.name:dict(location=list(o.location),scale=list(o.scale)) for o in scene.objects};scene.unit_settings.scale_length=1
    for o in scene.objects:
        o.location*=.01
        if o.type=='MESH':o.scale*=.01
        elif o.type=='LIGHT':o.data.size*=.01
        elif o.type=='CAMERA':o.data.ortho_scale*=.01;o.data.clip_start*=.01;o.data.clip_end*=.01
        else:raise AssertionError(o.type)
    out.mkdir();frames=[]
    for name in ('three_quarter','top','side'):
        scene.camera=bpy.data.objects[name];scene.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);frames.append(dict(file=name+'.png',sha256=sha(out/(name+'.png'))))
    path=out/'ClosedStorageJar_Study_R02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True);assert sha(fbx)==r['fbx_sha256']
    (out/'receipt.json').write_text(json.dumps(dict(status='DERIVED_CLOSED_JAR_METRE_INSPECTION_ONLY_NOT_NATIVE_ACCEPTANCE',model_receipt_sha256=sha(source/'receipt.json'),fbx=r['fbx'],fbx_sha256=r['fbx_sha256'],geometry_unchanged=True,only_scene_delta='Display centimetre mesh atobjectscale.01 inmetrescene; cameras/lightpositions andopticalrectsizes scaled.01, lightWatts unchanged. Fixes cm-based 100-unit illumination distance. Mesh data andexportedFBX retained byteexact.',before_scene_objects=before,derived_blend_sha256=sha(path),frames=frames,tool_sha256=sha(__file__)),indent=2)+'\n');print('CLOSED_JAR_RELIT_PREVIEW_COMPLETE',sha(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
