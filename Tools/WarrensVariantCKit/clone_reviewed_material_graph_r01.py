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
    # Use the source names as canonical graph identities even if Unreal renumbers copies.
    reverse={v.get_name():k for k,v in copies.items()}
    after_values=values.read(destination)
    assert {reverse[k]:v for k,v in after_values.items()}==before['values']
    after_links=links.read(destination)
    canonical_links=dict(nodes={reverse[k]:dict(cls=v['cls'],inputs=[dict(pin=x['pin'],node=reverse[x['node']] if x['node'] else None,channel=x['channel']) for x in v['inputs']]) for k,v in after_links['nodes'].items()},outputs={k:dict(node=reverse[v['node']] if v['node'] else None,channel=v['channel']) for k,v in after_links['outputs'].items()})
    assert canonical_links==before['links']
    after_graph=snapshot.snapshot(destination)
    assert after_graph['properties']==before['graph']['properties']
    canonical_nodes={reverse[k]:dict(cls=v['cls'],properties=v['properties'],inputs=[dict(pin=x['pin'],node=reverse[x['node']] if x['node'] else None) for x in v['inputs']]) for k,v in after_graph['nodes'].items()}
    assert canonical_nodes==before['graph']['nodes']
    canonical_outputs={k:source.get_path_name()+':'+reverse[v.rsplit(':',1)[1]] if v else None for k,v in after_graph['outputs'].items()}
    assert canonical_outputs==before['graph']['outputs']
    assert values.read(source)==before['values'] and links.read(source)==before['links'] and snapshot.snapshot(source)==before['graph']
    mel.recompile_material(destination)
    stats=mel.get_statistics(destination);source_stats=mel.get_statistics(source)
    statkeys=['num_vertex_shader_instructions','num_pixel_shader_instructions','num_pixel_texture_samples','num_vertex_texture_samples','num_samplers','num_interpolator_scalars','num_uv_scalars','num_virtual_texture_samples']
    actual={k:getattr(stats,k) for k in statkeys}
    assert actual=={k:getattr(source_stats,k) for k in statkeys} and actual['num_pixel_shader_instructions']>0 and actual['num_vertex_shader_instructions']>0
    assert {k:snapshot.serial(destination.get_editor_property(k)) for k in property_names}==explicit_properties
    return dict(source=source.get_path_name(),destination=destination.get_path_name(),source_readback=before,explicit_values=after_values,explicit_material_properties=explicit_properties,links=after_links,graph=snapshot.snapshot(destination),node_map={k:v.get_name() for k,v in copies.items()},compile_statistics=actual,tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),boundary='Exact node-value/input-channel graph copy, nine explicit shader flags and readable material properties. Protected/deprecated property read errors remain explicit. No look tuning, source graph or source package writes. Only an empty private destination is authored.')
