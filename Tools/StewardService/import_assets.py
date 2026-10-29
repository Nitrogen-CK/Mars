"""Scoped Unreal imports for generated Steward service art. Run in the rendered editor.

Imports the corrected service-only mesh on the existing skeleton without updating its reference pose.
New destinations carry ownership metadata; reruns require that ownership.
"""
import hashlib
import json
import sys
from pathlib import Path
import unreal as u

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ART = HERE / 'Output/Art'
DEST = '/Game/Mars/Gameplay/Steward/Service'
OWNER = 'Mars.StewardService.v1'
TAG = 'StewardServiceOwner'
EAL = u.EditorAssetLibrary


def owned(path):
    asset = u.load_asset(path) if EAL.does_asset_exist(path) else None
    if asset:
        assert EAL.get_metadata_tag(asset, TAG) == OWNER, 'Foreign destination: ' + path
    return asset


def save(asset):
    EAL.set_metadata_tag(asset, TAG, OWNER)
    assert EAL.save_loaded_asset(asset, False), asset.get_path_name()


def material(name, color, roughness=0.9):
    path = DEST + '/' + name
    asset = owned(path)
    if asset:
        return asset
    asset = u.AssetToolsHelpers.get_asset_tools().create_asset(name, DEST, u.Material, u.MaterialFactoryNew())
    lib = u.MaterialEditingLibrary
    base = lib.create_material_expression(asset, u.MaterialExpressionConstant3Vector, -300, 0)
    base.set_editor_property('constant', u.LinearColor(*color, 1))
    assert lib.connect_material_property(base, '', u.MaterialProperty.MP_BASE_COLOR)
    rough = lib.create_material_expression(asset, u.MaterialExpressionConstant, -300, 160)
    rough.set_editor_property('r', roughness)
    assert lib.connect_material_property(rough, '', u.MaterialProperty.MP_ROUGHNESS)
    asset.set_editor_property('two_sided', True)
    lib.recompile_material(asset)
    save(asset)
    return asset


def run(prop_only=False):
    assert not u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world(), 'Stop PIE first'
    sys.path.insert(0, str(ROOT / 'Tools/Blender/mars_send_to_unreal/unreal'))
    import mars_character_ue as importer
    skeleton = '/Game/Mars/Gameplay/Steward/Meshes/Steward_Mars_SKEL'
    anim_path = '/Game/Mars/Gameplay/Steward/Anims/Steward_Present_Mars_AS'
    prop_path = DEST + '/ServiceParchment_Mars_SM'
    mesh_path = DEST + '/Steward_Service_Mars_SK'
    owned(anim_path)
    owned(prop_path)
    owned(mesh_path)
    protected = [ROOT / 'Content/Mars/Gameplay/Steward/Meshes/Steward_Mars_SK.uasset',
                 ROOT / 'Content/Mars/Gameplay/Steward/Meshes/Steward_Mars_SKEL.uasset']
    if prop_only:
        protected += [ROOT / 'Content/Mars/Gameplay/Steward/Service/Steward_Service_Mars_SK.uasset',
                      ROOT / 'Content/Mars/Gameplay/Steward/Anims/Steward_Present_Mars_AS.uasset']
    before = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    jobs = [
        dict(fbx=str(ART / 'Steward_Service_Mars_SK.fbx'), folder=DEST,
             name='Steward_Service_Mars_SK', kind='skeletal', skeleton=skeleton, update_ref_pose=False),
        dict(fbx=str(ART / 'Steward_Present_Mars_AS.fbx'), folder='/Game/Mars/Gameplay/Steward/Anims',
             name='Steward_Present_Mars_AS', kind='anim', skeleton=skeleton),
        dict(fbx=str(ART / 'ServiceParchment_Mars_SM.fbx'), folder=DEST,
             name='ServiceParchment_Mars_SM', kind='static', skeleton=None),
    ]
    result = importer.import_character([jobs[-1]] if prop_only else jobs, save=False)
    assert not result['error'] and not result['failed'] and not result['skipped'], result
    anim = u.load_asset(anim_path)
    prop = u.load_asset(prop_path)
    service_mesh = u.load_asset(mesh_path)
    original_mesh = u.load_asset('/Game/Mars/Gameplay/Steward/Meshes/Steward_Mars_SK')
    assert isinstance(service_mesh, u.SkeletalMesh)
    assert service_mesh.get_editor_property('skeleton') == u.load_asset(skeleton)
    originals = {str(slot.get_editor_property('material_slot_name')): slot.get_editor_property('material_interface')
                 for slot in original_mesh.get_editor_property('materials')}
    slots = list(service_mesh.get_editor_property('materials'))
    for index, slot in enumerate(slots):
        name = str(slot.get_editor_property('material_slot_name'))
        assert name in originals, 'Unknown service mesh material slot: ' + name
        slot.set_editor_property('material_interface', originals[name])
    if not prop_only:
        service_mesh.set_editor_property('materials', slots)
        save(service_mesh)
    physics_asset = service_mesh.get_editor_property('physics_asset')
    if physics_asset and not prop_only:
        assert physics_asset.get_path_name().startswith(DEST + '/'), physics_asset.get_path_name()
        save(physics_asset)
    assert isinstance(anim, u.AnimSequence) and isinstance(prop, u.StaticMesh)
    EAL.set_metadata_tag(anim, TAG, OWNER)
    EAL.set_metadata_tag(prop, TAG, OWNER)
    assert anim.get_editor_property('skeleton') == u.load_asset(skeleton), 'Wrong animation skeleton'
    assert 5.9 < anim.get_play_length() < 6.1, anim.get_play_length()
    colors = {'ServiceParchment_Mars_M': (.63, .43, .20),
              'ServiceParchmentEdge_Mars_M': (.25, .125, .045),
              'ServiceSeal_Mars_M': (.22, .035, .018)}
    for index, slot in enumerate(prop.get_editor_property('static_materials')):
        name = str(slot.get_editor_property('imported_material_slot_name'))
        assert name in colors, name
        prop.set_material(index, material(name, colors[name]))
    bounds = prop.get_bounds()
    dims = bounds.box_extent * 2
    audited = json.loads((ART / 'export_validation.json').read_text())['prop_dimensions_metres']
    assert all(abs(actual - expected * 100) < .2 for actual, expected in zip(dims.to_tuple(), audited)), str(dims)
    save(prop)
    if not prop_only:
        save(anim)
    after = {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in protected}
    assert before == after, 'Existing Steward geometry/skeleton changed on disk'
    report = dict(status='imported', prop_only=prop_only, imports=result, animation_seconds=anim.get_play_length(),
                  service_mesh=service_mesh.get_path_name(),
                  skeleton=anim.get_editor_property('skeleton').get_path_name(), prop_dimensions_cm=list(dims.to_tuple()),
                  protected_sha256=after)
    (HERE / 'Output/import_report.json').write_text(json.dumps(report, indent=2))
    print('STEWARD_SERVICE_IMPORT_OK', json.dumps(report))
    return report


if __name__ == '__main__':
    run()
