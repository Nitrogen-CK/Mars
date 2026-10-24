"""Import new meshes only, reusing the shared CCK material/texture namespace."""
import importlib.util
from pathlib import Path
HERE=Path(__file__).resolve().parent
def main(ids=None):
    path=HERE.parent/'ChainCrossingKit/import_assets.py';spec=importlib.util.spec_from_file_location('warrens_import_core',path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    m.OUT=HERE/'Output';m.DEST='/Game/Mars/Environment/PumpCisternKit'
    m.MATERIAL_DEST='/Game/Mars/Environment/ChainCrossingKit'
    return m.main(ids)
if __name__=='__main__':main()
