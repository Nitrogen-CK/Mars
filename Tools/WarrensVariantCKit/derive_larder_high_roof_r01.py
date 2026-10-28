"""Derived ceiling completion on witnessed existing room-top solids only."""
import copy,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    source=BASE/'larder-native-r09/room_regions.json';r=json.loads(source.read_text());before=copy.deepcopy(r);assert r['room']['id']=='larder' and r['room']['top']==12 and len(r['ceiling_faces'])==132
    out=BASE/'larder-native-r11';assert not out.exists();top=12.;old={tuple(c['cell']) for c in r['ceiling_faces']};new=[];skips=[]
    for cell in r['admitted_floor_cells']:
        if tuple(cell['cell']) in old:continue
        rect=cell['rect'];overhead=[b for b in r['source_boxes'] if cell['z']+.05<b['lo'][2]<=top+1e-6 and all(b['lo'][k]-1e-7<=rect[k] and b['hi'][k]+1e-7>=rect[k+2] for k in (0,1))]
        if not overhead:skips.append(dict(cell=cell['cell'],reason='NO_FULL_CELL_PHYSICAL_OVERHEAD_SOLID'));continue
        first=min(b['lo'][2] for b in overhead)
        if abs(first-top)>1e-6:skips.append(dict(cell=cell['cell'],reason='INTERMEDIATE_PHYSICAL_OVERHEAD',first_z=first));continue
        witnesses=sorted(b['key'] for b in overhead if abs(b['lo'][2]-top)<1e-6);assert witnesses
        new.append(dict(cell=cell['cell'],rect=rect,z=top,source_solids=witnesses))
    assert new
    r['ceiling_faces']+=new;new_ids={tuple(c['cell']) for c in new};r['source_open_overhead_cells']=[c for c in r['source_open_overhead_cells'] if tuple(c) not in new_ids]
    ray=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/native-corrections-r10/roof_vertical_mesh_attribution_r01.json';actual=json.loads(ray.read_text());assert actual['rays'][0]['hits'][0]['plan_hit'][2]==12.000000000000002
    r['inputs'].update({source.relative_to(ROOT).as_posix():sha(source),ray.relative_to(ROOT).as_posix():sha(ray)})
    r['finite_ceiling_supplement']=dict(kind='FIRST_PHYSICAL_SOLID_AT_AUTHORED_ROOM_TOP',z=top,added_cells=len(new),unchanged_local_ceiling_cells=132,skipped=skips,tool_sha256=sha(__file__),boundary='Existing physical room-top underside only, exact owned floor-cell footprint. Source holes and intermediate roofs preserved. No source box, floor, wall, ownership, connector, light or physics edit.')
    for k in ['room','owned_niches','water','ownership','source_boxes','admitted_floor_cells','excluded_transition_cells','wall_faces','connector_regions']:assert r[k]==before[k]
    assert r['ceiling_faces'][:132]==before['ceiling_faces'];out.mkdir();f=out/'room_regions.json';f.write_text(json.dumps(r,indent=2)+'\n');print('HIGH_ROOF_DERIVED',len(new),'added; total',len(r['ceiling_faces']),sha(f))
if __name__=='__main__':main()
