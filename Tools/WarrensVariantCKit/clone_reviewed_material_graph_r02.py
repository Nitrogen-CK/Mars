"""Copy a reviewed material graph into an empty owned destination without edits."""
import hashlib
import importlib.util
from pathlib import Path


def load(name):
    path=Path(__file__).with_name(name+'.py')
    spec=importlib.util.spec_from_file_location('_clone_reviewed_'+name,path)
    result=importlib.util.module_from_spec(spec);spec.loader.exec_module(result)
    return result


def build(destination,source):
    import unreal as u
    assert isinstance(source,u.Material) and source.get_outer().get_path_name()=='/Engine/Transient'
    assert isinstance(destination,u.Material) and destination.get_path_name().startswith('/Game/Mars/ArtReview/Lookdev/LarderCompleteRoom_20261027R01/Persist_R01/Materials/')
    assert not [n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==destination]
    values=load('material_graph_values_r02');links=load('material_graph_links_r01');snapshot=load('catacomb_plane_normal_materials')
    before=dict(values=values.read(source),links=links.read(source),graph=snapshot.snapshot(source))
    mel=u.MaterialEditingLibrary
    property_names=load('room_tint_master_build_r01').PROPERTIES
    explicit_properties={k:snapshot.serial(source.get_editor_property(k)) for k in property_names}
    for name in property_names:
        destination.set_editor_property(name,source.get_editor_property(name))
    assert {k:snapshot.serial(destination.get_editor_property(k)) for k in property_names}==explicit_properties
    nodes=sorted([n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==source],key=lambda n:n.get_name())
    copies={n.get_name():mel.duplicate_material_expression(destination,None,n) for n in nodes}
    assert all(n and n.get_outer()==destination for n in copies.values())
    for node in nodes:
        pins=list(map(str,mel.get_material_expression_input_names(node)))
        inputs=list(mel.get_inputs_for_material_expression(source,node))
        assert len(pins)==len(inputs)
        paths=[p.get_path_name() for p in inputs if p]
        assert len(set(paths))==len(paths)
        for pin,parent in zip(pins,inputs):
            if parent:
                channel=mel.get_input_node_output_name_for_material_expression(node,parent)
                assert channel is not None
                assert mel.connect_material_expressions(copies[parent.get_name()],channel,copies[node.get_name()],pin)
    for prop in [u.MaterialProperty.MP_BASE_COLOR,u.MaterialProperty.MP_NORMAL,u.MaterialProperty.MP_ROUGHNESS,u.MaterialProperty.MP_METALLIC,u.MaterialProperty.MP_WORLD_POSITION_OFFSET,u.MaterialProperty.MP_EMISSIVE_COLOR,u.MaterialProperty.MP_AMBIENT_OCCLUSION,u.MaterialProperty.MP_SPECULAR,u.MaterialProperty.MP_OPACITY,u.MaterialProperty.MP_OPACITY_MASK]:
        original=mel.get_material_property_input_node(source,prop)
        if original:
            assert mel.connect_material_property(copies[original.get_name()],mel.get_material_property_input_node_output_name(source,prop),prop)
        else:
            assert mel.get_material_property_input_node(destination,prop) is None
    mel.recompile_material(destination)
    return load('material_copy_semantic_readback_r01').readback(destination,source,{k:v.get_name() for k,v in copies.items()})
