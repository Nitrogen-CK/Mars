"""Read-only complete assembled cube support: greybox HISMs plus static SMCs.

The legacy schema calls pose rows 'instances'. For a non-instanced SMC its
single row is explicitly typed as a component pose, never an HISM index.
"""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'

def capture(core,guard):
    import unreal as u
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world();assert w.get_path_name()=='/Game/Mars/Maps/Warrens_VariantC_Mars_MAP.Warrens_VariantC_Mars_MAP'
    guard();assert u.EditorLoadingAndSavingUtils.get_dirty_map_packages()==u.EditorLoadingAndSavingUtils.get_dirty_content_packages()==[]
    old=json.loads((RUN/'assembled_native_solids_r01.json').read_text());old_actors={a['level']+'|'+a['label']:a for a in old['actors']};actors=[];repairs=[]
    for a in u.GameplayStatics.get_all_actors_of_class(w,u.Actor):
        key=a.get_level().get_path_name()+'|'+a.get_actor_label()
        if key in old_actors:
            row=dict(label=a.get_actor_label(),level=a.get_level().get_path_name(),components=[core._component(c) for c in a.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)])
            assert row==old_actors[key];actors.append(row)
        else:
            parts=[]
            for c in a.get_components_by_class(u.StaticMeshComponent):
                if isinstance(c,u.InstancedStaticMeshComponent) or not c.static_mesh or c.static_mesh.get_path_name()!='/Engine/BasicShapes/Cube.Cube' or c.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION:continue
                assert c.mobility==u.ComponentMobility.STATIC and a.get_actor_label().startswith('WVC_GP_P4_Collision_')
                tf=core._pose(c.get_world_transform());assert tf['q']==[0.,0.,0.,1.] and all(v>0 for v in tf['scale'])
                assert not a.get_editor_property('hidden') and c.is_visible() and not c.get_editor_property('hidden_in_game')
                parts.append(dict(path=c.get_path_name(),owner=a.get_path_name(),owner_label=a.get_actor_label(),level=a.get_level().get_path_name(),mesh='/Engine/BasicShapes/Cube',materials=[m.get_path_name() for m in c.get_materials()],pose=tf,instances=[tf],pose_row_kind='SINGLE_STATIC_COMPONENT_WORLD_POSE_NOT_INSTANCE',collision_profile=str(c.get_collision_profile_name()),collision_enabled=str(c.get_collision_enabled()),body_instance=c.get_editor_property('body_instance').export_text(),visible=c.is_visible(),hidden_in_game=c.get_editor_property('hidden_in_game'),cast_shadow=c.cast_shadow))
            if parts:
                row=dict(label=a.get_actor_label(),level=a.get_level().get_path_name(),components=parts);actors.append(row);repairs.append(row)
    assert len(actors)==len(old['actors'])+14 and len(repairs)==14
    assert {a['level']+'|'+a['label'] for a in actors if not a['label'].startswith('WVC_GP_P4_Collision_')}==set(old_actors)
    record=dict(status='READ_ONLY_CURRENT_ASSEMBLED_NATIVE_SOLIDS',world=w.get_path_name(),actors=actors,dirty=dict(maps=[],content=[]),prior_sha256=hashlib.sha256((RUN/'assembled_native_solids_r01.json').read_bytes()).hexdigest(),tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),scope='Exact previous30greyboxHISM actors plus ALL14 current blocking non-instanced static Cube SMCs in assembled editor Main. Fourteen identity-quaternion component poses are explicitly typed; no geometry or source changes. Ramps, noncube props and dynamic runtime mechanism candidates are not support boxes.')
    p=RUN/'assembled_native_solids_r02.json';assert not p.exists();p.write_text(json.dumps(record,indent=2)+'\n');print('FULL_STATIC_CUBE_SUPPORT_CAPTURED',len(actors),len(repairs),hashlib.sha256(p.read_bytes()).hexdigest())
