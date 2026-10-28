"""Read raw FBX colour payload; do not infer it from sRGB reimport display values."""
import hashlib,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/roof-completion-export-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    from io_scene_fbx import parse_fbx
    e=json.loads((DOC/'export.json').read_text());p=ROOT/e['file'];assert sha(p)==e['fbx_sha256'];out=DOC/'raw_fbx_linear_colours.json';assert not out.exists()
    tree,version=parse_fbx.parse(str(p));objects,=[v for v in tree.elems if v.id==b'Objects'];geometry,=[v for v in objects.elems if v.id==b'Geometry'];layer,=[v for v in geometry.elems if v.id==b'LayerElementColor'];colours,=[v for v in layer.elems if v.id==b'Colors'];indices,=[v for v in layer.elems if v.id==b'ColorIndex'];values=list(colours.props[0]);assert len(values)%4==0 and all(math.isfinite(v) and 0<=v<=1 for v in values);rgba=[values[i:i+4] for i in range(0,len(values),4)];ids=list(indices.props[0]);assert ids and all(0<=i<len(rgba) for i in ids)
    record=dict(status='RAW_FBX_LINEAR_VERTEX_COLOUR_PAYLOAD_NOT_SRGB_DISPLAY',fbx_sha256=sha(p),export_sha256=sha(DOC/'export.json'),export_tool_sha256=e['tool_sha256'],tool_sha256=sha(__file__),fbx_version=version,colour_entries=len(rgba),corner_indices=len(ids),RGBA_min=[min(v[k] for v in rgba) for k in range(4)],RGBA_max=[max(v[k] for v in rgba) for k in range(4)],RGBA_values=rgba,boundary='Raw LayerElementColor/Colors payload from the existing unchanged FBX. Export recipe explicitly uses colors_type=LINEAR. Blender default FBX reimport uses SRGB and returns decoded linear display values; those earlier audit colour ranges are not native payload expectations. No texture, vertex colour, material or gamma correction performed.')
    out.write_text(json.dumps(record,indent=2)+'\n');print('RAW_FBX_LINEAR_COLOUR',record['RGBA_min'],record['RGBA_max'],sha(out),flush=True)
if __name__=='__main__':main()
