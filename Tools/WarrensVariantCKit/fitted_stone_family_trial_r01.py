"""One material axis on five enumerated, decorative TX01 HISM groups in PIE."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
STATE = None
TARGETS = {('Belfry', 'WVC_BACKING_TX01'): (112, 10459),
           ('Belfry', 'WVC_CCS13_TX01'): (112, 9541),
           ('Brineworks', 'WVC_BACKING_TX01'): (1282, 13470),
           ('Brineworks', 'WVC_CCS13_TX01'): (384, 14535),
           ('Brineworks', 'WVC_CCS15'): (898, 29462)}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check():
    import unreal as u
    t = STATE
    assert t and sha(__file__) == t['gate']['fitted_trial_sha256']
    t['colour'].check()
    assert t['colour'].STATE['on']
    for row in t['targets']:
        c = row['component']
        assert t['base'].flags(c) == row['flags']
        assert c.get_editor_property('body_instance').export_text() == row['original']['body_instance']
        assert c.get_material(0) == (t['material'] if t['on'] else row['material'])
        assert c.get_editor_property('instancing_random_seed') == row['original']['random_seed']
    assert t['values'].read(t['material']) == t['receipt']['explicit_values']
    assert t['links'].read(t['material']) == t['receipt']['links']
    assert t['snapshots'].snapshot(t['material']) == t['receipt']['full_graph']
    assert u.MaterialEditingLibrary.get_material_default_vector_parameter_value(t['material'], 'RoomTint').to_tuple() == (1., 1., 1., 1.)


def begin(base, colour, material):
    import unreal as u
    global STATE
    assert STATE is None
    colour.check()
    assert colour.STATE['on']
    gate = json.loads((DOC/'NATIVE_SHELL_UNDERLAY_GATE_R04.json').read_text())
    assert gate['fitted_trial_sha256'] == sha(__file__)
    assert base.RUN.relative_to(ROOT).as_posix() == gate['run']
    assert base.STATE['capture'].STATE['out'].relative_to(ROOT).as_posix() == gate['capture_folder']
    for path, digest in gate['input_sha256'].items():
        assert sha(ROOT/path) == digest
    receipt = json.loads((DOC/'fitted-context-family-r01/transient_build_readback_r01.json').read_text())
    assert material.get_path_name() == receipt['material'] and material.get_outer().get_path_name() == '/Engine/Transient'
    assert material.get_editor_property('phys_material') is None
    assert material.get_editor_property('used_with_instanced_static_meshes') is True
    assert material.get_editor_property('tangent_space_normal') is False
    stats = u.MaterialEditingLibrary.get_statistics(material)
    assert {k: getattr(stats, k) for k in receipt['compile_statistics']} == receipt['compile_statistics']
    inventory = json.loads((DOC/'native-shell-underlay-r13/static_TX01_context_inventory_r01.json').read_text())
    targets = []
    for (tile, label), (count, seed) in TARGETS.items():
        actor, = [a for a in u.GameplayStatics.get_all_actors_of_class(base.STATE['world'], u.Actor)
                  if a.get_actor_label() == label and a.get_level().get_path_name().split('/')[-1].startswith('UEDPIE_0_LI_Warrens_'+tile+'_LevelInstance_')]
        c, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert c.mobility == u.ComponentMobility.STATIC and c.get_collision_enabled() == u.CollisionEnabled.NO_COLLISION
        assert len(c.get_materials()) == 1
        old = c.get_material(0)
        assert old.get_path_name().split('.')[0] == '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01'
        assert isinstance(old, u.Material) and old.get_editor_property('phys_material') is None
        original = copy.deepcopy(base.STATE['expected_hisms'][c.get_path_name()])
        assert original == base.STATE['before'][c.get_path_name()]
        expected, = [r for r in inventory['components'] if r['tile'] == tile and r['label'] == label]
        assert {k:v for k,v in original.items() if k not in ('path','owner','level')} == {k:v for k,v in expected['original'].items() if k not in ('path','owner','level')}
        assert len(original['instances']) == count and original['random_seed'] == seed and original['custom_data_floats'] == 0
        assert base.flags(c) == expected['flags']
        targets.append(dict(tile=tile, label=label, component=c, material=old, original=original, flags=base.flags(c)))
    assert len(targets) == 5 and sum(len(r['original']['instances']) for r in targets) == 2788
    STATE = dict(base=base, colour=colour, material=material, targets=targets, gate=gate, receipt=receipt,
                 values=base.load('material_graph_values_r02'), links=base.load('material_graph_links_r01'),
                 snapshots=base.load('catacomb_plane_normal_materials'), on=False)
    check()
    (base.STATE['capture'].STATE['out']/'fitted_targets.json').write_text(json.dumps(dict(status='FIVE_DECORATIVE_GROUPS_ENUMERATED_BEFORE_BINDING', targets=[dict(tile=r['tile'],label=r['label'],original=r['original'],flags=r['flags']) for r in targets]), indent=2)+'\n')
    print('FITTED_FAMILY_READY_FIVE_GROUPS_2788_INSTANCES_UNCHANGED_SEEDS')


def candidate(on):
    assert isinstance(on, bool)
    check()
    t = STATE
    for row in t['targets']:
        material = t['material'] if on else row['material']
        row['component'].set_material(0, material)
        expected = copy.deepcopy(row['original'])
        expected['materials'] = [material.get_path_name().split('.')[0]]
        t['base'].STATE['expected_hisms'][row['component'].get_path_name()] = expected
    t['on'] = on
    check()


def capture(label):
    import unreal as u
    t = STATE
    u.GameplayStatics.set_game_paused(t['base'].STATE['world'], True)
    check()
    t['colour'].capture(label)
    path = t['base'].STATE['capture'].STATE['out']/(label+'.json')
    record = json.loads(path.read_text())
    record['fitted_stone'] = dict(on=t['on'], material=t['material'].get_path_name(), targets=[r['component'].get_path_name() for r in t['targets']], boundary='Only five exact decorative static TX01 slot0 bindings. Geometry, instances, random seeds, physics, other materials and all accepted working room axes stay fixed. Statistical native family palette; no exact source UV or histogram parity claim.')
    path.write_text(json.dumps(record, indent=2)+'\n')


def release():
    global STATE
    candidate(False)
    STATE = None
    print('FITTED_FAMILY_ORIGINAL_BINDINGS_RESTORED_REFERENCES_RELEASED')


def abort(colour, underlay, base, roof, extension):
    global STATE
    try:
        if STATE:
            for row in STATE['targets']:
                row['component'].set_material(0, row['material'])
                base.STATE['expected_hisms'][row['component'].get_path_name()] = copy.deepcopy(row['original'])
    finally:
        STATE = None
        colour.abort(underlay, base, roof, extension)
