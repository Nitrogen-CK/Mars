"""Fixed-axis world-metric albedo coordinates for static cardinal wall faces."""


def add_blender(material, image_node, normal_axis, tile_metres=2.0):
    assert normal_axis in (0, 1) and tile_metres > 0
    tree = material.node_tree
    assert image_node.id_data == tree and image_node.type == 'TEX_IMAGE'
    assert image_node.extension == 'REPEAT' and not image_node.inputs['Vector'].is_linked
    old_nodes = {n.name for n in tree.nodes}
    old_links = {(l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier) for l in tree.links}
    position = tree.nodes.new('ShaderNodeNewGeometry')
    separate = tree.nodes.new('ShaderNodeSeparateXYZ')
    plane = tree.nodes.new('ShaderNodeCombineXYZ')
    scale = tree.nodes.new('ShaderNodeVectorMath')
    for node, label in ((position,'WorldPosition'),(separate,'WorldAxes'),(plane,'WallPlane'),(scale,'MetresPerRepeat')):
        node.name = 'WarrensProjection_' + label
    scale.operation = 'SCALE'
    scale.inputs['Scale'].default_value = 1.0/tile_metres
    plane.inputs['Z'].default_value = 0
    sockets = [(position.outputs['Position'], separate.inputs['Vector']),
               (separate.outputs['Y' if normal_axis == 0 else 'X'], plane.inputs['X']),
               (separate.outputs['Z'], plane.inputs['Y']),
               (plane.outputs['Vector'], scale.inputs[0]),
               (scale.outputs['Vector'], image_node.inputs['Vector'])]
    for output, input in sockets:
        tree.links.new(output, input)
    expected_links = old_links | {(o.node.name,o.identifier,i.node.name,i.identifier) for o,i in sockets}
    actual_links = {(l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier) for l in tree.links}
    assert actual_links == expected_links and len(tree.nodes) == len(old_nodes)+4
    return dict(normal_axis=normal_axis, tangent_axis=1-normal_axis, vertical_axis=2,
        tile_metres=tile_metres, world_space=True, added_nodes=[n.name for n in (position,separate,plane,scale)],
        only_delta='Four coordinate nodes and five links into this owned albedo sample Vector input; no image, tint/mix, PBR, geometry or mesh UV change.')
