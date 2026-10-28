"""Read pin/channel links explicitly; reject ambiguous reused input parents."""


def read(material):
    import unreal as u
    mel = u.MaterialEditingLibrary
    nodes = {}
    for node in u.ObjectIterator(u.MaterialExpression):
        if node.get_outer() != material:
            continue
        pins = list(map(str, mel.get_material_expression_input_names(node)))
        inputs = list(mel.get_inputs_for_material_expression(material, node))
        assert len(pins) == len(inputs)
        nonempty = [v.get_path_name() for v in inputs if v]
        assert len(set(nonempty)) == len(nonempty)
        links = []
        for pin, parent in zip(pins, inputs):
            output = mel.get_input_node_output_name_for_material_expression(node, parent) if parent else None
            assert parent is None or output is not None
            links.append(dict(pin=pin, node=parent.get_name() if parent else None, channel=output))
        nodes[node.get_name()] = dict(cls=node.get_class().get_name(), inputs=links)
    outputs = {}
    for prop in [u.MaterialProperty.MP_BASE_COLOR, u.MaterialProperty.MP_NORMAL, u.MaterialProperty.MP_ROUGHNESS, u.MaterialProperty.MP_METALLIC]:
        node = mel.get_material_property_input_node(material, prop)
        outputs[str(prop)] = dict(node=node.get_name() if node else None, channel=mel.get_material_property_input_node_output_name(material, prop))
    return dict(nodes=nodes, outputs=outputs)
