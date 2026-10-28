"""Translate accepted native room records into exact two-source-map changes."""
import copy
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
PERSIST='/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Persist_R01/Materials/'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def package(path):return path.split('.')[0]


source={tile:json.loads((DOC/'source-retention-preflight-r02'/tile/'baseline.json').read_text()) for tile in ('Brineworks','Belfry')}
context=json.loads((DOC.parent/'remaining-room-rollout-r01/shared_static_context_inventory_r01.json').read_text())['components']
offsets={}
for tile,data in source.items():
    local,=[v for v in data['hisms'].values() if v['owner_label']=='Warrens_Greybox_wall']
    main,=[v['original'] for v in context if v['label']=='Warrens_Greybox_wall' and 'LI_Warrens_'+tile+'_LevelInstance_' in v['level']]
    assert local['pose']['q']==main['pose']['q']==[0.,0.,0.,1.] and local['pose']['scale']==main['pose']['scale']==[1.,1.,1.]
    offsets[tile]=[a-b for a,b in zip(main['pose']['at'],local['pose']['at'])]
    assert all(v==0 for v in local['pose']['at'])
reviewed=json.loads((DOC/'native-fitted-stone-r16/storage_fitted_B.json').read_text())
new_actors=[]
roles=['walls','floor','ceiling','window','barrel','sack','jar','high_roof']
assert len(reviewed['art_state'])==len(roles)==8
for role,original in zip(roles,reviewed['art_state']):
    row=copy.deepcopy(original);tile='Belfry' if role=='high_roof' else 'Brineworks'
    pose=copy.deepcopy(row['pose']);pose['at']=[a-b for a,b in zip(pose['at'],offsets[tile])]
    material_paths=[package(v) for v in row.get('materials',[])]
    if role in ('barrel','sack','jar'):material_paths[0]=PERSIST+'MI_WVC_Larder_'+role.title()+'_R01'
    new_actors.append(dict(role=role,tile=tile,label='WVC_Larder_Retained_'+role,pose=pose,reviewed_world_pose=row['pose'],mesh=package(row['mesh']) if 'mesh' in row else None,materials=material_paths,reviewed_properties={k:v for k,v in row.items() if k not in ('path','pose','mesh','materials','tag')}))
bindings=[]
for tile,data in source.items():
    labels=['Warrens_Greybox_wall','WVC_BACKING_TX01','WVC_CCS13_TX01']+(['WVC_CCS15'] if tile=='Brineworks' else [])
    for label in labels:
        component,=[v for v in data['hisms'].values() if v['owner_label']==label]
        assert component['materials']==['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01']
        bindings.append(dict(tile=tile,actor_label=label,slot=0,before=component['materials'][0],after=PERSIST+'M_WVC_Larder_'+('RawShell' if label=='Warrens_Greybox_wall' else 'Fitted')+'_R01',component_path=component['path'],instances=len(component['instances'])))
water,=[v for v in source['Brineworks']['hisms'].values() if v['materials']==['/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_FX_Water'] and len(v['instances'])==1]
bindings.append(dict(tile='Brineworks',actor_label=water['owner_label'],slot=0,before=water['materials'][0],after=PERSIST+'MI_WVC_Larder_Brine_R01',component_path=water['path'],instances=1))
removals=[]
for role,label,index,count in [('barrel','WVC_CCS66',4,5),('sack','WVC_CCS68',8,9),('jar','WVC_WVC048',2,3)]:
    row,=[v for v in source['Brineworks']['hisms'].values() if v['owner_label']==label]
    assert len(row['instances'])==count and index==count-1 and 'NO_COLLISION' in row['collision_enabled']
    removals.append(dict(role=role,tile='Brineworks',actor_label=label,index=index,count_before=count,local_pose=row['instances'][index],component_path=row['path']))
script,=source['Brineworks']['scripts'];assert script['type']=='Mars_Anchor_Spawn_EntityScript' and script['LeverSide']=='<Mars_Anchor_LeverSide.NONE: 0>' and script['HasCrawl'] is False
script=dict(script,tile='Brineworks',property='GateMaterialOverride',before=package(script['GateMaterialOverride']),after=PERSIST+'M_WVC_Larder_S3_R01')
files={p:h for data in source.values() for p,h in data['files'].items()}
result=dict(status='PROPOSED_EXACT_ACCEPTED_LARDER_SOURCE_RETENTION_NOT_EXECUTED',owner='Mars.WarrensVariantC.Larder.RetainedArt.R01',source_main_offset_cm=offsets,source_baselines={tile:dict(file=(DOC/'source-retention-preflight-r02'/tile/'baseline.json').relative_to(ROOT).as_posix(),sha256=sha(DOC/'source-retention-preflight-r02'/tile/'baseline.json'),actors_before=len(data['roster']),HISMs_before=len(data['hisms']),instances_before=sum(len(v['instances']) for v in data['hisms'].values())) for tile,data in source.items()},allowed_source_files=files,new_actors=new_actors,material_bindings=bindings,remove_decorative_tails=removals,S3_presentation=script,expected_source_counts=dict(Brineworks=dict(actors=117,HISMs=69,instances=5246),Belfry=dict(actors=81,HISMs=33,instances=3537)),review=dict(file=(DOC/'native-fitted-stone-r16/ASTRA_FITTED_STONE_AND_WORKING_ROOM_REVIEW_R16.md').relative_to(ROOT).as_posix(),sha256=sha(DOC/'native-fitted-stone-r16/ASTRA_FITTED_STONE_AND_WORKING_ROOM_REVIEW_R16.md')),scope='Eight accepted actors (seven primary Brineworks, source-supported high roof in Belfry); eight exact HISM material bindings, three decorative final-instance removals, one existing S3 Spawn anchor material property only. No original pose/body/seed/visibility/light/mesh or any other gameplay property changes. No Main/Catacomb or collision map save. Private meshes/materials/MI already saved and reloaded. Source current guard successor and native persisted appearance must follow adoption. Source and native/Blender library persistence are separate obligations.',regeneration='Existing unreal_scenes.refuse_retained_scene_rebuild already refuses raw legacy rebuilds after retained-art promotion. Retained manifest is the procedural source for this scoped art operation; do not run legacy full dressing to reproduce it.')
path=DOC/'SOURCE_RETENTION_MANIFEST_R01.json';assert not path.exists();path.write_text(json.dumps(result,indent=2)+'\n')
print('EXACT_LARDER_SOURCE_MANIFEST',len(new_actors),len(bindings),len(removals),offsets,sha(path))
