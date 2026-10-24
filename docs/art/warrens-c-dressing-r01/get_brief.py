"""Print one Blender request, or a batch filtered by tile/priority. Never runs Blender or edits the map."""
import argparse,json
from pathlib import Path
r=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('id',nargs='?');p.add_argument('--tile');p.add_argument('--priority',choices=['P0','P1','P2']);a=p.parse_args()
items=json.loads((r/'prop_catalog.json').read_text())
items=[i for i in items if (not a.id or i['id']==a.id) and (not a.tile or a.tile in i['tiles']) and (not a.priority or i['priority']==a.priority)]
if not items:raise SystemExit('No matching prop entries')
print('Material library: blender/WarrensC_MaterialLibrary.blend\nRead BLENDER_AUTHORING.md before generating.\n')
for item in items:print(item['id']+' / '+item['name']+'\n'+item['blender_generation_brief']+'\n')
