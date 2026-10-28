"""Headless normal-only refinement; no geometry, UV, pigment or collision changes."""
import hashlib,json,sys,math
from array import array
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
OUT=DOC/'normal-refinement-r05';PREFIX='CatacombPilot_R02_'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def shape(mesh):
    h=hashlib.sha256()
    for source,attribute,size,code in [(mesh.vertices,'co',3,'f'),(mesh.edges,'vertices',2,'i'),(mesh.loops,'vertex_index',1,'i'),(mesh.polygons,'loop_start',1,'i'),(mesh.polygons,'loop_total',1,'i'),(mesh.polygons,'material_index',1,'i')]:
        values=array(code,[0])*(len(source)*size);source.foreach_get(attribute,values);h.update(attribute.encode()+values.tobytes())
    for layer in mesh.uv_layers:
        values=array('f',[0])*(len(layer.data)*2);layer.data.foreach_get('uv',values);h.update(layer.name.encode()+values.tobytes())
    for layer in mesh.color_attributes:
        assert layer.data_type in ('FLOAT_COLOR','BYTE_COLOR')
        values=array('f',[0])*(len(layer.data)*4);layer.data.foreach_get('color',values);h.update(layer.name.encode()+values.tobytes())
    return h.hexdigest()
def normals(mesh):
    values=array('f',[0])*(len(mesh.corner_normals)*3);mesh.corner_normals.foreach_get('vector',values)
    return hashlib.sha256(values.tobytes()).hexdigest()
def main():
    import bpy
    from mathutils import Vector
    source=DOC/'pilot-preview-r03/CatacombPilot_R02.blend'
    assert Path(bpy.data.filepath).resolve()==source.resolve() and sha(source)==read(DOC/'pilot-preview-r03/receipt.json')['derived_sha256']
    assert not OUT.exists();OUT.mkdir()
    guard=read(ROOT/'Saved/WarrensCGameplay-20261024/CatacombPilot/baseline_guard_r02.json');guards=guard['immutable_guards']|guard['collision_hashes']
    assert all(sha(ROOT/p)==v for p,v in guards.items())
    inventories={m.name:shape(m) for m in bpy.data.meshes};oldnormals={m.name:normals(m) for m in bpy.data.meshes};changed=[]
    for family,sign in [('floor',1),('ceiling',-1)]:
        mesh=bpy.data.objects[PREFIX+family].data
        for p in mesh.polygons:p.use_smooth=True
        mesh.normals_split_custom_set([(0,0,sign)]*len(mesh.loops));mesh.update()
        assert mesh.has_custom_normals and shape(mesh)==inventories[mesh.name]
        error=max((v.vector-Vector((0,0,sign))).length for v in mesh.corner_normals)
        angle=max(math.degrees(math.acos(max(-1,min(1,v.vector.z*sign)))) for v in mesh.corner_normals)
        print('ACTUAL_CUSTOM_NORMAL_ERROR',family,error,angle,flush=True)
        # Blender's encoded loop-normal spaces can represent a perpendicular
        # corner normal within half a degree. Pin the actual angular bound;
        # geometry/source-support tolerances are unchanged.
        assert angle<.51,(family,error,angle)
        changed.append(dict(family=family,mesh=mesh.name,corners=len(mesh.loops),normal=[0,0,sign],max_vector_error=error,max_angular_error_degrees=angle,shape_uv_color_sha256=shape(mesh)))
    assert all(shape(m)==inventories[m.name] for m in bpy.data.meshes)
    targets={r['mesh'] for r in changed}
    assert all(normals(m)==oldnormals[m.name] for m in bpy.data.meshes if m.name not in targets)
    derived=OUT/'CatacombPilot_R04.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True)
    original=read(DOC/'export-r03/audit_export.json');exports=[]
    export_scene=bpy.data.scenes.new('CatacombNormalOnlyExport');bpy.context.window.scene=export_scene;export_scene.unit_settings.system='METRIC';export_scene.unit_settings.scale_length=.01
    for row in original['exports']:
        if row['kind']=='walls':exports.append(row);continue
        copies=[]
        for name in (PREFIX+row['kind'],PREFIX+row['kind']+'_Backing'):
            old=bpy.data.objects[name];obj=old.copy();obj.data=old.data.copy();export_scene.collection.objects.link(obj)
            for v in obj.data.vertices:v.co=(v.co-Vector((-72,-21,0)))*100
            for attr in obj.data.color_attributes:
                if attr.name=='StoneTint':
                    for d in attr.data:d.color=tuple(v/1.2 for v in d.color[:3])+(d.color[3],)
            obj.select_set(True);copies.append(obj)
        bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();obj=copies[0];obj.name=row['name'];obj.data.name=row['name']
        path=OUT/(row['name']+'.fbx')
        bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=True,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
        exports.append(row|dict(file=path.relative_to(ROOT).as_posix(),sha256=sha(path),normal_policy='Controlled floor+Z/ceiling-Z custom corner normals on thin stone veneers; backing remains original geometry normal.'))
        bpy.data.objects.remove(obj,do_unlink=True)
    result=original|dict(status='NORMAL_ONLY_OFFLINE_REFINEMENT_NOT_NATIVE_APPROVED',source_derived_sha256=sha(source),derived_sha256=sha(derived),exports=exports,normal_changes=changed,all_mesh_shape_uv_color_inventories_unchanged=len(inventories),unrelated_mesh_normals_unchanged=len(oldnormals)-len(targets),untouched_normal_hashes={k:v for k,v in oldnormals.items() if k not in targets},tool_sha256=sha(__file__),boundary='Normals only, actual Blender encoded-corner angular error explicitly recorded; no widened geometry tolerance. No original library/map or collision changes. Native reimport/readback and result review required.')
    (OUT/'audit_export.json').write_text(json.dumps(result,indent=2)+'\n')
    assert all(sha(ROOT/p)==v for p,v in guards.items())
    print('NORMAL_ONLY_EXPORT_READY',sha(OUT/'audit_export.json'),flush=True)
if __name__=='__main__':main()
