"""Restore evaluated Blender morph animation explicitly after UE FBX import.

The FBX armature dummy is deliberately stripped for a clean 12-bone hierarchy;
its custom properties do not arrive as animation curves. Read actual clamped
shape-key values exported from the source .blend instead of guessing them.
"""
import json
from pathlib import Path

import unreal

ROOT = Path(__file__).resolve().parent
DEST = '/Game/Mars/Gameplay/PlayerCookbook/StylizedR02'
samples = json.loads((ROOT / 'Model' / 'morph_curves.json').read_text())
report = {'sample_source': samples['sample_source'], 'clips': {}}
clip_names = {
    'Book_Lying_R_01': 'Cookbook_Closed_AS',
    'Book_Lying_Open_01': 'Cookbook_Open_AS',
    'Book_Lying_R_to_Open_01': 'Cookbook_Opening_AS',
    'Book_Lying_Open_to_R_01': 'Cookbook_Closing_AS',
    'Book_Lying_Open_Page_Turn_R_to_L_02': 'Cookbook_TurnForward_AS',
    'Book_Lying_Open_Page_Turn_L_to_R_02': 'Cookbook_TurnReverse_AS',
}
for name, action in samples['actions'].items():
    sequence = unreal.load_asset(DEST + '/Animations/' + clip_names[name])
    assert isinstance(sequence, unreal.AnimSequence), name
    skeleton = sequence.get_skeleton()
    controller = sequence.get_editor_property('controller')
    data = sequence.get_editor_property('data_model_interface')
    before = data.get_number_of_float_curves()
    controller.open_bracket('Cookbook evaluated morph samples')
    for curve_name, values in action['curves'].items():
        skeleton.add_curve_meta_data(curve_name)
        skeleton.set_curve_meta_data_morph_target(curve_name, True)
        identifier = unreal.AnimationCurveIdentifier()
        identifier.set_curve_identifier(curve_name, unreal.RawCurveTrackTypes.RCT_FLOAT)
        if before == 0:
            assert controller.add_curve(identifier), curve_name
        keys = []
        for time, value in zip(action['times'], values):
            key = unreal.RichCurveKey()
            key.set_editor_property('time', time)
            key.set_editor_property('value', value)
            key.set_editor_property('interp_mode', unreal.RichCurveInterpMode.RCIM_LINEAR)
            keys.append(key)
        assert controller.set_curve_keys(identifier, keys), curve_name
    controller.close_bracket()
    assert data.get_number_of_float_curves() == 4
    curve_report = {}
    for curve_name, expected in action['curves'].items():
        actual_times, actual_values = unreal.AnimationLibrary.get_float_keys(sequence, curve_name)
        assert len(actual_values) == len(expected)
        value_error = max(abs(a - b) for a, b in zip(actual_values, expected))
        time_error = max(abs(a - b) for a, b in zip(actual_times, action['times']))
        assert value_error < 1e-6 and time_error < 1e-6, (name, curve_name, value_error, time_error)
        assert skeleton.get_curve_meta_data_morph_target(curve_name)
        curve_report[curve_name] = {'keys': len(actual_values), 'minimum': min(actual_values),
                                   'maximum': max(actual_values), 'max_value_error': value_error,
                                   'max_time_error': time_error, 'morph_metadata': True}
    assert unreal.EditorAssetLibrary.save_loaded_asset(sequence)
    assert unreal.EditorAssetLibrary.save_loaded_asset(skeleton)
    report['clips'][name] = {'curves_before': before, 'curves_after': 4, 'verified': curve_report}
(ROOT / 'unreal_morph_report.json').write_text(json.dumps(report, indent=2))
print('COOKBOOK_MORPHS ' + json.dumps({name: {'before': item['curves_before'], 'after': item['curves_after']}
                                     for name, item in report['clips'].items()}))
