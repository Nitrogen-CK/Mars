"""Finite PIE-only skin isolation; restores every transform at the same index."""
import json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
STATE=None

def isolate(trial,family,tag='r03'):
    global STATE
    import unreal as u
    assert STATE is None and family in ('floor','ceiling')
    assert hashlib.sha256((DOC/'TRIAL_DIAGNOSTIC_ADDENDUM_R01.json').read_bytes()).hexdigest()=='757061a66149d091ded0b5454dd2ecce1f6805d5871a63e8bd6f299899779cd1'
    world=trial.STATE['world'];assert u.GameplayStatics.is_game_paused(world)
    core=trial.STATE['core'];_,before=core._hism_snapshot(world)
    manifest=json.loads((DOC/'geometry-r05/room_geometry.json').read_text())
    fit=json.loads((ROOT/'Tools/WarrensVariantCKit/Output/fitted_instances.json').read_text())['placements']
    role='source floor veneer' if family=='floor' else 'source ceiling underside'
    rows=[(k,fit[k]) for k in manifest['superseded_fit_keys'] if fit[k]['role']==role]
    components=[c for a in u.GameplayStatics.get_all_actors_of_class(world,u.Actor) if 'LI_Warrens_Catacomb' in a.get_path_name() for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent) if '_CCS13_' in c.static_mesh.get_name()]
    assert rows and len(components)==2
    matches=[]
    for key,row in rows:
        expected=u.Vector((row['at'][0]-70)*100,(row['at'][1]-55)*100,row['at'][2]*100)
        found=[(c,i,c.get_instance_transform(i,world_space=True)) for c in components for i in range(c.get_instance_count()) if (c.get_instance_transform(i,world_space=True).translation-expected).length()<.01]
        c,i,t=found.pop();assert not found
        assert row['collision']=='NoCollision' and c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
        assert (t.scale3d-u.Vector(*row['scale'])).length()<.001
        matches.append((c,i,c.get_instance_transform(i,world_space=False),key))
    assert len({(c.get_path_name(),i) for c,i,t,k in matches})==len(rows)
    receipt=dict(family=family,status='ISOLATION_PREFLIGHT',instances=[dict(component=c.get_path_name(),index=i,fit_key=k,original_transform=t.export_text()) for c,i,t,k in matches])
    assert tag in ('r03','r04')
    path=ROOT/('Saved/WarrensCGameplay-20261024/CatacombPilot/skin_'+family+'_diagnostic_'+tag+'.json');assert not path.exists()
    path.write_text(json.dumps(receipt,indent=2)+'\n')
    STATE=dict(trial=trial,before=before,rows=matches,family=family)
    for c,i,t,k in matches:
        zero=c.get_instance_transform(i,world_space=False);zero.scale3d=u.Vector(0,0,0)
        assert c.update_instance_transform(i,zero,world_space=False,mark_render_state_dirty=True,teleport=True)
    trial.STATE['stage']='H_'+family+'_old_veneer_isolation'
    print('FINITE_SKIN_ISOLATED',family,len(matches))

def restore():
    global STATE
    assert STATE is not None
    s=STATE
    for c,i,t,k in s['rows']:
        assert c.update_instance_transform(i,t,world_space=False,mark_render_state_dirty=True,teleport=True)
    _,after=s['trial'].STATE['core']._hism_snapshot(s['trial'].STATE['world'])
    assert after==s['before'],'Exact full HISM snapshot differs after diagnostic restoration'
    print('FINITE_SKIN_EXACT_SNAPSHOT_RESTORED',s['family'],len(s['rows']))
    STATE=None
