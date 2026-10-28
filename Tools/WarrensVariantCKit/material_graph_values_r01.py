"""Explicit shader values that Unreal Python descriptors omit from snapshots."""


def read(material):
    import unreal as u
    rows = {}
    fields = {
        'MaterialExpressionCustom': ['code', 'output_type'],
        'MaterialExpressionScalarParameter': ['parameter_name', 'default_value'],
        'MaterialExpressionVectorParameter': ['parameter_name', 'default_value'],
        'MaterialExpressionTextureSample': ['texture', 'sampler_type', 'const_coordinate', 'sampler_source', 'mip_value_mode'],
        'MaterialExpressionTextureCoordinate': ['coordinate_index', 'u_tiling', 'v_tiling', 'un_mirror_u', 'un_mirror_v'],
        'MaterialExpressionWorldPosition': ['world_position_shader_offset'],
        'MaterialExpressionConstant': ['r'],
        'MaterialExpressionConstant3Vector': ['constant'],
        'MaterialExpressionComponentMask': ['r', 'g', 'b', 'a'],
        'MaterialExpressionMultiply': ['const_a', 'const_b'],
        'MaterialExpressionAdd': ['const_a', 'const_b'],
        'MaterialExpressionLinearInterpolate': ['const_a', 'const_b', 'const_alpha'],
        'MaterialExpressionTransform': ['transform_source_type', 'transform_type'],
    }

    def value(v):
        if isinstance(v, u.Object):
            return v.get_path_name()
        if isinstance(v, u.StructBase):
            return v.export_text()
        if v is None or isinstance(v, (str, int, float, bool)):
            return v
        return str(v)

    for node in u.ObjectIterator(u.MaterialExpression):
        if node.get_outer() != material:
            continue
        kind = node.get_class().get_name()
        properties = {name: value(node.get_editor_property(name)) for name in fields.get(kind, [])}
        if kind == 'MaterialExpressionCustom':
            properties['custom_inputs'] = [v.export_text() for v in node.get_editor_property('inputs')]
            properties['include_file_paths'] = list(map(str, node.get_editor_property('include_file_paths')))
            properties['additional_defines'] = [v.export_text() for v in node.get_editor_property('additional_defines')]
        rows[node.get_name()] = dict(cls=kind, values=properties)
    assert rows and any(r['cls'] == 'MaterialExpressionCustom' and r['values']['code'] for r in rows.values())
    return rows
