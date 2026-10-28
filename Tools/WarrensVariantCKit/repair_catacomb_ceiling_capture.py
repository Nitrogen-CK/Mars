"""Correct two ceiling images using the pinned actual CAMERA, without saving geometry."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02';PREFIX='CatacombPilot_R02_'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def main():
    import bpy
    from mathutils import Vector
    r=read(DOC/'pilot-preview-r03/receipt.json');original=read(DOC/'pilot-preview-r02/receipt.json');export=read(DOC/'export-r03/audit_export.json')
    source=Path(bpy.data.filepath);assert sha(source)==r['derived_sha256']
    assert all(sha(ROOT/k)==v for k,v in r['guards'].items());assert all(sha(ROOT/v['file'])==v['sha256'] for v in export['exports'])
    matrix=next(f for f in original['frames'] if f['view']=='ceiling')['camera_matrix']
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene;bpy.context.view_layer.update()
    cameras=[o for o in scene.objects if o.type=='CAMERA' and all(abs(a-b)<1e-6 for aa,bb in zip(o.matrix_world,matrix) for a,b in zip(aa,bb))]
    camera,=cameras;assert camera.type=='CAMERA' and camera.data.type=='PERSP' and abs(camera.data.lens-28)<1e-6
    assert bpy.data.objects[PREFIX+'ceiling'].type=='MESH'
    out=DOC/'ceiling-camera-fix-r01';assert not out.exists();out.mkdir();frames=[]
    for stage in ('C_angular_pigment_neutral','D_local_warm_lights'):
        warm=stage.startswith('D')
        for l in r['lights']:bpy.data.objects[l['name']].hide_render=(l['group']=='warm')!=warm
        lantern=bpy.data.objects[PREFIX+'PlayerLanternReviewProxy'];lantern.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)))
        scene.camera=camera;assert scene.camera.type=='CAMERA'
        path=out/(stage+'_ceiling.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        frames.append(dict(stage=stage,view='ceiling',file=path.name,sha256=sha(path),camera_object=camera.name,camera_type=camera.type,lens_mm=camera.data.lens,camera_matrix=[list(v) for v in camera.matrix_world]))
    assert sha(source)==r['derived_sha256'];assert all(sha(ROOT/k)==v for k,v in r['guards'].items());assert all(sha(ROOT/v['file'])==v['sha256'] for v in export['exports'])
    result=dict(status='CORRECTED_ACTUAL_CAMERA_CEILING_VIEWS_RENDERED',source_blend=source.relative_to(ROOT).as_posix(),source_sha256=r['derived_sha256'],
        source_study_receipt_sha256=sha(DOC/'pilot-preview-r03/receipt.json'),camera_source_receipt_sha256=sha(DOC/'pilot-preview-r02/receipt.json'),
        export_receipt_sha256=sha(DOC/'export-r03/audit_export.json'),export_hashes={v['name']:v['sha256'] for v in export['exports']},
        failure='The generated ceiling mesh and ceiling camera shared a name prefix. The old postprocess selected the mesh object, producing an invalid camera render. Both old r03 ceiling images are rejected.',
        correction='Select exactly one object of type CAMERA by its pinned original matrix and lens. Assert CAMERA again before rendering. Original geometry and all files remain unchanged; no Blend save.',
        frames=frames,tool_sha256=sha(__file__),boundary='Two actual corrected offline ceiling frames only. Six non-ceiling r03 frames remain separate retained evidence. Native camera/lantern acceptance still required.')
    (out/'receipt.json').write_text(json.dumps(result,indent=2)+'\n');print('CEILING_CAMERA_CORRECTED',sha(out/'receipt.json'))
if __name__=='__main__':main()
