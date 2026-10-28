"""Audit the saved active cookbook separately from the older prototype assets."""
import json
from pathlib import Path
import unreal

registry = unreal.AssetRegistryHelpers.get_asset_registry()
options = unreal.AssetRegistryDependencyOptions(include_soft_package_references=True, include_hard_package_references=True)
active = registry.get_assets_by_path('/Game/Mars/Gameplay/PlayerCookbook/StylizedR02', recursive=True)
dependencies = {str(a.package_name): [str(p) for p in registry.get_dependencies(a.package_name, options)] for a in active}
for path, refs in dependencies.items():
    assert not any(p.startswith('/BookMenu/') or p.startswith('/Script/BookMenu') for p in refs), (path, refs)
report = {'active_assets': len(active), 'bookmenu_references': 0, 'dependencies': dependencies}
(Path(__file__).resolve().parent/'asset_dependencies.json').write_text(json.dumps(report, indent=2))
print('COOKBOOK_DEPENDENCY_AUDIT '+json.dumps({'active_assets': len(active), 'bookmenu_references': 0}))
