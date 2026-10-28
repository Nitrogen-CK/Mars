"""Import separate owned R03 lookdev materials; no map or shared asset writes."""
import importlib.util
import json
from pathlib import Path

import unreal as u

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REVIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024'
OUT = REVIEW / 'lookdev/painterly-r03'
DEST = '/Game/Mars/Environment/WarrensVariantCKit/Lookdev/BrushR03'


def main():
    assert u.get_editor_subsystem(u.UnrealEditorSubsystem).get_game_world() is None
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    assert not u.EditorLoadingAndSavingUtils.get_dirty_content_packages()
    spec = importlib.util.spec_from_file_location('warrens_brush_import', HERE.parent / 'ChainCrossingKit/import_assets.py')
    shared = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shared)
    recipes = shared.recipes()
    shared.ART = OUT
    shared.MATERIAL_DEST = DEST
    shared.OWNER = 'Mars.WarrensC.BrushR03.20261024'
    shared.TAG = 'WarrensBrushOwner'
    shared.RECIPE_VERSION = 3
    report = {}
    for key in ('TX01', 'TX02'):
        recipe = dict(recipes[key])
        recipe['texture_weight'] = .60
        recipe['maps'] = {channel: f'{key}_Brush_{channel}.png' for channel in ('BaseColor', 'ORM', 'NormalDX')}
        textures = {relative: shared.import_texture(shared.texture_spec(relative, channel, recipe)) for channel, relative in recipe['maps'].items()}
        material = shared.make_material(key, recipe, textures)
        report[key] = dict(material=material.get_path_name(), textures=[t.get_path_name() for t in textures.values()], texture_weight=.60,
                           surface_axis='Albedo only: original quiet roughness .88 and disconnected normal preserved. New ORM/NormalDX imported for later separate surface comparison.')
    assert not u.EditorLoadingAndSavingUtils.get_dirty_map_packages()
    (OUT / 'unreal_import.json').write_text(json.dumps(report, indent=2) + '\n')
    print('WARRENS_BRUSH_IMPORT', json.dumps(report))


if __name__ == '__main__':
    main()
