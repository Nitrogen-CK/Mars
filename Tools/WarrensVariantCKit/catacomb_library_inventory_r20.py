"""Read-only original native library inventory and datum witnesses."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/library_inventory_r20'
MAPS={k:'/Game/Mars/Environment/WarrensVariantCKit/Maps/WarrensVariantC_'+k+'_Mars_MAP' for k in ('Diorama','KitLibrary')}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def capture(target,source):
    import unreal as u
    assert target in MAPS;ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None
    w=ed.get_editor_world();assert w.get_path_name().split('.')[0]==MAPS[target]
    source.guard();assert source.STATE['source'].dirty()==dict(maps=[],content=[])
    folder=RUN/target;assert not folder.exists();base,core=source.STATE['source'].dependencies()
    roster,hisms=base._roster(u,core,w,folder/'exports')
    selected={p:r for p,r in hisms.items() if any(k in r['mesh'] for k in ('WVC026','WVC052','WVC053','WVC081','CCS60','CCS61','CCS62','CCS64'))}
    disk=ROOT/('Content/'+MAPS[target].removeprefix('/Game/')+'.umap')
    result=dict(status='READ_ONLY_ORIGINAL_NATIVE_LIBRARY_INVENTORY',target=target,map=MAPS[target],map_sha256=sha(disk),actor_count=len(roster),hism_count=len(hisms),instance_count=sum(len(r['instances']) for r in hisms.values()),roster=roster,hisms=hisms,datum_candidates=selected,boundary='Original library unchanged. Actor/component exports and complete HISM metadata/poses provide before data; no staging, save, import or collision cook.')
    out=folder/'inventory.json';out.write_text(json.dumps(result,indent=2)+'\n')
    source.guard();assert source.STATE['source'].dirty()==dict(maps=[],content=[])
    print('ORIGINAL_LIBRARY_INVENTORY',target,len(roster),len(hisms),result['instance_count'],sha(out))
