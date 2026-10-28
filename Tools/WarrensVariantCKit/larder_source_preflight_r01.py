"""Read/export exact source-room baselines; never modify or save native packages."""
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def load(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_source_preflight_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m


def run(tile,core,base,assets):
    import unreal as u
    assert tile in ('Brineworks','Belfry')
    assert Path(u.Paths.convert_relative_path_to_full(u.Paths.project_dir())).resolve()==ROOT.resolve()
    ed=u.get_editor_subsystem(u.UnrealEditorSubsystem);assert ed.get_game_world() is None
    world=ed.get_editor_world();target='/Game/Mars/Maps/Variants/v8c/LI_Warrens_'+tile
    assert world.get_path_name()==target+'.LI_Warrens_'+tile
    assets.guard();assert assets.load('room_tint_owned_assets_r01').dirty()==dict(maps=[],content=[])
    folder=DOC/'source-retention-preflight-r01'/tile;assert not folder.exists();folder.mkdir(parents=True)
    exporter=load('cardinal_wall_family_persistent')
    roster,hisms=exporter._roster(u,core,world,folder/'before_raw')
    flags={}
    for actor in u.GameplayStatics.get_all_actors_of_class(world,u.Actor):
        for component in actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent):
            flags[component.get_path_name()]=dict(render_flags=base.flags(component),mobility=str(component.mobility),phys_materials=[dict(path=m.get_path_name(),type=m.get_class().get_name(),override=m.get_editor_property('phys_material').get_path_name() if m.get_editor_property('phys_material') else None) for m in component.get_materials()])
    scripts=[]
    if tile=='Brineworks':
        kind=u.load_class(None,'/Script/Angelscript.Mars_Anchor_Spawn_EntityScript')
        for obj in u.ObjectIterator(kind):
            if obj.get_world()==world and 'Anchor.Mars.Warrens.S3' in obj.get_editor_property('AnchorId').export_text():
                script=exporter._export(u,obj,folder/'S3_script.t3d')
                scripts.append(dict(path=obj.get_path_name(),actor=obj.get_outer().get_path_name(),actor_guid=obj.get_outer().get_editor_property('actor_guid').export_text(),type=obj.get_class().get_name(),AnchorId=obj.get_editor_property('AnchorId').export_text(),GateMaterialOverride=obj.get_editor_property('GateMaterialOverride').get_path_name(),LeverSide=str(obj.get_editor_property('LeverSide')),HasCrawl=obj.get_editor_property('HasCrawl'),raw=script))
        assert len(scripts)==1
    mapfile=ROOT/('Content/'+target.removeprefix('/Game/')+'.umap');files={mapfile.relative_to(ROOT).as_posix():sha(mapfile)}
    sidecar=mapfile.with_suffix('.ckexport')
    if sidecar.exists():files[sidecar.relative_to(ROOT).as_posix()]=sha(sidecar)
    record=dict(status='READ_ONLY_SOURCE_ROSTER_COMPONENTS_RAW_EXPORTS_AND_S3_BASELINE',tile=tile,target=target,files=files,roster=roster,hisms=hisms,component_flags=flags,scripts=scripts,tool_sha256=sha(__file__),boundary='No source package or object property modified; read-only full Actor/component T3D, HISM/instance/body/material/seed records, render flags/mobility/physical overrides and S3 source script recorded. Raw old-map bytes remain canonical guard targets.')
    (folder/'baseline.json').write_text(json.dumps(record,indent=2)+'\n')
    assets.guard();assert assets.load('room_tint_owned_assets_r01').dirty()==dict(maps=[],content=[])
    print('SOURCE_PREFLIGHT_EXPORTED',tile,len(roster),len(hisms),sum(len(v['instances']) for v in hisms.values()),sha(folder/'baseline.json'))
