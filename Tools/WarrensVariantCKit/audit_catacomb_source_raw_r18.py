"""Offline audit of every preserved original export from the discarded R17 stage."""
import difflib
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def main():
    tool=ROOT/'Tools/WarrensVariantCKit/catacomb_source_room_r18.py'
    spec=importlib.util.spec_from_file_location('r18_pure_raw',tool);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    run=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
    before=json.loads((run/'source_room_checkpoint_r17.json').read_text())['snapshot'];manifest=m.manifest();folder=run/'source_room_r17/staged';checked=0
    for name,row in before['roster'].items():
        for rec,cn in [(row['raw'],None)]+[(c['raw'],cn) for cn,c in row['components'].items()]:
            old=(ROOT/rec['file']).read_text();new=(folder/Path(rec['file']).name).read_text();label=row['label']
            if name=='Ck_EntitySpawner_UE_0':old=old.replace(m.full(manifest['forage_profile']['before']),m.full(manifest['forage_profile']['after']))
            for r in manifest['material_bindings']:
                if r['actor_label']==label:old=old.replace(m.full(r['before']),m.full(r['after']))
            for r in manifest['source_light_intensities']:
                if r['actor_label']==label:old=old.replace('Intensity='+format(r['before'],'.6f'),'Intensity='+format(r['after'],'.6f'))
            x=m._allowed_raw(old,label,manifest,name,cn);y=m._allowed_raw(new,label,manifest,name,cn)
            assert x==y,(label,cn,list(difflib.unified_diff(x.splitlines(),y.splitlines(),n=0)))
            checked+=1
    old=(ROOT/before['script']['file']).read_text().replace(m.full(manifest['forage_profile']['before']),m.full(manifest['forage_profile']['after']))
    assert old==(folder/'forage_script.t3d').read_text();checked+=1;assert checked==115
    out=run/'source_room_raw_filter_proof_r18b.json';assert not out.exists()
    result=dict(status='ALL115_PRIOR_STAGED_EXPORTS_EXACT_AFTER_NARROW_EXPECTED_DATA_RULES',checked=checked,tool_sha256=hashlib.sha256(tool.read_bytes()).hexdigest(),changes='12expectedappends,4exactslot0overrides,3intensities,1profile; only4appendHISM knownbuildbounds caches excluded',engine_source='HierarchicalInstancedStaticMesh.cpp2485-2487; header169-175',boundary='Offline discarded-stage raw evidence only. No source success/save/reopen claim.')
    out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));print(hashlib.sha256(out.read_bytes()).hexdigest())

if __name__=='__main__':main()
