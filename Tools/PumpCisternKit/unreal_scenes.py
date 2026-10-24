"""Owned source-fitted Waterworks dressing and reusable review maps.

No collision or gameplay writes. Original tile backups remain the rollback.
Open each target with guarded Monolith load_level before calling these functions.
"""
import importlib.util
import json
from pathlib import Path
import unreal as u

HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
DEST='/Game/Mars/Environment/PumpCisternKit'
SHARED='/Game/Mars/Environment/ChainCrossingKit'
OWNER='Mars.PumpCisternKit.Authoring.v1'
spec=importlib.util.spec_from_file_location('waterworks_scene_core',HERE.parent/'ChainCrossingKit/unreal_scenes.py')
core=importlib.util.module_from_spec(spec);spec.loader.exec_module(core)
core.OWNER=OWNER;core.PREFIX='PWC_';core.FOLDER='PumpCisternKit'

def registry():
    paths={r['id']:DEST+'/Meshes/'+r['name'] for r in json.loads((OUT/'asset_manifest.json').read_text())['assets']}
    paths.update({r['id']:SHARED+'/Meshes/'+r['name'] for r in json.loads((HERE.parent/'ChainCrossingKit/Output/asset_manifest.json').read_text())['assets']})
    paths.update({k:'/Engine/BasicShapes/Cube' for k in ['BACKING_TX01','BACKING_TX02','SOURCE_GALLERY']})
    return paths

def dress(tile):
    assert not any('Mars.WarrensVariantCKit.Authoring.v1' in [str(t) for t in a.tags] for a in core.EA.get_all_level_actors()),'This tile is owned by the complete Variant C pass; use WarrensVariantCKit/unreal_scenes.py'
    core.clean()
    data=json.loads((OUT/'fitted_instances.json').read_text());assert tile in data['pivots']
    base_path=OUT/'Reports/level_baseline.json' if tile=='Hub' else HERE.parent/'ChainCrossingKit/Output/Reports/level_baseline.json'
    base=json.loads(base_path.read_text())[tile]
    assert Path(base['backup']).is_file()
    assert core.ED.get_editor_world().get_path_name().split('.')[0]==base['asset']
    original={a.get_actor_label():a for a in core.EA.get_all_level_actors()}
    expected={a['label'] for a in base['actors'] if a['label'].startswith('Warrens_') or a['components']}
    assert expected.issubset(original),expected-set(original)
    core.clear_owned()
    counts=core.add_instances([p for p in data['placements'] if p['tile']==tile],data['pivots'][tile],True,registry(),SHARED)
    for change in data['visibility_overrides']:
        if change['tile']!=tile:continue
        a=original[change['label']];a.set_actor_hidden_in_game(not change['visible'])
        for c in a.get_components_by_class(u.InstancedStaticMeshComponent):
            c.set_visibility(change['visible'],False);c.set_hidden_in_game(not change['visible'],False)
    for change in data['light_overrides']:
        if change['tile']!=tile:continue
        a=original[change['label']];assert isinstance(a,u.PointLight)
        a.point_light_component.set_intensity(change['intensity'])
    for i,light in enumerate(data['lights']):
        if light['tile']!=tile:continue
        at=[light['at'][k]-data['pivots'][tile][k] for k in range(3)]
        core.light('Practical_'+str(i),at,light['intensity'],(1,.66,.34),light['radius'])
    assert core.LES.save_current_level()
    report=dict(tile=tile,asset=base['asset'],instances=sum(counts.values()),unique_meshes=len(counts),counts=counts,backup=base['backup'],collision='NoCollision',coverage=data['coverage']['tiles'][tile])
    (OUT/'Reports'/('dressed_'+tile+'.json')).write_text(json.dumps(report,indent=2))
    print('PUMP_CISTERN_DRESSED',tile,report['instances'],report['unique_meshes'])
    return report

def preview_world(kind):
    core.clean();assert kind in ['KitLibrary','Diorama']
    path=DEST+'/Maps/PumpCistern_'+kind+'_Mars_MAP'
    assert core.ED.get_editor_world().get_path_name().split('.')[0]==path,'Open target through guarded Monolith first'
    assert all(OWNER in [str(t) for t in a.tags] for a in core.EA.get_all_level_actors()),'Refusing foreign authored actors'
    core.clear_owned();core.review_lighting()
    manifest=json.loads((OUT/'asset_manifest.json').read_text())
    if kind=='KitLibrary':
        ids=[r['id'] for r in manifest['assets']]+manifest['shared_reuse_ids']
        rows=[dict(id=k,at=[(i%8-3.5)*5,(i//8)*6,0]) for i,k in enumerate(ids)]
        for i,k in enumerate(ids):
            a=core.actor(u.TextRenderActor,'Label_'+k,[((i%8-3.5)*5)*100,-((i//8)*6-2)*100,10])
            a.text_render.set_text(k);a.text_render.set_world_size(35)
            a.set_actor_rotation(u.Rotator(pitch=55,yaw=90,roll=0),False)
        counts=core.add_instances(rows,registry=registry(),material_root=SHARED)
        core.camera('Library_Camera',(30,-36,42),(0,12,1))
        for x in [-15,0,15]:core.light('LibraryStudio',(x,8,12),60,(.86,.9,1),2200,True)
    else:
        rows=[p for p in json.loads((OUT/'fitted_instances.json').read_text())['placements'] if 'ceiling' not in p['role'] and p['id']!='SOURCE_GALLERY']
        counts=core.add_instances(rows,(38,28,-2.5),True,registry(),SHARED)
        core.camera('Diorama_Camera',(38,-50,54),(0,0,1))
        for x in [-20,0,20]:core.light('DioramaStudio',(x,0,10),50,(1,.78,.55),2600,True)
    assert core.LES.save_current_level()
    report=dict(map=path,instances=sum(counts.values()),unique_meshes=len(counts),counts=counts,collision='NoCollision')
    (OUT/'Reports'/('unreal_'+kind+'.json')).write_text(json.dumps(report,indent=2))
    print('PUMP_CISTERN_REVIEW_MAP',report['map'],report['instances']);return report
