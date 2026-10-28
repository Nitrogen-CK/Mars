"""Derived ceiling completion on witnessed existing room-top solids only."""
import copy,hashlib,importlib.util,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    source=BASE/'larder-native-r09/room_regions.json';r=json.loads(source.read_text());before=copy.deepcopy(r);assert r['room']['id']=='larder' and r['room']['top']==12 and len(r['ceiling_faces'])==132
    out=BASE/'larder-native-r12';assert not out.exists();top=12.;old={tuple(c['cell']) for c in r['ceiling_faces']};new=[];skips=[];clipped=[]
    helper=Path(__file__).with_name('room_surface_regions_r03.py');assert sha(helper)=='f55ac26b73f6781183d72fe86bf097d094b754c0f8cff9a6d84e3599f7c682b4';spec=importlib.util.spec_from_file_location('_roof_rectangles',helper);g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)
    for cell in r['admitted_floor_cells']:
        if tuple(cell['cell']) in old:continue
        rect=cell['rect'];overhead=[b for b in r['source_boxes'] if cell['z']+.05<b['lo'][2]<=top+1e-6 and all(b['lo'][k]-1e-7<=rect[k] and b['hi'][k]+1e-7>=rect[k+2] for k in (0,1))]
        if not overhead:skips.append(dict(cell=cell['cell'],reason='NO_FULL_CELL_PHYSICAL_OVERHEAD_SOLID'));continue
        witnesses=sorted(b['key'] for b in overhead if abs(b['lo'][2]-top)<1e-6)
        if not witnesses:skips.append(dict(cell=cell['cell'],reason='NO_FULL_CELL_ROOM_TOP_SUPPORT'));continue
        parts=[rect];occluders=[]
        # Every intermediate solid's positive-area projection is subtracted,
        # including solids that cover only part of an owned floor cell.
        for b in r['source_boxes']:
            if not cell['z']+.05<b['lo'][2]<top-1e-6:continue
            cut=[b['lo'][0],b['lo'][1],b['hi'][0],b['hi'][1]]
            if g.intersection(rect,cut) is None:continue
            occluders.append(b['key']);parts=[q for part in parts for q in g.subtract(part,cut)]
        if occluders:clipped.append(dict(cell=cell['cell'],source_solids=occluders,remaining_rectangles=parts))
        if not parts:skips.append(dict(cell=cell['cell'],reason='INTERMEDIATE_PHYSICAL_SOLID_COVERS_FOOTPRINT'));continue
        new.extend(dict(cell=cell['cell'],rect=part,z=top,source_solids=witnesses) for part in parts)
    assert new
    r['ceiling_faces']+=new;new_ids={tuple(c['cell']) for c in new};r['source_open_overhead_cells']=[c for c in r['source_open_overhead_cells'] if tuple(c) not in new_ids]
    ray=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/native-corrections-r10/roof_vertical_mesh_attribution_r01.json';actual=json.loads(ray.read_text());assert actual['rays'][0]['hits'][0]['plan_hit'][2]==12.000000000000002
    r['inputs'].update({source.relative_to(ROOT).as_posix():sha(source),ray.relative_to(ROOT).as_posix():sha(ray)})
    r['finite_ceiling_supplement']=dict(kind='FIRST_PHYSICAL_SOLID_AT_AUTHORED_ROOM_TOP_WITH_PARTIAL_OCCLUDER_SUBTRACTION',z=top,added_footprints=len(new),added_cells=len(new_ids),unchanged_local_ceiling_cells=132,skipped=skips,partial_and_full_occluder_subtractions=clipped,tool_sha256=sha(__file__),rectangle_helper_sha256=sha(helper),boundary='Existing physical room-top underside only, exact owned floor-cell fragments after all intermediate positive-area solid projections are subtracted. Source holes and intermediate roofs preserved. No source box, floor, wall, ownership, connector, light or physics edit.')
    for k in ['room','owned_niches','water','ownership','source_boxes','admitted_floor_cells','excluded_transition_cells','wall_faces','connector_regions']:assert r[k]==before[k]
    assert r['ceiling_faces'][:132]==before['ceiling_faces'];out.mkdir();f=out/'room_regions.json';f.write_text(json.dumps(r,indent=2)+'\n');print('HIGH_ROOF_DERIVED',len(new),'added; total',len(r['ceiling_faces']),sha(f))
if __name__=='__main__':main()
