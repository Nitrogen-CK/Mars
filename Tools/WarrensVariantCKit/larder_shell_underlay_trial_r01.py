"""Material-only disposable shared-shell trial; no native package saves."""
import copy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
STATE = None
OLD = '/Game/Mars/Environment/ChainCrossingKit/Materials/M_CCK_TX01'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def check():
    t = STATE
    assert t and sha(__file__) == t['gate']['tool_sha256']
    t['roof'].check()
    for row in t['targets']:
        component = row['component']
        assert t['base'].flags(component) == row['flags']
        assert component.get_editor_property('body_instance').export_text() == row['original']['body_instance']
        assert component.get_material(0) == (t['material'] if t['on'] else row['material'])
    assert t['reader'].snapshot(t['material']) == t['material_snapshot']


def begin(base, roof):
    import unreal as u
    global STATE
    assert STATE is None
    roof.check()
    gate = json.loads((DOC/'NATIVE_SHELL_UNDERLAY_GATE_R01.json').read_text())
    assert gate['status'] == 'APPROVED_TWO_COMPONENT_DISPOSABLE_STATIC_SHELL_MATERIAL_TRIAL'
    assert gate['tool_sha256'] == sha(__file__) and base.RUN.relative_to(ROOT).as_posix() == gate['run']
    assert base.STATE['capture'].STATE['out'].relative_to(ROOT).as_posix() == gate['capture_folder']
    for path, digest in gate['input_sha256'].items():
        assert sha(ROOT/path) == digest
    s = base.STATE
    material = roof.STATE['extension'].STATE['s3_parent']
    assert material.get_editor_property('phys_material') is None
    assert material.get_editor_property('used_with_instanced_static_meshes') is True
    statistics = u.MaterialEditingLibrary.get_statistics(material)
    assert statistics.num_pixel_shader_instructions > 0 and statistics.num_vertex_shader_instructions > 0
    reader = base.load('catacomb_plane_normal_materials')
    plan = json.loads((ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json').read_text())
    geometry = base.load('catacomb_pilot_manifest')
    rooms = [(r['id'], geometry.roompoly(r), r['z'], r.get('top', r['z']+3.5)) for r in plan['rooms']]
    rooms += [(r['id'], geometry.rectpoly(r['rect']), r['z'], r.get('top', r['z']+3.5)) for r in plan['niches']]
    targets = []
    for tile in ('Brineworks', 'Belfry'):
        actor, = [a for a in u.GameplayStatics.get_all_actors_of_class(s['world'], u.Actor) if a.get_actor_label() == 'Warrens_Greybox_wall' and a.get_level().get_path_name().split('/')[-1].startswith('UEDPIE_0_LI_Warrens_'+tile+'_LevelInstance_')]
        component, = actor.get_components_by_class(u.HierarchicalInstancedStaticMeshComponent)
        assert component.static_mesh.get_path_name() == '/Engine/BasicShapes/Cube.Cube'
        assert len(component.get_materials()) == 1 and component.mobility == u.ComponentMobility.STATIC
        original_material = component.get_material(0)
        assert original_material.get_path_name().split('.')[0] == OLD and original_material.get_editor_property('phys_material') is None
        parent = original_material.get_editor_property('parent')
        while isinstance(parent, u.MaterialInstanceConstant):
            assert parent.get_editor_property('phys_material') is None
            parent = parent.get_editor_property('parent')
        assert isinstance(parent, u.Material) and parent.get_editor_property('phys_material') is None
        original = copy.deepcopy(s['expected_hisms'][component.get_path_name()])
        assert original == s['before'][component.get_path_name()]
        assignments = []
        for index, pose in enumerate(original['instances']):
            x, y = pose['at'][0]/100+70, pose['at'][1]/100+55
            assert max(abs(v) for v in pose['q'][:3]) < 1e-8 and abs(pose['q'][3]-1) < 1e-8
            centre = [x, y, pose['at'][2]/100]
            low = [centre[k]-pose['scale'][k]/2 for k in range(3)]
            high = [centre[k]+pose['scale'][k]/2 for k in range(3)]
            candidates = [name for name, poly, zlow, zhigh in rooms if low[2] <= zhigh and high[2] >= zlow and all(low[k] <= max(v[k] for v in poly) and high[k] >= min(v[k] for v in poly) for k in (0, 1))]
            assignments.append(dict(instance=index, plan_bounds_min=low, plan_bounds_max=high, room_niche_AABB_candidates=candidates))
        targets.append(dict(tile=tile, component=component, material=original_material, original=original, flags=base.flags(component), room_assignments=assignments))
    assert len(targets) == 2
    STATE = dict(base=base, roof=roof, gate=gate, material=material, reader=reader, material_snapshot=reader.snapshot(material), targets=targets, on=False)
    check()
    record = dict(status='TWO_STATIC_SHELL_COMPONENTS_ENUMERATED_NO_ADOPTION', material=material.get_path_name(), material_snapshot=STATE['material_snapshot'], targets=[dict(tile=r['tile'], original=r['original'], flags=r['flags'], instance_context_candidates=r['room_assignments']) for r in targets], boundary='Every affected instance is enumerated. Room/niche AABB candidates conservatively describe possible context, not exact polygon intersections or unique ownership. Long walls can meet several rooms. Only original wall HISM slot0 can toggle; mesh/instances/body/flags remain exact. Both old material inheritance and new parent have no physical-material override. This does not prove packaged physical-material behavior.')
    (s['capture'].STATE['out']/'underlay_targets.json').write_text(json.dumps(record, indent=2)+'\n')
    print('STATIC_SHELL_UNDERLAY_READY', [(r['tile'], len(r['original']['instances'])) for r in targets])


def visible(on):
    assert isinstance(on, bool)
    check()
    t = STATE
    s = t['base'].STATE
    for row in t['targets']:
        component = row['component']
        component.set_material(0, t['material'] if on else row['material'])
        expected = copy.deepcopy(row['original'])
        if on:
            expected['materials'] = [t['material'].get_path_name().split('.')[0]]
        s['expected_hisms'][component.get_path_name()] = expected
    t['on'] = on
    check()


def capture(label):
    import unreal as u
    t = STATE
    u.GameplayStatics.set_game_paused(t['base'].STATE['world'], True)
    check()
    t['roof'].capture(label)
    path = t['base'].STATE['capture'].STATE['out']/(label+'.json')
    record = json.loads(path.read_text())
    record['shell_underlay'] = dict(on=t['on'], material=t['material'].get_path_name(), targets=[r['component'].get_path_name() for r in t['targets']], boundary='Only two exact original static wall HISM material-slot0 bindings toggle. All original instances, physics, flags and all other art remain fixed.')
    path.write_text(json.dumps(record, indent=2)+'\n')


def release():
    global STATE
    visible(False)
    STATE = None
    print('STATIC_SHELL_UNDERLAY_ORIGINAL_BINDINGS_RESTORED_REFERENCES_RELEASED')


def abort(base, roof, extension):
    global STATE
    try:
        if STATE:
            for row in STATE['targets']:
                row['component'].set_material(0, row['material'])
                base.STATE['expected_hisms'][row['component'].get_path_name()] = copy.deepcopy(row['original'])
    finally:
        STATE = None
        roof.abort(base, extension)
