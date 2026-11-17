"""Read the final saved model afresh for each independent validation/export step."""
import bpy,runpy,json
from pathlib import Path
root=Path(__file__).resolve().parent
source=root/'Cookbook_StylizedR03.blend'
for name in ['validate_and_roundtrip.py','check_gutter.py','export_morph_curves.py',
             'inspect_fbx_units.py','export_closed_proxy.py','validate_spine_pages.py']:
    bpy.ops.wm.open_mainfile(filepath=str(source))
    runpy.run_path(str(root/name),run_name='__main__')
print('R03_ALL_VALIDATION_COMPLETE')

