"""Read-only original FBX winding/normal audit; no asset or source save."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/sack-winding-r01'
def main():
    import bpy
    from mathutils import Vector
    source=ROOT/'Tools/ChainCrossingKit/Output/FBX/WarrensC_CCS68_ClothSack_Mars_SM.fbx'
    assert not OUT.exists();h=hashlib.sha256(source.read_bytes()).hexdigest()
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.scale_length=.01
    bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True)
    o,=[o for o in bpy.context.scene.objects if o.type=='MESH'];m=o.data
    assert len(m.polygons)==320 and len(m.materials)==2 and len(m.uv_layers)==1
    rows=[]
    for p in m.polygons:
        coords=[m.vertices[i].co for i in p.vertices];n=(coords[1]-coords[0]).cross(coords[2]-coords[0]).normalized();center=sum(coords,Vector())/3
        radial=Vector((center.x,center.y,0)).normalized()
        rows.append(dict(id=p.index,material=p.material_index,z=[min(c.z for c in coords),max(c.z for c in coords)],center=list(center),winding_normal=list(n),radial_dot=n.dot(radial),vertex_normals_dot=[n.dot(m.corner_normals[i].vector) for i in p.loop_indices],corners=[list(c) for c in coords]))
    OUT.mkdir(parents=True);(OUT/'audit.json').write_text(json.dumps(dict(status='READ_ONLY_ORIGINAL_FBX_WINDING_AUDIT_NOT_FIX',source=str(source.relative_to(ROOT)),source_sha256=h,triangles=rows,boundary='Radial dot is diagnostic only; it is not a universal inside/outside test at caps, neck or irregular folds. No mesh mutation/export.'),indent=2)+'\n')
    assert hashlib.sha256(source.read_bytes()).hexdigest()==h
    print('WINDING_AUDIT',[(r['id'],r['z'],round(r['radial_dot'],3),[round(v,3) for v in r['vertex_normals_dot']]) for r in rows if r['z'][1]<36],flush=True)
if __name__=='__main__':main()
