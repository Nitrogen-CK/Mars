"""Reparent only the six live cookbook pages; preserve layouts and package paths."""
import json
from pathlib import Path
import shutil
import unreal

root = Path(__file__).resolve().parent
repo = root.parents[3]
registry = unreal.AssetRegistryHelpers.get_asset_registry()
options = unreal.AssetRegistryDependencyOptions(include_soft_package_references=True, include_hard_package_references=True)
report = {'widgets': []}
for spread in ['Index', 'Sample', 'Notes']:
    for side in ['Left', 'Right']:
        name = f'Cookbook_{spread}_{side}_WBP'
        path = f'/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/{name}'
        source = repo/f'Content/Mars/Gameplay/PlayerCookbook/StylizedR02/Widgets/{name}.uasset'
        backup = root/'Before'/source.name
        backup.parent.mkdir(exist_ok=True)
        if not backup.exists():
            shutil.copy2(source, backup)
        blueprint = unreal.load_asset(path)
        generated = unreal.BlueprintEditorLibrary.generated_class(blueprint)
        if not isinstance(unreal.get_default_object(generated), unreal.Ck_UserWidget_UE):
            unreal.BlueprintEditorLibrary.reparent_blueprint(blueprint, unreal.Ck_UserWidget_UE)
            unreal.BlueprintEditorLibrary.compile_blueprint(blueprint)
            assert unreal.EditorAssetLibrary.save_loaded_asset(blueprint, only_if_is_dirty=True), path
        generated = unreal.BlueprintEditorLibrary.generated_class(blueprint)
        assert isinstance(unreal.get_default_object(generated), unreal.Ck_UserWidget_UE), path
        report['widgets'].append({'asset': path, 'parent': '/Script/CkUICore.Ck_UserWidget_UE',
                                  'saved_dependencies': [str(p) for p in registry.get_dependencies(path, options)]})

all_assets = registry.get_assets_by_path('/Game/Mars/Gameplay/PlayerCookbook', recursive=True)
remaining = {}
for asset in all_assets:
    deps = [str(p) for p in registry.get_dependencies(asset.package_name, options)
            if str(p).startswith('/BookMenu/') or str(p).startswith('/Script/BookMenu')]
    if deps:
        remaining[str(asset.package_name)] = deps
report['remaining_prototype_dependencies'] = remaining
assert not any('/StylizedR02/' in name for name in remaining), remaining
(root/'widget_migration.json').write_text(json.dumps(report, indent=2))
print('COOKBOOK_WIDGET_MIGRATION '+json.dumps({'reparented': len(report['widgets']), 'remaining_prototypes': len(remaining)}))
