"""Import only the owned derived arch; explicit source UCX, never automatic hulls."""
import unreal as u, sys, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'Tools/StewardService/Output/Arch'
DEST='/Game/Mars/Gameplay/Steward/Service'
NAME='CampOpenArch_Mars_SM'; PATH=DEST+'/'+NAME
TAG='StewardServiceOwner'; OWNER='Mars.StewardService.v1'
assert not u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world(), 'Stop PIE before asset import'
existing=u.load_asset(PATH)
assert existing is None or u.EditorAssetLibrary.get_metadata_tag(existing,TAG)==OWNER, 'Foreign destination'
protected=[ROOT/'Content/Mars/Environment/Meshes/Crypt'/n for n in ['CryptExtractionArch_Mars_SM.uasset','CryptArchBarred2m4_Mars_SM.uasset']]
before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
sys.path.insert(0,str(ROOT/'Tools/Blender/mars_send_to_unreal/unreal'))
import mars_character_ue as helper
job=dict(fbx=str(OUT/(NAME+'.fbx')),folder=DEST,name=NAME,kind='static',skeleton=None)
task=helper._task(job); opts=helper._options(job,existing)
opts.static_mesh_import_data.set_editor_property('auto_generate_collision',False)
opts.static_mesh_import_data.set_editor_property('one_convex_hull_per_ucx',True)
task.options=opts
was=u.SystemLibrary.get_console_variable_bool_value(helper.FBX_FLAG)
u.SystemLibrary.execute_console_command(None,helper.FBX_FLAG+' 0')
try:u.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
finally:u.SystemLibrary.execute_console_command(None,helper.FBX_FLAG+(' 1' if was else ' 0'))
mesh=u.load_asset(PATH); assert isinstance(mesh,u.StaticMesh),task.imported_object_paths
source=u.load_asset('/Game/Mars/Environment/Meshes/Crypt/CryptExtractionArch_Mars_SM')
mesh.set_material(0,source.get_material(0))
u.EditorAssetLibrary.set_metadata_tag(mesh,TAG,OWNER)
body=mesh.get_editor_property('body_setup'); agg=body.get_editor_property('agg_geom')
convex=agg.get_editor_property('convex_elems')
assert len(convex)==3, 'Expected exactly original posts and threshold, got '+str(len(convex))
def vec(v):return [v.x,v.y,v.z]
source_audit=json.loads((OUT/'source_islands.json').read_text())['Source_ExtractionArch.fbx']
source_hulls=next(o['islands'] for o in source_audit if o['name']=='UCX_CryptExtractionArch_Mars_SM')
boxes=[dict(min=[i['min'][0]*100,-i['max'][1]*100,i['min'][2]*100],
            max=[i['max'][0]*100,-i['min'][1]*100,i['max'][2]*100]) for i in source_hulls]
assert all(b['max'][2]<=30.01 or b['max'][0]<=76.01 or b['min'][0]>=323.99 for b in boxes), boxes
assert u.EditorAssetLibrary.save_loaded_asset(mesh,False)
after={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}; assert before==after
bounds=mesh.get_bounds()
report=dict(asset=PATH,convex_count=len(convex),convex_bounds_cm=boxes,bounds=dict(origin=vec(bounds.origin),extent=vec(bounds.box_extent)),
    material=mesh.get_material(0).get_path_name(),source_hashes_before=before,source_hashes_after=after,source_hashes_unchanged=before==after,
    convex_bounds_evidence='Explicit source UCX input; verify saved asset by exported FBX roundtrip',
    no_central_convex=True,auto_generate_collision=False)
(OUT/'import_report.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
