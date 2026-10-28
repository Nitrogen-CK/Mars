"""Correct excessive local studio irradiance; no geometry/material/native writes."""
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
    p=argparse.ArgumentParser();p.add_argument('--target',choices=('Diorama','KitLibrary'),required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);target=a.target
    previous=DOC/'catacomb-library-sync-r23'/target;r=json.loads((previous/'receipt.json').read_text());source=ROOT/r['candidate'];assert Path(bpy.data.filepath).resolve()==source.resolve() and sha(source)==r['candidate_sha256']
    out=DOC/'catacomb-library-sync-r24'/target;out.mkdir(parents=True,exist_ok=False);active=bpy.context.window.scene
    lamps=[]
    for obj in bpy.data.objects:
        if obj.type=='LIGHT' and obj.name.startswith('CP23_'):
            assert obj.get('Owner')=='Mars.WarrensVariantC.LibraryViews.R23';old=obj.data.energy;obj.data.energy=old/32;lamps.append(dict(object=obj.name,before=old,after=obj.data.energy))
    assert len(lamps)==16
    for row in r['frames']:
        s=bpy.data.scenes[row['scene']]
        if row['view'].endswith('_detail'):
            labels=[c for c in s.collection.children if c.name.startswith('CP22_') and c.name.endswith('_Labels')];assert len(labels)==1;s.collection.children.unlink(labels[0])
    candidate=out/('WarrensVariantC_'+target+'_Catacomb_R24.blend');bpy.ops.wm.save_as_mainfile(filepath=str(candidate),compress=True,relative_remap=False)
    frames=[]
    for row in r['frames']:
        s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;bpy.context.view_layer.update();s.render.filepath=str(out/row['file']);bpy.ops.render.render(write_still=True);frames.append(dict(row,sha256=sha(out/row['file'])))
    bpy.context.window.scene=active;bpy.context.view_layer.update()
    report=dict(r,status='STUDIO_IRRADIANCE_CALIBRATED_REOPEN_AUDIT_PENDING',source=source.relative_to(ROOT).as_posix(),source_sha256=sha(source),candidate=candidate.relative_to(ROOT).as_posix(),candidate_sha256=sha(candidate),writer_sha256=sha(__file__),prior_receipt_sha256=sha(previous/'receipt.json'),frames=frames,studio_lamps=lamps,removed_redundant_detail_captions=True,boundary='Only16CP23-owned new presentation lights divided by32 and redundant new detail label collection links removed. Art, poses, original scenes and original four files unchanged. Independent complete reopen audit required.')
    (out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('CALIBRATED_VIEWS_READY',target,sha(out/'receipt.json'))
if __name__=='__main__':main()
