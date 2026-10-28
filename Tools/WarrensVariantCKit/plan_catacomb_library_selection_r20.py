"""Pure-data library selection; no Blender or Unreal mutations."""
import copy
import hashlib
import json
import math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
def read(p):return json.loads(Path(p).read_text())
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def rotation(q):
    x,y,z,w=q
    return [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)], [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)], [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
def matrix_blender(p):
    q=p['q'];r=rotation([-q[0],q[1],-q[2],q[3]]);at=[p['at'][0]/100,-p['at'][1]/100,p['at'][2]/100]
    return [[r[i][j]*p['scale'][j] for j in range(3)]+[at[i]] for i in range(3)]+[[0,0,0,1]]
def main():
    m=read(DOC/'SOURCE_RETENTION_MANIFEST_R17.json');source=read(RUN/'source_room_saved_r18.json')['snapshot'];dio=read(RUN/'library_inventory_r20/Diorama/inventory.json');kit=read(RUN/'library_inventory_r20/KitLibrary/inventory.json')
    shift=[-8600,-1500,0];splits=[];refs={}
    for row in m['material_bindings']:
        src,=[r for r in source['hisms'].values() if r['mesh']==row['mesh']];assert len(src['instances'])==1
        expected=copy.deepcopy(src['instances'][0]);expected['at']=[a+b for a,b in zip(expected['at'],shift)]
        matches=[]
        for path,r in dio['hisms'].items():
            if r['mesh']!=row['mesh']:continue
            for i,pose in enumerate(r['instances']):
                if max(abs(a-b) for a,b in zip(pose['at'],expected['at']))<.001 and max(abs(a-b) for a,b in zip(pose['scale'],expected['scale']))<.00001 and abs(abs(sum(a*b for a,b in zip(pose['q'],expected['q'])))-1)<.000001:matches.append((path,r,i,pose))
        path,before,index,pose=matches.pop();assert not matches and index==len(before['instances'])-1
        ident=next(k for k in ('WVC026','WVC052','WVC053','WVC081') if k in row['mesh']);witnesses={}
        for label in ('Diorama','KitLibrary'):
            p=RUN/'library_inventory_r20'/('Blender_'+label+'_scenes.json');refs[p.relative_to(ROOT).as_posix()]=sha(p);data=read(p)
            for scene in ('02_VariantC_Cutaway','Zone_Catacomb'):
                witness=data['scenes'][scene]['witnesses'][ident];want=matrix_blender(pose)
                error=max(abs(a-b) for r1,r2 in zip(want,witness['world']) for a,b in zip(r1,r2));assert error<.00001
                witnesses[label+'/'+scene]=dict(object=witness['name'],collection=witness['instance'],world=witness['world'],max_matrix_error=error)
        splits.append(dict(ident=ident,component=path,index=index,before_count=len(before['instances']),before=before,source_pose=src['instances'][0],diorama_pose=pose,material_slot=row['slot'],material_after=row['after'],blender_witnesses=witnesses))
    assert len(splits)==4
    bounds=read(RUN/'library_inventory_r20/KitLibrary/occupied_bounds.json');blends=[read(RUN/'library_inventory_r20'/('Blender_'+k+'_kit_bounds.json')) for k in ('Diorama','KitLibrary')]
    old_edge=max(-bounds['lo'][1]/100,*[r['hi'][1] for r in blends]);half=1.325;row_y=old_edge+7+half
    names=['Fig','Censer','Bellnut','Tomb','Lid','Bone','Urn','Walls','Floor','Ceiling','TimberPost','TimberArm']
    cells=[dict(role=n,centre_native_cm=[350+700*i,-row_y*100,0],centre_blender_metres=[3.5+7*i,row_y,0]) for i,n in enumerate(names)]
    for p in ('library_inventory_r20/Diorama/inventory.json','library_inventory_r20/KitLibrary/inventory.json','library_inventory_r20/KitLibrary/occupied_bounds.json','library_inventory_r20/candidate_mesh_bounds.json','baseline_guard_after_source_room_r19.json','candidate_assets_timber_r13.json'):
        f=RUN/p;refs[f.relative_to(ROOT).as_posix()]=sha(f)
    result=dict(status='CONCRETE_LIBRARY_SELECTION_PROPOSAL_NOT_STAGED',inputs=refs,source_to_diorama_translation_cm=shift,source_to_main_translation_cm=m['source_main_offset_cm'],diorama_splits=splits,fixture_appends=m['append_hism_instances'],retained_source_actors=m['new_actors'],kit_cells=cells,old_occupied_front_blender_y=old_edge,new_exhibit_half_y=half,new_front_clearance_metres=row_y-half-old_edge,ceiling_display_bottom_cm=200,veneer_display_scale=.1,policy=dict(diorama='Roofless cutaway; walls/floor only. Static Fig exemplar, not a random-result claim.',kit='Three static forage variants, four prop variants, three veneer displays, two timber samples; original grid/cameras unchanged; dedicated review cameras.',complete_blender_view='Separate full ceiling room scene. Original object geometry, material graphs and unrelated poses remain exact.',carried_forward='Earlier native Diorama Sluice sync remains outstanding; Catacomb-only synchronization cannot close it.'))
    out=DOC/'LIBRARY_SELECTION_R20.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print('CONCRETE_LIBRARY_SELECTION',sha(out),[(r['ident'],r['index'],r['before_count']) for r in splits],row_y)
if __name__=='__main__':main()
