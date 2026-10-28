"""White RoomTint parity on three owned room surfaces in disposable PIE only."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
STATE = None


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check():
    import unreal as u
    t = STATE
    assert t and sha(__file__) == t['gate']['tool_sha256']
    t['base'].check()
    for family, row in t['targets'].items():
        assert row['component'].get_material(0) == (row['candidate'] if t['on'] else row['original'])
        assert t['values'].read(row['candidate']) == row['proof']['destination_explicit_values']
        assert t['values'].read(row['original']) == row['proof']['source_values']
        assert t['links'].read(row['candidate']) == row['proof']['destination_links']
        assert t['links'].read(row['original']) == row['proof']['source_links']
        assert t['snapshots'].snapshot(row['candidate'])['properties'] == row['proof']['destination_properties']
        assert t['snapshots'].snapshot(row['original'])['properties'] == row['proof']['source_properties']
        assert u.MaterialEditingLibrary.get_material_default_vector_parameter_value(row['candidate'], 'RoomTint').to_tuple() == (1., 1., 1., 1.)


def begin(base, candidates):
    import unreal as u
    global STATE
    assert STATE is None
    base.check()
    s = base.STATE
    assert len(s['created']) == 4 and not s['props'] and s['water_mid'] is None
    gate = json.loads((DOC/'NATIVE_ROOM_TINT_WHITE_GATE_R01.json').read_text())
    assert gate['status'] == 'APPROVED_THREE_OWNED_SURFACE_WHITE_TINT_PARITY_ONLY' and gate['tool_sha256'] == sha(__file__)
    assert base.RUN.relative_to(ROOT).as_posix() == gate['run'] and s['capture'].STATE['out'].relative_to(ROOT).as_posix() == gate['capture_folder']
    for path, digest in gate['input_sha256'].items():
        assert sha(ROOT/path) == digest
    builds = json.loads((DOC/'room_tint_transient_builds_r01.json').read_text())
    assert builds['status'] == 'THREE_TRANSIENT_FAMILY_COPIES_COMPILED_NOT_BOUND_OR_WHITE_PARITY_ACCEPTED'
    assert set(candidates) == {'Walls', 'Floor', 'Ceiling'}
    targets = {}
    for family, role in [('Walls', 'walls'), ('Floor', 'floor'), ('Ceiling', 'ceiling')]:
        actor, = [a for a in s['created'] if a.get_actor_label() == 'WVC_Larder_Finish_'+role]
        component = actor.static_mesh_component
        proof = builds['families'][family]
        original = component.get_material(0)
        candidate = candidates[family]
        assert original.get_path_name() == proof['source'] and candidate.get_path_name() == proof['destination']
        assert not proof['full_property_delta'] and candidate.get_outer().get_path_name() == '/Engine/Transient'
        stats = u.MaterialEditingLibrary.get_statistics(candidate)
        assert stats.num_pixel_shader_instructions > 0 and stats.num_vertex_shader_instructions > 0
        targets[family] = dict(actor=actor, component=component, original=original, candidate=candidate, before=copy.deepcopy(base.owned(actor)), proof=proof)
    STATE = dict(base=base, gate=gate, targets=targets, values=base.load('material_graph_values_r02'), links=base.load('material_graph_links_r01'), snapshots=base.load('catacomb_plane_normal_materials'), on=False)
    check()
    print('THREE_OWNED_SURFACE_WHITE_TINT_AXIS_READY')


def white(on):
    assert isinstance(on, bool)
    check()
    t = STATE
    s = t['base'].STATE
    for row in t['targets'].values():
        material = row['candidate'] if on else row['original']
        row['component'].set_material(0, material)
        expected = copy.deepcopy(row['before'])
        expected['materials'][0] = material.get_path_name()
        assert t['base'].owned(row['actor']) == expected
        s['owned_expected'][s['created'].index(row['actor'])] = expected
    t['on'] = on
    check()


def capture(label):
    import unreal as u
    t = STATE
    u.GameplayStatics.set_game_paused(t['base'].STATE['world'], True)
    check()
    t['base'].capture(label)
    path = t['base'].STATE['capture'].STATE['out']/(label+'.json')
    record = json.loads(path.read_text())
    record['white_tint_parity'] = dict(on=t['on'], boundary='Only three owned surface slot0 bindings toggle between accepted originals and graph copies with RoomTint=(1,1,1). Original HISM groups, props, water, physics, mechanisms, textures, lights and source packages remain unchanged. No room palette or source adoption.')
    path.write_text(json.dumps(record, indent=2)+'\n')


def release():
    global STATE
    white(False)
    STATE = None
    print('WHITE_TINT_SOURCE_BINDINGS_RESTORED_REFERENCES_RELEASED')


def abort(base):
    global STATE
    try:
        if STATE:
            for row in STATE['targets'].values():
                row['component'].set_material(0, row['original'])
                base.STATE['owned_expected'][base.STATE['created'].index(row['actor'])] = copy.deepcopy(row['before'])
    finally:
        STATE = None
        base.abort()
