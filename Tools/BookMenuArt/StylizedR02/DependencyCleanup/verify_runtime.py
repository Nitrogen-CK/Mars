"""Run in the probe's public Python scope; collect the actual native page lifecycle."""
def cookbook_verify_textures(label, expected_count):
    book = next(c for c in unreal.ObjectIterator(unreal.SkeletalMeshComponent)
                if c.get_world() == cookbook_world() and 'CookbookPresentation' in c.get_class().get_name())
    widgets = [w for w in unreal.ObjectIterator(unreal.Ck_UserWidget_UE)
               if w.get_world() == cookbook_world() and w.get_class().get_name().startswith('Cookbook_')]
    textures = [book.get_material(slot).get_texture_parameter_value('BC')
                for slot in range(2,6) if isinstance(book.get_material(slot), unreal.MaterialInstanceDynamic)]
    result = {'label': label, 'state': str(book.get_editor_property('_State')),
              'section': book.get_editor_property('_PageSectionIndex'),
              'textures': [t.get_path_name() for t in textures],
              'widget_classes': [w.get_class().get_path_name() for w in widgets],
              'all_ck_widgets': all(isinstance(w, unreal.Ck_UserWidget_UE) for w in widgets),
              'all_texture2d': all(isinstance(t, unreal.Texture2D) for t in textures),
              'material_textures': [book.get_material(slot).get_texture_parameter_value('BC').get_path_name()
                                    if isinstance(book.get_material(slot), unreal.MaterialInstanceDynamic) else None
                                    for slot in range(2,6)]}
    assert len(textures) == (4 if expected_count else 0), result
    assert len(widgets) == expected_count, result
    assert result['all_ck_widgets'] and result['all_texture2d'], result
    if expected_count:
        assert all(t in result['textures'] for t in result['material_textures']), result
    else:
        assert all(t is None for t in result['material_textures']), result
    (COOKBOOK_CAPTURE_ROOT/(label+'.json')).write_text(json.dumps(result, indent=2))
    print('COOKBOOK_CK_TEXTURES '+json.dumps(result))
