"""Reload/read only the three clean owned successors; never save or alter source."""
import hashlib
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def run(creator):
    import unreal as u
    source=creator.STATE['source'];assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert source.dirty()==dict(maps=[],content=[]);source.guard(source.STATE['map_after'])
    inventory=json.loads((RUN/'candidate_assets_timber_r13.json').read_text());assert sha(RUN/'candidate_assets_timber_r13.json')=='ce24d0065ccd17de8dfe2be98a03cd31d64b7405eddd3f5eb1523da0ec0f7675'
    assert len(inventory['assets'])==39 and len(creator.STATE['created'])==3
    def verify_bytes():
        assert all(sha(ROOT/('Content/'+p.removeprefix('/Game/')+'.uasset'))==r['package_sha256'] for p,r in inventory['assets'].items())
        source.guard(source.STATE['map_after']);assert source.dirty()==dict(maps=[],content=[])
    verify_bytes();paths=creator.STATE['targets'];assert len(set(paths))==3 and set(paths)==set(creator.STATE['created'])
    assert set(paths)==set(creator.MATERIALS.values())|{creator.PROFILE} and all(p.startswith(creator.DEST+'/') for p in paths)
    packages=[u.load_asset(p).get_outer() for p in paths]
    assert [p.get_path_name() for p in packages]==paths
    assert hasattr(u.ReloadPackagesInteractionMode,'ASSUME_NEGATIVE')
    result=u.EditorLoadingAndSavingUtils.reload_packages(packages,u.ReloadPackagesInteractionMode.ASSUME_NEGATIVE)
    assert result[0] is True and str(result[1])=='',result
    del packages
    verify_bytes();graphs={};stats={}
    for role,path in creator.MATERIALS.items():
        m=u.load_asset(path);assert m and m.get_path_name().split('.')[0]==path
        graphs[role]=creator.graph(m);assert graphs[role]==creator.STATE['graphs'][role]
        s=u.MaterialEditingLibrary.get_statistics(m);assert s.num_pixel_shader_instructions>0 and s.num_vertex_shader_instructions>0
        stats[role]=dict(pixel=s.num_pixel_shader_instructions,vertex=s.num_vertex_shader_instructions)
    p=u.load_asset(creator.PROFILE);refs=creator.profile_refs(p)
    expected=creator.STATE['created'][creator.PROFILE]['details']['refs'];assert refs==expected
    base=source.dependencies()[0];export=base._export(u,p,RUN/'timber_successors_r13/reloaded_profile.t3d')
    assert export['sha256']==creator.STATE['created'][creator.PROFILE]['details']['export']['sha256'],'Profile export changed on reload'
    verify_bytes()
    data=dict(status='RELOAD_REPORTED_SUCCESS_AND_THREE_OWNED_ASSETS_READ_BACK',requested_reload_paths=paths,any_packages_reloaded=result[0],reload_error=str(result[1]),graphs=graphs,statistics=stats,profile_refs=refs,profile_export=export,source_map_sha256=source.STATE['map_after'],asset_inventory_sha256=sha(RUN/'candidate_assets_timber_r13.json'),dirty=source.dirty(),boundary='Requested only three clean unused owned packages with AssumeNegative. API reports any package reloaded, with empty errors; all three paths then passed fresh graph/profile checks. Global component reregistration is an engine side effect. No save, source/profile assignment, library or gameplay change. Native saved appearance remains separate.')
    out=RUN/'timber_successors_reloaded_r13.json';assert not out.exists();out.write_text(json.dumps(data,indent=2)+'\n');print('SAVED_SUCCESSORS_RELOADED',sha(out))
