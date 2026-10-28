"""Derived original-shape Sack successor: cloth winding only, ties exact."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01/sack-winding-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    audit=json.loads((OUT/'audit.json').read_text());source=ROOT/audit['source'];assert sha(source)==audit['source_sha256']
    target=OUT/'WVC_Larder_OutwardClothSack_R01_SM.fbx';receipt=OUT/'successor.json';assert not target.exists() and not receipt.exists()
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.01
    bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True);o,=[o for o in scene.objects if o.type=='MESH'];old=o.data
    assert len(old.polygons)==320 and len(old.materials)==2 and len(old.uv_layers)==1
    assert len(old.color_attributes)==0
    points=[tuple(v.co) for v in old.vertices];faces=[];uv=[];normals=[];slots=[];changed=[]
    for p in old.polygons:
        ids=list(p.loop_indices);flip=p.material_index==0
        if flip:ids.reverse();changed.append(p.index)
        faces.append([old.loops[i].vertex_index for i in ids]);uv.extend(tuple(old.uv_layers[0].data[i].uv) for i in ids);normals.extend(tuple(-old.corner_normals[i].vector if flip else old.corner_normals[i].vector) for i in ids);slots.append(p.material_index)
    assert len(changed)==128
    m=bpy.data.meshes.new('OutwardClothSack_WindingOnly_R01');m.from_pydata(points,[],faces);m.update();m.uv_layers.new(name=old.uv_layers[0].name)
    for i,v in enumerate(uv):m.uv_layers[0].data[i].uv=v
    for mat in old.materials:m.materials.append(mat)
    for p,k in zip(m.polygons,slots):p.material_index=k;p.use_smooth=False
    m.normals_split_custom_set(normals);m.update();o.data=m;o.name='WVC_Larder_OutwardClothSack_R01_SM'
    assert [tuple(v.co) for v in m.vertices]==points
    for p in m.polygons:
        assert p.area>1e-6
        if p.material_index==0:
            cs=[m.vertices[i].co for i in p.vertices];center=sum(cs,Vector())/3
            if max(v.z for v in cs)==0:assert p.normal.z<-.9999
            else:assert p.normal.dot(Vector((center.x,center.y,0)).normalized())>.63
            assert all(p.normal.dot(m.corner_normals[i].vector)>.9999 for i in p.loop_indices)
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.fbx(filepath=str(target),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=False,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
    assert sha(source)==audit['source_sha256']
    receipt.write_text(json.dumps(dict(status='DERIVED_WINDING_ONLY_ORIGINAL_SACK_PENDING_INDEPENDENT_FBX_NATIVE_REVIEW',source=audit['source'],source_sha256=sha(source),fbx=target.relative_to(ROOT).as_posix(),fbx_sha256=sha(target),audit_sha256=sha(OUT/'audit.json'),tool_sha256=sha(__file__),triangles=320,reversed_cloth_triangles=128,unchanged_tie_triangles=192,changed_faces=changed,all_vertex_positions_exact=True,uv_material_corner_association_exact=True,boundary='Original shape retained, cloth triangle winding and authored normal directions reversed only. No wider foot, coordinates, UV association, tie normals, source package or library change. Actual native one-sided A/B/A required.'),indent=2)+'\n');print('SACK_WINDING_SUCCESSOR',sha(receipt),flush=True)
if __name__=='__main__':main()
