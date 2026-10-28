"""Export only the new physical high-roof veneer; preserve accepted local ceilings."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy,bmesh
    from mathutils import Vector
    folder=DOC/'roof-completion-study-r01';out=DOC/'roof-completion-export-r01';assert not out.exists();r=json.loads((folder/'receipt.json').read_text());source=folder/'Larder_SurfaceStudy_R01.blend';assert Path(bpy.data.filepath).resolve()==source and sha(source)==r['derived_sha256']
    audit=folder/'full_triangle_coverage_r03.json';a=json.loads(audit.read_text());assert a['derived_sha256']==sha(source) and all(v['all_triangles_inside_reviewed_shells_with_float32_boundary_budget'] for v in a['checks'])
    manifest=ROOT/r['manifest'];m=json.loads(manifest.read_text());assert sha(manifest)==r['manifest_sha256'] and m['finite_ceiling_supplement']['z']==12 and m['finite_ceiling_supplement']['added_footprints']==1388
    record,=[v for v in r['geometry'] if v['family']=='ceiling'];scene=bpy.data.scenes.new('Larder_HighRoofOnly_Export_R01');bpy.context.window.scene=scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.01;copies=[];pivot=Vector((62,15,-2.5))
    for name in [record['name'],record['name']+'_Backing']:
        original=bpy.data.objects[name];o=original.copy();o.data=original.data.copy();scene.collection.objects.link(o);bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.delete(bm,geom=[v for v in bm.verts if v.co.z<11.9],context='VERTS');bm.to_mesh(o.data);bm.free();o.data.update();assert len(o.data.polygons)>0
        assert all(11.9819<v.co.z<12.0001 for v in o.data.vertices)
        for v in o.data.vertices:v.co=(v.co-pivot)*100
        for attr in o.data.color_attributes:
            if attr.name=='StoneTint':
                for d in attr.data:d.color=tuple(v/1.2 for v in d.color[:3])+(d.color[3],)
        o.select_set(True);copies.append(o)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.join();o=copies[0];o.name='WVC_Larder_HighRoof_R01_SM';o.data.name=o.name;bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.triangulate(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free();o.data.update()
    for p in o.data.polygons:p.use_smooth=True
    o.data.normals_split_custom_set([(0,0,-1)]*len(o.data.loops));o.data.update();o.data.calc_loop_triangles();assert all(n.vector.z<-.9999 for n in o.data.corner_normals)
    lo=[min(v.co[k] for v in o.data.vertices) for k in range(3)];hi=[max(v.co[k] for v in o.data.vertices) for k in range(3)];assert lo[2]-250>1198.19 and hi[2]-250<1200.01
    # Entire approved window rectangle is below every exported roof vertex.
    window=DOC/'WINDOW_LIGHT_PROPOSAL_R01.json';w=json.loads(window.read_text());assert w['source_rectangle_z']==[7,11] and lo[2]-250>1100
    assert len(o.data.materials)==2 and len(o.data.uv_layers)==1
    out.mkdir();path=out/(o.name+'.fbx');bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=1,apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,mesh_smooth_type='FACE',use_triangles=False,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
    result=dict(status='DERIVED_HIGH_ROOF_ONLY_FBX_EXPORT_PENDING_FRESH_FBX_NATIVE_REVIEW',file=path.relative_to(ROOT).as_posix(),fbx_sha256=sha(path),study_sha256=sha(source),study_receipt_sha256=sha(folder/'receipt.json'),manifest=r['manifest'],manifest_sha256=sha(manifest),triangle_audit_sha256=sha(audit),tool_sha256=sha(__file__),vertices=len(o.data.vertices),triangles=len(o.data.loop_triangles),materials=[v.name for v in o.data.materials],uv_channels=1,placement_main_cm=[5000,-1500,-250],placement_brineworks_li_cm=[3200,3600,0],unreal_bounds_min_cm=[lo[0],-hi[1],lo[2]],unreal_bounds_max_cm=[hi[0],-lo[1],hi[2]],normal_sign=-1,vertex_color_gain=1/1.2,window_source_sha256=sha(window),full_window_rectangle_z_metres=[7,11],exported_roof_min_world_z_metres=(lo[2]-250)/100,boundary='Only the new room-top12m ceiling geometry is exported. Existing132 local ceiling rows and accepted Ceiling_R01 asset remain untouched; this is an additive NoCollision surface, not physical roof creation. All exported vertices lie above the entire approved7-11m window aperture, so eye-to-aperture segments below11m cannot intersect this geometry. Actual exported triangle/UV/normal/colour support and native same-view review still required.')
    (out/'export.json').write_text(json.dumps(result,indent=2)+'\n');assert sha(source)==r['derived_sha256'];print('HIGH_ROOF_ONLY_EXPORTED',result['triangles'],sha(out/'export.json'),flush=True)
if __name__=='__main__':main()
