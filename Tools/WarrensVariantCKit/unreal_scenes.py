"""Owned full-world artwork. Original route geometry and collision stay intact.

Rollback: close editor and restore only the11 checkpoint map copies listed in
Output/Reports/checkpoint.json. Guarded Monolith must open the target first.
"""
import importlib.util,json
from pathlib import Path
import unreal as u
HERE=Path(__file__).resolve().parent
OUT=HERE/'Output'
DEST='/Game/Mars/Environment/WarrensVariantCKit'
SHARED='/Game/Mars/Environment/ChainCrossingKit'
OWNER='Mars.WarrensVariantCKit.Authoring.v1'
OLD_OWNERS={'Mars.ChainCrossingKit.Authoring.v1','Mars.PumpCisternKit.Authoring.v1'}
s=importlib.util.spec_from_file_location('full_world_scene_core',HERE.parent/'ChainCrossingKit/unreal_scenes.py');core=importlib.util.module_from_spec(s);s.loader.exec_module(core)
core.OWNER=OWNER;core.PREFIX='WVC_';core.FOLDER='WarrensVariantCKit'
def save_visual_level():
    # This pass changes only NoCollision art, materials and lights. On-save
    # collision cooking of streamed temp worlds is unrelated and raises the
    # existing LevelIdentityIsStable ensure. Pause only this save callback;
    # restore the in-memory user setting immediately, never save its config.
    cls=u.load_class(None,'/Script/CkJoltEditor.Ck_JoltCook_UserSettings_UE');settings=u.get_default_object(cls)
    old=settings.get_editor_property('_AutoCookStaticWorldOnLevelSave')
    try:
        settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',type(old).DISABLE)
        assert core.LES.save_current_level()
    finally:settings.set_editor_property('_AutoCookStaticWorldOnLevelSave',old)
def registry():
    result={}
    for kit in ['ChainCrossingKit','PumpCisternKit','WarrensVariantCKit']:
        result.update({r['id']:'/Game/Mars/Environment/'+kit+'/Meshes/'+r['name'] for r in json.loads((HERE.parent/kit/'Output/asset_manifest.json').read_text())['assets']})
    for key in ['TX01','TX02','TX04','TX17']:result['BACKING_'+key]='/Engine/BasicShapes/Cube'
    result['SOURCE_CUBE_TX01']='/Engine/BasicShapes/Cube'
    result['SOURCE_CUBE_TX02']='/Engine/BasicShapes/Cube'
    for row in json.loads((OUT/'fitted_instances.json').read_text())['placements']:
        if row.get('mesh_id'):result[row['id']]=result[row['mesh_id']]
    return result

def dress(tile):
    core.clean();data=json.loads((OUT/'fitted_instances.json').read_text());base=json.loads((OUT/'Reports/full_source_baseline.json').read_text())[tile]
    paths=registry()
    for r in data['placements']:
        if r['tile']!=tile:continue
        assert u.load_asset(paths[r['id']]),paths[r['id']]
        if r.get('material'):assert u.load_asset(SHARED+'/Materials/M_CCK_'+r['material']),r['material']
    checkpoint=json.loads((OUT/'Reports/checkpoint.json').read_text())[tile] if tile!='Main' else base
    assert Path(checkpoint['backup']).is_file()
    assert core.ED.get_editor_world().get_path_name().split('.')[0]==base['asset'],'Guarded load target first'
    scope=[a for a in core.EA.get_all_level_actors() if a.get_path_name().startswith(base['asset']+'.')]
    for a in scope:
        if any(str(t) in OLD_OWNERS|{OWNER} for t in a.tags):assert core.EA.destroy_actor(a)
    originals={a.get_actor_label():a for a in core.EA.get_all_level_actors() if a.get_path_name().startswith(base['asset']+'.')}
    expected={a['label'] for a in base['actors'] if a['label'].startswith('Warrens_') or a['components']}
    assert expected.issubset(originals),expected-set(originals)
    # Restore previous pass's source visibility before applying the single
    # authoritative ownership/visibility ledger. Original meshes never change.
    for old in base['actors']:
        a=originals.get(old['label'])
        if not a:continue
        a.set_actor_hidden_in_game(old.get('hidden',False))
        comps={c.get_name():c for c in a.get_components_by_class(u.StaticMeshComponent)}
        for oldc in old['components']:
            c=comps[oldc['name']];c.set_visibility(oldc.get('visible',True),False);c.set_hidden_in_game(not oldc.get('visible',True),False)
    changes=[]
    stone={'floor':'TX02','wall':'TX01','roof':'TX01','ramp':'TX02','gallery':'TX09','water':'FX_Water','inlay':'TX09','root':'TX17','prop':'TX01','candle':'TX09','hearth':'TX09'}
    for label,a in originals.items():
        if not label.startswith('Warrens_Greybox_'):continue
        kind=label.removeprefix('Warrens_Greybox_');key=stone.get(kind)
        if not key:continue
        if kind=='wall' and tile in ['Pit','Catacomb','Main']:key='TX17'
        if kind=='floor' and tile in ['Ossuary','Reliquary']:key='TX04'
        mat=u.load_asset(SHARED+'/Materials/M_CCK_'+key);assert mat,key
        for c in a.get_components_by_class(u.StaticMeshComponent):
            for slot in range(max(1,c.get_num_materials())):c.set_material(slot,mat)
            changes.append(dict(actor=label,component=c.get_name(),material=mat.get_path_name()))
    for change in data['visibility_overrides']:
        if change['tile']!=tile:continue
        a=originals[change['label']];a.set_actor_hidden_in_game(not change['visible'])
        for c in a.get_components_by_class(u.StaticMeshComponent):c.set_visibility(change['visible'],False);c.set_hidden_in_game(not change['visible'],False)
    counts=core.add_instances([p for p in data['placements'] if p['tile']==tile],data['pivots'][tile],True,registry(),SHARED)
    for i,light in enumerate(data['lights']):
        if light['tile']==tile:core.light('Practical_'+str(i),[light['at'][k]-data['pivots'][tile][k] for k in range(3)],light['intensity'],light.get('color',(1,.66,.34)),light.get('radius',450))
    for spec in data['light_overrides']:
        if spec['tile']!=tile:continue
        a=originals[spec['label']];assert isinstance(a,u.PointLight);a.point_light_component.set_intensity(spec['intensity'])
    # Serialized per-placement opt-in, including dynamically chosen route gates.
    # Other levels and colored puzzle indicators retain their existing materials.
    gate_bindings=[];iron=u.load_asset(SHARED+'/Materials/M_CCK_TX09');assert iron
    for label,a in originals.items():
        if 'Spawner' not in a.get_class().get_name():continue
        script=a.get_editor_property('_EntityScript');name=script.get_class().get_name()
        prop='MaterialOverride' if name=='Mars_Gate_EntityScript' else 'GateMaterialOverride' if name.startswith('Mars_Anchor_') and name in ['Mars_Anchor_Route_EntityScript','Mars_Anchor_Spawn_EntityScript'] else None
        if prop:
            script.modify();script.set_editor_property(prop,iron)
            assert script.get_editor_property(prop)==iron
            gate_bindings.append(dict(actor=label,property=prop,material=iron.get_path_name()))
    save_visual_level()
    report=dict(tile=tile,asset=base['asset'],instances=sum(counts.values()),hism_groups=len(counts),counts=counts,material_overrides=changes,gate_bindings=gate_bindings,rollback=checkpoint['backup'])
    (OUT/'Reports'/('dressed_'+tile+'.json')).write_text(json.dumps(report,indent=2));print('VARIANT_C_DRESSED',tile,report['instances'],report['hism_groups']);return report

def update_glass_shadows(tile):
    core.clean();base=json.loads((OUT/'Reports/full_source_baseline.json').read_text())[tile]
    assert core.ED.get_editor_world().get_path_name().split('.')[0]==base['asset']
    count=0
    for a in core.EA.get_all_level_actors():
        if a.get_path_name().startswith(base['asset']+'.') and a.get_actor_label()=='WVC_CCS61' and OWNER in [str(t) for t in a.tags]:
            for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
                c.set_cast_shadow(False);count+=c.get_instance_count()
    if count:save_visual_level()
    print('VARIANT_C_GLASS_SHADOWS',tile,count)

def preview_world(kind):
    core.clean();assert kind in ['KitLibrary','Diorama']
    path=DEST+'/Maps/WarrensVariantC_'+kind+'_Mars_MAP'
    assert core.ED.get_editor_world().get_path_name().split('.')[0]==path
    assert all(OWNER in [str(t) for t in a.tags] for a in core.EA.get_all_level_actors()),'Foreign review-map content'
    core.clear_owned();core.review_lighting()
    for a in core.EA.get_all_level_actors():
        if a.get_actor_label()=='WVC_ReviewKey':a.light_component.set_intensity(12)
        if a.get_actor_label()=='WVC_ReviewSky':a.light_component.set_intensity(2)
    if kind=='KitLibrary':
        m=json.loads((OUT/'asset_manifest.json').read_text());ids=[r['id'] for r in m['assets']+m['shared_assets']]
        rows=[dict(id=k,at=[(i%14-6.5)*7,(i//14)*7,0]) for i,k in enumerate(ids)]
        core.camera('Library_Camera',(50,-40,55),(0,45,0))
        for i,k in enumerate(ids):
            a=core.actor(u.TextRenderActor,'Label_'+k,[((i%14-6.5)*7)*100,-((i//14)*7-2)*100,10]);a.text_render.set_text(k);a.text_render.set_world_size(40);a.set_actor_rotation(u.Rotator(pitch=55,yaw=90,roll=0),False)
        counts=core.add_instances(rows,registry=registry(),material_root=SHARED)
    else:
        rows=[p for p in json.loads((OUT/'fitted_instances.json').read_text())['placements'] if 'ceiling' not in p['role'] and not p.get('context_proxy')]
        counts=core.add_instances(rows,(58,55,0),True,registry(),SHARED);core.camera('Diorama_Camera',(55,-65,80),(0,0,0))
    save_visual_level()
    report=dict(map=path,instances=sum(counts.values()),hism_groups=len(counts));(OUT/'Reports'/('unreal_'+kind+'.json')).write_text(json.dumps(report,indent=2));print('VARIANT_C_REVIEW_MAP',report)
