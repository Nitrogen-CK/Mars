"""Compare copied custom graphs while retaining their intended new object owners."""
import copy
import importlib.util
from pathlib import Path


def load(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_material_copy_semantic_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m


def readback(destination,source,node_map):
    import unreal as u
    reader=load('material_graph_values_r02');links=load('material_graph_links_r01');snapshot=load('catacomb_plane_normal_materials')
    source_values=reader.read(source);actual_values=reader.read(destination)
    reverse={v:k for k,v in node_map.items()}
    assert len(reverse)==len(node_map)==len(source_values)==len(actual_values)
    # Same node names cannot conceal an input still pointing into the transient source.
    mel=u.MaterialEditingLibrary
    properties=[u.MaterialProperty.MP_BASE_COLOR,u.MaterialProperty.MP_NORMAL,u.MaterialProperty.MP_ROUGHNESS,u.MaterialProperty.MP_METALLIC,u.MaterialProperty.MP_WORLD_POSITION_OFFSET,u.MaterialProperty.MP_EMISSIVE_COLOR,u.MaterialProperty.MP_AMBIENT_OCCLUSION,u.MaterialProperty.MP_SPECULAR,u.MaterialProperty.MP_OPACITY,u.MaterialProperty.MP_OPACITY_MASK]
    for material,allowed in [(source,set(node_map)),(destination,set(reverse))]:
        nodes=[n for n in u.ObjectIterator(u.MaterialExpression) if n.get_outer()==material]
        assert {n.get_name() for n in nodes}==allowed
        for node in nodes:
            for parent in mel.get_inputs_for_material_expression(material,node):
                if parent:
                    assert parent.get_outer()==material and parent.get_name() in allowed
                    assert parent.get_path_name()==material.get_path_name()+':'+parent.get_name()
        for prop in properties:
            terminal=mel.get_material_property_input_node(material,prop)
            if terminal:
                assert terminal.get_outer()==material and terminal.get_name() in allowed
                assert terminal.get_path_name()==material.get_path_name()+':'+terminal.get_name()
    canonical={reverse[k]:copy.deepcopy(v) for k,v in actual_values.items()}
    for record in canonical.values():
        if record['cls']=='MaterialExpressionCustom':
            rewritten=[]
            for value in record['values']['custom_inputs']:
                for new_name,old_name in reverse.items():
                    value=value.replace(destination.get_path_name()+':'+new_name+"'",source.get_path_name()+':'+old_name+"'")
                rewritten.append(value)
            record['values']['custom_inputs']=rewritten
    assert canonical==source_values
    source_links=links.read(source);actual_links=links.read(destination)
    canonical_links=dict(nodes={reverse[k]:dict(cls=v['cls'],inputs=[dict(pin=x['pin'],node=reverse[x['node']] if x['node'] else None,channel=x['channel']) for x in v['inputs']]) for k,v in actual_links['nodes'].items()},outputs={k:dict(node=reverse[v['node']] if v['node'] else None,channel=v['channel']) for k,v in actual_links['outputs'].items()})
    assert canonical_links==source_links
    source_graph=snapshot.snapshot(source);actual_graph=snapshot.snapshot(destination)
    assert actual_graph['properties']==source_graph['properties']
    canonical_nodes={reverse[k]:dict(cls=v['cls'],properties=v['properties'],inputs=[dict(pin=x['pin'],node=reverse[x['node']] if x['node'] else None) for x in v['inputs']]) for k,v in actual_graph['nodes'].items()}
    assert canonical_nodes==source_graph['nodes']
    canonical_outputs={k:source.get_path_name()+':'+reverse[v.rsplit(':',1)[1]] if v else None for k,v in actual_graph['outputs'].items()}
    assert canonical_outputs==source_graph['outputs']
    names=load('room_tint_master_build_r01').PROPERTIES
    props={k:snapshot.serial(source.get_editor_property(k)) for k in names}
    assert {k:snapshot.serial(destination.get_editor_property(k)) for k in names}==props
    stats=mel.get_statistics(destination);source_stats=mel.get_statistics(source)
    keys=['num_vertex_shader_instructions','num_pixel_shader_instructions','num_pixel_texture_samples','num_vertex_texture_samples','num_samplers','num_interpolator_scalars','num_uv_scalars','num_virtual_texture_samples']
    actual_stats={k:getattr(stats,k) for k in keys}
    assert actual_stats=={k:getattr(source_stats,k) for k in keys} and actual_stats['num_pixel_shader_instructions']>0
    assert reader.read(source)==source_values and links.read(source)==source_links and snapshot.snapshot(source)==source_graph
    return dict(source=source.get_path_name(),destination=destination.get_path_name(),source_readback=dict(values=source_values,links=source_links,graph=source_graph),explicit_values=actual_values,explicit_material_properties=props,links=actual_links,graph=snapshot.snapshot(destination),node_map=node_map,compile_statistics=actual_stats,boundary='Only Custom input Expression object references map to corresponding nodes in the new owning material. Code, input names, masks, indices, parameter defaults, texture paths, links, terminal properties and explicit nine flags remain exact. No shader text or external asset path normalization or graph mutation.')
