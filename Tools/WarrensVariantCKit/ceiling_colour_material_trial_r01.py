"""Finite old/new material axis on the two already enumerated raw shell groups."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
STATE = None


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check():
    t = STATE
    assert t and sha(__file__) == t['gate']['colour_trial_sha256']
    t['underlay'].check()
    s = t['underlay'].STATE
    assert s['on'] and s['material'] == (t['candidate'] if t['on'] else t['old'])
    assert s['reader'].snapshot(t['old']) == t['old_snapshot']
    assert s['reader'].snapshot(t['candidate']) == t['new_snapshot']
    assert t['value_reader'].read(t['old']) == t['explicit_values']['old']
    assert t['value_reader'].read(t['candidate']) == t['explicit_values']['new']
    assert t['underlay'].STATE['roof'].STATE['on'] is True


def begin(underlay, candidate):
    import unreal as u
    global STATE
    assert STATE is None
    underlay.check()
    s = underlay.STATE
    assert s['on'] and len(s['targets']) == 2
    gate = json.loads((DOC/'NATIVE_SHELL_UNDERLAY_GATE_R03.json').read_text())
    assert gate['colour_trial_sha256'] == sha(__file__) and gate['tool_sha256'] == sha(underlay.__file__)
    for path, digest in gate['input_sha256'].items():
        assert sha(ROOT/path) == digest
    receipt = json.loads((DOC/'ceiling-underlay-family-r01/transient_build_readback_r01.json').read_text())
    assert candidate.get_path_name() == receipt['material']
    assert candidate.get_outer().get_path_name() == '/Engine/Transient'
    assert candidate.get_editor_property('used_with_instanced_static_meshes') is True
    assert candidate.get_editor_property('phys_material') is None
    graph = s['reader'].snapshot(candidate)
    assert graph == receipt['graph']
    explicit = json.loads((DOC/'ceiling-underlay-family-r01/transient_build_explicit_values_r02.json').read_text())
    value_reader = s['base'].load('material_graph_values_r01')
    assert sha(value_reader.__file__) == explicit['reader_sha256']
    assert value_reader.read(candidate) == explicit['new']
    assert value_reader.read(s['material']) == explicit['old']
    stats = u.MaterialEditingLibrary.get_statistics(candidate)
    assert stats.num_pixel_shader_instructions == 451 and stats.num_vertex_shader_instructions == 150
    assert u.MaterialEditingLibrary.get_material_property_input_node(candidate, u.MaterialProperty.MP_NORMAL).get_path_name() == receipt['normal_output_unchanged']
    assert u.MaterialEditingLibrary.get_material_property_input_node(candidate, u.MaterialProperty.MP_ROUGHNESS).get_path_name() == receipt['roughness_output_unchanged']
    STATE = dict(underlay=underlay, gate=gate, old=s['material'], candidate=candidate, old_snapshot=copy.deepcopy(s['material_snapshot']), new_snapshot=graph, value_reader=value_reader, explicit_values=explicit, on=False)
    check()
    print('CEILING_COLOUR_MATERIAL_AXIS_READY_UNBOUND_CANDIDATE')


def candidate(on):
    assert isinstance(on, bool)
    check()
    t = STATE
    s = t['underlay'].STATE
    material = t['candidate'] if on else t['old']
    s['material'] = material
    s['material_snapshot'] = t['new_snapshot'] if on else t['old_snapshot']
    for row in s['targets']:
        component = row['component']
        component.set_material(0, material)
        expected = copy.deepcopy(row['original'])
        expected['materials'] = [material.get_path_name().split('.')[0]]
        s['base'].STATE['expected_hisms'][component.get_path_name()] = expected
    t['on'] = on
    check()


def capture(label):
    import unreal as u
    t = STATE
    s = t['underlay'].STATE
    u.GameplayStatics.set_game_paused(s['base'].STATE['world'], True)
    check()
    t['underlay'].capture(label)
    path = s['base'].STATE['capture'].STATE['out']/(label+'.json')
    record = json.loads(path.read_text())
    record['ceiling_colour_candidate'] = dict(on=t['on'], material=s['material'].get_path_name(), boundary='Only the downward BaseColor/course material successor on two enumerated raw wall HISM groups. Roof geometry, S3, props, water, lights and all other shading axes fixed. Fitted bays excluded.')
    path.write_text(json.dumps(record, indent=2)+'\n')


def release():
    global STATE
    candidate(False)
    STATE = None
    print('CEILING_COLOUR_OLD_UNDERLAY_BINDINGS_RESTORED_REFERENCES_RELEASED')


def abort(underlay, base, roof, extension):
    global STATE
    try:
        if STATE:
            s = underlay.STATE
            s['material'] = STATE['old']
            s['material_snapshot'] = STATE['old_snapshot']
    finally:
        STATE = None
        underlay.abort(base, roof, extension)
