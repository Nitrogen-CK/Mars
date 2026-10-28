"""Refit only the reviewed P2 source delta with the established surface fitter.

The original fitted ledger and whole-level library are read-only. Output is an
exact removal/addition ledger for the scoped live-map patch, plus provenance.
"""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
KIT = HERE.parent
OUT = HERE/'Output'
REVIEW = ROOT/'docs/art/warrens-c-gameplay-review-20261024'


def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))


def key(row):
    return (row['tile'],row['id'],tuple(round(v,6) for v in row['at']),
            tuple(round(v,6) for v in row['scale']),
            tuple(round(v,6) for v in row.get('rotation',[0,row.get('yaw',0),0])),
            row.get('material'),row.get('material_path'))


def normalize(rows):
    result = {}
    for source in rows:
        row = copy.deepcopy(source)
        if row['id']=='BACKING': row['id']='BACKING_'+row['material']
        if row['id']=='CCS18' and row['role']=='source ceiling underside':
            row.update(id='CCS13',material='TX01',rotation=[180,0,0])
            row['at'][2]+=.146
            row['scale'][2]=1
        if row.get('material') and not row['id'].startswith('BACKING'):
            row['mesh_id']=row['id']
            row['id']+='_'+row['material']
        result.setdefault(key(row),row)
    return result


def main():
    baseline_path = KIT/'Output/Reports/full_source_baseline.json'
    baseline = read(baseline_path)
    tiles = ['WaterworksW','Canal','Brineworks']
    specs = {tile:dict(baseline_path=baseline_path,pivot=baseline[tile]['pivot']) for tile in tiles}
    spec = importlib.util.spec_from_file_location('p2_surface_fitter',ROOT/'Tools/PumpCisternKit/surface_fitting.py')
    surface = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(surface)
    original = surface.load_boxes(specs)
    section = read(ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c_p2_section.json')
    revised = copy.deepcopy(original)
    replacements = [(r['source'],r['replacements']) for r in section['splits']]
    replacements += [(r,[]) for r in section['removed_boxes']]
    for source,fragments in replacements:
        tile = 'WaterworksW' if source['tile']=='Waterworks-W' else source['tile']
        matches = [i for i,b in enumerate(revised[tile])
                   if b['label']=='Warrens_Greybox_'+source['kind']
                   and max(abs(b['at'][k]-source['centre'][k]) for k in range(3))<.001
                   and max(abs(b['size'][k]-source['size'][k]) for k in range(3))<.001
                   and max(abs(b['rotation'][k]-[source['pitch'],source['yaw'],0][k]) for k in range(3))<.001]
        assert len(matches)==1,(source,matches)
        index = matches[0]
        old = revised[tile][index]
        pieces = []
        for i,fragment in enumerate(fragments):
            c,s = fragment['centre'],fragment['size']
            pieces.append(dict(key='P2:'+str(source['index'])+':'+str(i),label=old['label'],at=c,size=s,
                rotation=[fragment['pitch'],fragment['yaw'],0],
                lo=[c[k]-s[k]/2 for k in range(3)],hi=[c[k]+s[k]/2 for k in range(3)]))
        revised[tile][index:index+1]=pieces
    for row in section['added_boxes']:
        tile = 'WaterworksW' if row['centre'][0]<70 else 'Canal'
        c,s = row['centre'],row['size']
        revised[tile].append(dict(key='P2:'+row['name'],label='Warrens_Greybox_'+row['kind'],at=c,size=s,
            rotation=[row['pitch'],row['yaw'],0],lo=[c[k]-s[k]/2 for k in range(3)],hi=[c[k]+s[k]/2 for k in range(3)]))
    outputs = []
    for boxes in (original,revised):
        # Same classification policy as fitted_placement.py.
        for values in boxes.values():
            for box in values:
                if box['label']=='Warrens_Greybox_gallery' and min(box['size'][:2])>.11 and box['size'][2]<=.5:
                    box['label']='Warrens_Greybox_floor'
        surface.load_boxes = lambda unused=None,boxes=boxes: boxes
        outputs.append(normalize(surface.build(specs)['placements']))
    old,new = outputs
    ledger_path = KIT/'Output/fitted_instances.json'
    ledger = read(ledger_path)
    existing = {key(r):r for r in ledger['placements']}
    missing = set(old)-set(existing)
    assert not missing,('Fitter no longer matches source ledger',len(missing))
    remove = {k:existing[k] for k in set(old)-set(new)}
    add = {k:row for k,row in new.items() if k not in old and k not in existing}
    membership = read(REVIEW/'P2_ART_MEMBERSHIP.json')
    for name in ('old_ramp_surface_art','legacy_span_fascia_and_ribs',
                 'legacy_static_gate_guides_and_surround','old_span_lamp_assemblies'):
        for row in membership['sets'][name]['placements']:
            k = key(row)
            assert k in existing,(name,row)
            remove[k]=existing[k]
    audit = read(REVIEW/'P2_ART_DELTA.json')
    # Source veneers have been refit, rather than cropped as detailed meshes.
    # Remaining local detail within the new opening/sweep is removed explicitly.
    for row in audit['cut_or_sweep_art_hits']['placements']:
        k = key(row)
        if not row['role'].startswith('source ') and k in existing:
            remove[k]=existing[k]
    flames = [row for row in membership['sets']['old_span_lamp_assemblies']['placements'] if row['id']=='CCS64']
    lights = [dict(index=i,**row) for i,row in enumerate(ledger['lights'])
              if any(row['tile']==f['tile'] and sum((row['at'][k]-f['at'][k])**2 for k in range(3))<.5**2 for f in flames)]
    report = dict(source_ledger_sha256=hashlib.sha256(ledger_path.read_bytes()).hexdigest(),
        section_sha256=hashlib.sha256((ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c_p2_section.json').read_bytes()).hexdigest(),
        removed=list(remove.values()),added=list(add.values()),removed_lights=lights,
        source_boxes_matched=len(replacements),method='Existing source fitter before/after exact section, transform-set delta; explicit old span/control membership removal.',
        boundary='NoCollision local artwork. Detailed new surfaces refit from residual source solids; runtime visual/collision acceptance separate.')
    (OUT/'art_delta.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({k:len(report[k]) for k in ('removed','added','removed_lights')}))
    return report


if __name__=='__main__': main()
