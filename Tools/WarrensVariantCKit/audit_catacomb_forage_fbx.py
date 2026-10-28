"""Independent headless FBX round trip; reads owned exports, never edits their source."""
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    folder=sys.argv[sys.argv.index('--')+1];out=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'/folder
    receipt=json.loads((out/'PROP_PREVIEW_RECEIPT.json').read_text());results=[]
    for row in receipt['exports']:
        path=out/row['file'];assert sha(path)==row['sha256']
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.fbx(filepath=str(path),use_custom_normals=True)
        obj,=[o for o in bpy.data.objects if o.type=='MESH'];coords=[obj.matrix_world@v.co for v in obj.data.vertices]
        lo=[min(v[i] for v in coords) for i in range(3)];hi=[max(v[i] for v in coords) for i in range(3)]
        error=max(abs(a-b) for aa,bb in ((lo,row['blender_min_metres']),(hi,row['blender_max_metres'])) for a,b in zip(aa,bb));assert error<.00001,(path,error)
        tris=sum(len(p.vertices)-2 for p in obj.data.polygons);assert tris==row['triangles'];assert len(obj.data.uv_layers)==1
        color,=list(obj.data.color_attributes);values=[c for d in color.data for c in d.color[:3]];assert .001<max(values)<.99 and max(values)>min(values)
        if row['material_role'] in ('fig','bellnut') or 'Bob' in row['name']:assert max(v.length for v in coords)<=.50001
        results.append(dict(file=row['file'],bounds_error_metres=error,triangles=tris,uv_channels=1,color_min=min(values),color_max=max(values),normalized_radius=max(v.length for v in coords)))
    report=dict(status='ALL_FIVE_EXPORTED_MESHES_ROUNDTRIP_PASS',preview_receipt_sha256=sha(out/'PROP_PREVIEW_RECEIPT.json'),results=results,boundary='Independent Blender FBX import only; native RenderData and appearance remain separate checks.')
    path=out/'FBX_ROUNDTRIP_AUDIT.json';assert not path.exists();path.write_text(json.dumps(report,indent=2)+'\n');print(report['status'],sha(path),flush=True)
if __name__=='__main__':main()
