"""Opt-in placed pickup manifests. Shared item/drop behavior is never changed."""
import copy
import json
import math
from pathlib import Path


def item_kind(cls):
    known = {
        'Mars_WorldItem_Key_Red_EntityScript':'Key_Red',
        'Mars_WorldItem_Backpack_EntityScript':'Backpack',
        'Mars_WorldItem_Lantern_EntityScript':'Lantern',
        'Mars_WorldItem_Tallow_EntityScript':'Tallow',
        'Mars_WorldItem_Ration_EntityScript':'Ration',
        'Mars_Sandbox_Cleaver_EntityScript':'Cleaver',
        'Mars_Sandbox_Tenderizer_EntityScript':'Tenderizer',
    }
    return known.get(cls)


def fixture_id(row):
    return row['note'].replace(' ','_').replace(':','_')


def apply(manifest, spec):
    bounds = json.loads((Path(__file__).parent/spec['boundsFile']).read_text())
    rows=[]
    for row in manifest['entities']:
        kind=item_kind(row['cls'])
        if not kind:
            continue
        assert not row['props'], ('Custom placed pickup configuration needs review',row)
        assert row.get('yaw',0)==0 and row.get('pitch',0)==0, 'Rotated body needs authored witnesses'
        identity=fixture_id(row)
        original=copy.deepcopy(row)
        mesh=bounds[kind]
        half=[math.ceil(max(abs(mesh['min'][i]),abs(mesh['max'][i]))*mesh['scale'][i]+1) for i in range(2)]
        if identity in spec['supportById']:
            support=spec['supportById'][identity]
        else:
            entry=row['note'].split(' ')[0]
            assert entry in spec['entrySupportZ'], row
            support=spec['entrySupportZ'][entry]
        row['cls']='Mars_PlacedPickup_EntityScript'
        row['tile']=None
        row['props']=dict(FixtureId='WarrensC.Startup.'+identity,
            Definition=dict(asset=mesh['definition']),
            SupportHeightOffsetCm=round((support-row['at'][2])*100,6),
            SupportHalfExtentsCm=dict(struct='Vector2D',fields=dict(X=half[0],Y=half[1])))
        row['placedPickupOriginal']=original
        row['placedPickupExistingAt']=spec.get('existingAtById',{}).get(identity,list(original['at']))
        row['placedPickupSupportZ']=support
        rows.append(dict(id=identity,kind=kind,support_z=support,footprint_half_cm=half,
                         original_tile=original['tile'],at=row['at']))
    assert len(rows)==spec['expectedCount'], (len(rows),spec['expectedCount'])
    assert len({r['id'] for r in rows})==len(rows)
    manifest['placedPickupStartup']=dict(fixtures=rows,boundsFile=spec['boundsFile'],
        boundary='Authored initial support predicate only; real completion, retention and pickup require runtime proof.')
