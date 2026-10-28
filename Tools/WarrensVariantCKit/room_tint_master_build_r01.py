"""Clone an accepted family graph into a new transient, adding only RoomTint."""
from pathlib import Path
import hashlib
import importlib.util

ROOT = Path(__file__).resolve().parents[2]
PARENTS = '/Game/Mars/ArtReview/Lookdev/CatacombCompleteRoom_20261026R02/PBR_R09/Materials/'
PROPERTIES = ['blend_mode', 'shading_model', 'two_sided', 'tangent_space_normal', 'used_with_instanced_static_meshes', 'material_domain', 'fully_rough', 'dithered_lod_transition', 'use_material_attributes']


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def build(destination, family):
    import unreal as u
    assert family in ('Walls', 'Floor', 'Ceiling')
    assert isinstance(destination, u.Material) and destination.get_outer().get_path_name() == '/Engine/Transient'
    assert not [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer() == destination]
    source = u.load_asset(PARENTS+'M_CP_'+family+'_PBR_R09')
    source_disk = ROOT/('Content/'+source.get_path_name().split('.')[0].removeprefix('/Game/')+'.uasset')
    original_digest = sha(source_disk)
    path = Path(__file__).with_name('material_graph_values_r02.py')
    spec = importlib.util.spec_from_file_location('_room_tint_values', path)
    reader = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(reader)
    before = reader.read(source)
    mel = u.MaterialEditingLibrary
    nodes = sorted([n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer() == source], key=lambda n: n.get_name())
    assert len(nodes) == (25 if family == 'Walls' else 31)
    copies = {}
    for name in PROPERTIES:
        destination.set_editor_property(name, source.get_editor_property(name))
    for node in nodes:
        duplicate = mel.duplicate_material_expression(destination, None, node)
        assert duplicate and duplicate.get_outer() == destination
        copies[node.get_name()] = duplicate
    for node in nodes:
        names = list(map(str, mel.get_material_expression_input_names(node)))
        inputs = list(mel.get_inputs_for_material_expression(source, node))
        assert len(names) == len(inputs)
        nonempty = [v.get_path_name() for v in inputs if v]
        # The output-name API returns the first match for a given source node.
        # Reject ambiguity rather than guessing the pin/channel association.
        assert len(set(nonempty)) == len(nonempty)
        for name, parent in zip(names, inputs):
            if parent:
                output = mel.get_input_node_output_name_for_material_expression(node, parent)
                assert output is not None
                assert mel.connect_material_expressions(copies[parent.get_name()], output, copies[node.get_name()], name)
        actual = list(mel.get_inputs_for_material_expression(destination, copies[node.get_name()]))
        assert actual == [copies[v.get_name()] if v else None for v in inputs]
    outputs = [u.MaterialProperty.MP_BASE_COLOR, u.MaterialProperty.MP_NORMAL, u.MaterialProperty.MP_ROUGHNESS, u.MaterialProperty.MP_METALLIC]
    for prop in outputs:
        original = mel.get_material_property_input_node(source, prop)
        assert original
        output = mel.get_material_property_input_node_output_name(source, prop)
        assert mel.connect_material_property(copies[original.get_name()], output, prop)
    for prop in [u.MaterialProperty.MP_WORLD_POSITION_OFFSET, u.MaterialProperty.MP_EMISSIVE_COLOR, u.MaterialProperty.MP_AMBIENT_OCCLUSION, u.MaterialProperty.MP_SPECULAR, u.MaterialProperty.MP_OPACITY, u.MaterialProperty.MP_OPACITY_MASK]:
        assert mel.get_material_property_input_node(source, prop) is None
    original_colour = mel.get_material_property_input_node(destination, u.MaterialProperty.MP_BASE_COLOR)
    original_output = mel.get_material_property_input_node_output_name(destination, u.MaterialProperty.MP_BASE_COLOR)
    tint = mel.create_material_expression(destination, u.MaterialExpressionVectorParameter, 1200, 0)
    tint.set_editor_property('parameter_name', 'RoomTint')
    tint.set_editor_property('default_value', u.LinearColor(1, 1, 1, 1))
    multiply = mel.create_material_expression(destination, u.MaterialExpressionMultiply, 1400, 0)
    assert mel.connect_material_expressions(original_colour, original_output, multiply, 'A')
    assert mel.connect_material_expressions(tint, 'RGB', multiply, 'B')
    assert mel.connect_material_property(multiply, '', u.MaterialProperty.MP_BASE_COLOR)
    after = reader.read(destination)
    for node in nodes:
        assert after[copies[node.get_name()].get_name()] == before[node.get_name()]
    assert reader.read(source) == before and sha(source_disk) == original_digest
    assert all(destination.get_editor_property(k) == source.get_editor_property(k) for k in PROPERTIES)
    mel.recompile_material(destination)
    return dict(status='TRANSIENT_ACCEPTED_FAMILY_GRAPH_COPY_WITH_WHITE_ROOM_TINT_NOT_BOUND', family=family, source=source.get_path_name(), source_sha256=original_digest, source_values=before, destination=destination.get_path_name(), copied_node_map={k: v.get_name() for k, v in copies.items()}, explicit_values=after, tool_sha256=sha(__file__), reader_sha256=sha(path), boundary='New transient graph only. Every accepted source node value and input/channel link is copied; exact source shader properties retained. Only a final BaseColor multiply by RoomTint(default white) is added. Original vertex data stays in native UNorm range; room palette belongs in per-room instances. Native compile and white-tint buffer parity remain required. No source material, texture, asset, map or library save.')
