"""Read authored linear vertex ranges from the frozen derived Blender source."""
import bpy,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-forage-props-r04'
assert Path(bpy.data.filepath).resolve()==(OUT/'Catacomb_ForageProps_Source_R01.blend').resolve()
receipt=json.loads((OUT/'PROP_PREVIEW_RECEIPT.json').read_text());rows={}
for row in receipt['exports']:
    obj=bpy.data.objects[row['name']];attr=obj.data.color_attributes['ForagePaint'];values=[c for d in attr.data for c in d.color[:3]]
    rows[row['name']]=dict(min=min(values),max=max(values),domain=attr.domain,data_type=attr.data_type,source='Authored Blender linear color attribute; before FBX export')
path=OUT/'SOURCE_VERTEX_RANGES.json';assert not path.exists();path.write_text(json.dumps(rows,indent=2)+'\n');print('AUTHORED_SOURCE_VERTEX_RANGES',hashlib.sha256(path.read_bytes()).hexdigest())
