"""Independent process reopen: complete library snapshot and actual camera bounds."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def module(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_audit25_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def main():
    import bpy
    from bpy_extras.object_utils import world_to_camera_view
    from mathutils import Vector
    p=argparse.ArgumentParser();p.add_argument('--target',required=True,choices=('Diorama','KitLibrary'));p.add_argument('--revision',required=True,choices=('r23','r24'));p.add_argument('--captured-snapshot');p.add_argument('--captured-sha');a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);folder=DOC/('catacomb-library-sync-'+a.revision)/a.target;r=json.loads((folder/'receipt.json').read_text());candidate=ROOT/r['candidate'];assert Path(bpy.data.filepath).resolve()==candidate.resolve() and sha(candidate)==r['candidate_sha256']
    writer=module('stage_catacomb_blender_libraries_r21');sync=module('sync_art_libraries');writer.guards();active=bpy.context.window.scene;baseline=json.loads((ROOT/r['original_baseline']).read_text())
    if a.captured_snapshot:
        captured=(ROOT/a.captured_snapshot).resolve();assert captured.is_relative_to((RUN/'blender_library_audit_r25'/a.target).resolve()) and sha(captured)==a.captured_sha;snap=json.loads(captured.read_text())
    else:snap=writer.snapshot(sync)
    writer.assert_originals(baseline,snap,r['allowed_collection_reference_changes']);out=RUN/'blender_library_audit_r25'/a.target;out.mkdir(parents=True,exist_ok=True);report=out/(a.revision+'_reopen.json');assert not report.exists()
    if a.revision=='r24':
        prior_path=out/'r23_snapshot.json';prior=json.loads(prior_path.read_text());expected=copy.deepcopy(prior)
        for lamp in r['studio_lamps']:
            assert expected['lights'][lamp['object']]['energy']==lamp['before'];expected['lights'][lamp['object']]['energy']=lamp['after']
        for row in r['frames']:
            if row['view'].endswith('_detail'):
                name=row['scene'];old=expected['scenes'][name]['objects'];labels=[n for n in old if bpy.data.objects[n].type=='FONT'];assert len(labels)==1;expected['scenes'][name]['objects']=[n for n in old if n not in labels]
                # Saving discards the three now-unreferenced NEW label collections;
                # Blender retains their FONT objects as loose data on this reload.
                col=name+'_Labels';assert expected['collections'][col]==dict(objects=labels,children=[]);expected['collections'].pop(col)
                for n in labels:assert expected['objects'][n]['collections']==['collection:'+col];expected['objects'][n]['collections']=[]
        if expected!=snap:
            debug=out/'r24_unvalidated_snapshot.json';assert not debug.exists();debug.write_text(json.dumps(snap,separators=(',',':'))+'\n')
            changes=[]
            def diff(x,y,path=''):
                if type(x)!=type(y):changes.append(path+': type');return
                if isinstance(x,dict):
                    for k in x.keys()|y.keys():
                        if k not in x or k not in y:changes.append(path+'/'+k+': added/removed')
                        else:diff(x[k],y[k],path+'/'+k)
                elif x!=y:changes.append(path+': '+str(x)[:100]+' -> '+str(y)[:100])
            diff(expected,snap);(out/'r24_unvalidated_delta.json').write_text(json.dumps(changes,indent=2)+'\n');raise AssertionError(str(changes[:20]))
    camera_rows=[]
    for row in r['frames']:
        s=bpy.data.scenes[row['scene']];bpy.context.window.scene=s;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();projected=[]
        for item in deps.object_instances:
            if item.object.type not in ('MESH','FONT') or item.object.hide_render:continue
            projected.extend(world_to_camera_view(s,s.camera,item.matrix_world@Vector(v)) for v in item.object.bound_box)
        assert projected and all(p.z>0 and -.001<=p.x<=1.001 and -.001<=p.y<=1.001 for p in projected),('Camera clips bounds',row['view'])
        camera_rows.append(dict(view=row['view'],matrix=[list(v) for v in s.camera.matrix_world],projected_min=[min(p[i] for p in projected) for i in range(3)],projected_max=[max(p[i] for p in projected) for i in range(3)],corrects_stale_preupdate_receipt=True))
    bpy.context.window.scene=active;bpy.context.view_layer.update();writer.guards();snapshot_file=out/(a.revision+'_snapshot.json');assert not snapshot_file.exists();snapshot_file.write_text(json.dumps(snap,separators=(',',':'))+'\n')
    result=dict(status='INDEPENDENT_PROCESS_REOPEN_LIBRARY_AND_CAMERA_BOUNDS_ACCEPTED',target=a.target,revision=a.revision,candidate=r['candidate'],candidate_sha256=sha(candidate),snapshot=snapshot_file.relative_to(ROOT).as_posix(),snapshot_sha256=sha(snapshot_file),audit_tool_sha256=sha(__file__),original_meshes_unchanged=len(baseline['meshes']),original_materials_unchanged=len(baseline['materials']),original_objects_unchanged_except_8_collection_references=len(baseline['objects']),all_original_scene_settings_preserved=True,exact_r23_to_r24_delta=a.revision=='r24',actual_camera_bounds=camera_rows,boundary='Read-only camera metadata correction. Native photometry/pixel parity not claimed; original four files remain unchanged.')
    report.write_text(json.dumps(result,indent=2)+'\n');print('REOPEN_AUDIT_OK',a.target,a.revision,sha(report))
if __name__=='__main__':main()
