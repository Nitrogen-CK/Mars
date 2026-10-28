"""Read-only actual authored Fig state; no requests or fragment/component writes."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04/native-room-r11'

def record(label,room,source):
    import unreal as u
    s=room.STATE;assert s and s['world']==u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world()
    typ=u.get_type_from_class(u.load_class(None,'/Script/Angelscript.Mars_Forage_FigVine_EntityScript'))
    matches=[o for o in u.ObjectIterator(typ) if o.get_world()==s['world'] and 'Anchor.Mars.Warrens.CatacombHusk' in o.get_editor_property('Anchor').export_text()]
    obj,=matches;context=obj.get_editor_property('Anchor').export_text();assert source.PROFILE in context
    dyn=u.get_type_from_class(u.load_class(None,'/Script/CkDynamic.Ck_Utils_DynamicFragment_UE'))
    life=u.get_type_from_class(u.load_class(None,'/Script/CkEcs.Ck_Utils_EntityLifetime_UE'))
    handle=obj.do_get_script_entity();assert life.get_world_for_entity(handle)==s['world']
    fragments=[f.export_text() for f in dyn.get_all_fragments(handle)]
    fragments=[f for f in fragments if any(t in f for t in ('Mars_Fragment_Forage','Health','Mars_Feature_Forage'))]
    parts=[]
    for a in u.GameplayStatics.get_all_actors_of_class(s['world'],u.Actor):
        for c in a.get_components_by_class(u.StaticMeshComponent):
            if not c.static_mesh:continue
            p=c.get_world_location()
            if abs(p.x+9600)<150 and abs(p.y-1900)<100 and 0<=p.z<=270:
                parts.append(dict(path=c.get_path_name(),mesh=c.static_mesh.get_path_name(),at=list(p.to_tuple()),visible=c.is_visible(),collision=str(c.get_collision_profile_name())))
    data=dict(label=label,world=s['world'].get_path_name(),script=obj.get_path_name(),context=context,
              time=u.GameplayStatics.get_time_seconds(s['world']),paused=u.GameplayStatics.is_game_paused(s['world']),
              player=s['helper'].inspect(s['pawn']),world_items=s['helper'].world_items(s['pawn']),fragments=fragments,parts=parts,
              boundary='Read-only actual authored Fig and public copied fragments. Inputs and timed observations are recorded separately; no forced release, refill, visibility or inventory.')
    source.guard(source.STATE['map_after']);assert source.dirty()==dict(maps=[],content=[])
    path=OUT/(label+'.json');assert not path.exists();path.write_text(json.dumps(data,indent=2)+'\n')
    print('FIG_STATE',label,fragments);return data
