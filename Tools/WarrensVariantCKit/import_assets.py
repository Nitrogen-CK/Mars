"""Import Variant C models through the shared guarded centimetre-FBX pipeline."""
import importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
def ensure_variant_materials():
    import json
    s=importlib.util.spec_from_file_location('whole_level_variants',HERE.parent/'ChainCrossingKit/import_assets.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
    recipes=m.recipes();materials={}
    keys={r['material'] for r in json.loads((HERE/'Output/fitted_instances.json').read_text())['placements'] if r.get('material')}
    for key in sorted(keys):
        recipe=recipes[key];textures={}
        for channel,relative in recipe['maps'].items():textures[relative]=m.import_texture(m.texture_spec(relative,channel,recipe))
        materials[key]=m.make_material(key,recipe,textures)
    print('VARIANT_C_MATERIAL_VARIANTS_READY',sorted(materials))
    return materials
def main(ids=None):
    s=importlib.util.spec_from_file_location('whole_level_import',HERE.parent/'ChainCrossingKit/import_assets.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
    m.OUT=HERE/'Output';m.DEST='/Game/Mars/Environment/WarrensVariantCKit';m.MATERIAL_DEST='/Game/Mars/Environment/ChainCrossingKit'
    return m.main(ids)
if __name__=='__main__':main()
