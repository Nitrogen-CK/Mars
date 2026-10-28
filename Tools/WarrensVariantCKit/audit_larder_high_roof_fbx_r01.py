"""Fresh actual FBX coverage, controlled normals and full-window Z separation."""
import hashlib,importlib.util,json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_roof_audit_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def main():
    import bpy
    folder=DOC/'roof-completion-export-r01';ep=folder/'export.json';e=json.loads(ep.read_text());source=ROOT/e['file'];mp=ROOT/e['manifest'];assert sha(source)==e['fbx_sha256'] and sha(mp)==e['manifest_sha256'];r=json.loads(mp.read_text());out=folder/'fresh_fbx_audit.json';assert not out.exists()
    bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.scale_length=.01;bpy.ops.import_scene.fbx(filepath=str(source),use_custom_normals=True);o,=[o for o in bpy.context.scene.objects if o.type=='MESH'];m=o.data;m.calc_loop_triangles();assert len(m.loop_triangles)==e['triangles']==7356 and len(m.materials)==2 and len(m.uv_layers)==1
    assert [v.name for v in m.materials]==e['materials'];assert all(math.isfinite(v) for l in m.uv_layers[0].data for v in l.uv)
    assert all(v.vector.z<-.9999 and abs(v.vector.length-1)<1e-5 for v in m.corner_normals)
    points=[(v.co.x/100+120,40-v.co.y/100,v.co.z/100-2.5) for v in m.vertices];raw_rects=[v['rect'] for v in r['ceiling_faces'][132:]];g=load('catacomb_pilot_manifest');segments=load('audit_room_study_triangles_r03');maximum=0.;degenerate=0;edge_conversions={}
    def f32(v):return struct.unpack('f',struct.pack('f',v))[0]
    def edge(axis,value):
        study=f32(value-58) if axis==0 else f32(55-value);local=f32(f32(study-(62 if axis==0 else 15))*100);world=local/100+120 if axis==0 else 40-local/100
        edge_conversions[f'{axis}:{value!r}']=dict(axis=axis,source=value,study_float32=study,export_local_cm_float32=local,world_roundtrip=world,delta_metres=world-value);return world
    rects=[[edge(i%2,v) for i,v in enumerate(rect)] for rect in raw_rects]
    for tri in m.loop_triangles:
        ps=[points[i] for i in tri.vertices];assert all(11.9819<p[2]<11.9871 for p in ps);xy=[p[:2] for p in ps];lo=[min(v[k] for v in xy) for k in (0,1)];hi=[max(v[k] for v in xy) for k in (0,1)];near=[v for v in rects if v[0]<=hi[0]+3e-5 and v[2]>=lo[0]-3e-5 and v[1]<=hi[1]+3e-5 and v[3]>=lo[1]-3e-5];area=g.area(xy)
        if area<1e-9:
            assert all(segments.segment_covered(xy[i],xy[(i+1)%3],near) for i in range(3));degenerate+=1
        else:
            covered=sum(g.area(g.clip(xy,g.rectpoly(v))) for v in near);perimeter=sum(math.dist(xy[i],xy[(i+1)%3]) for i in range(3));error=abs(covered-area)/max(perimeter,1e-12)
            if abs(covered-area)>max(1e-10,perimeter*1e-7):
                failure=folder/'fresh_fbx_coverage_failure.json';failure.write_text(json.dumps(dict(triangle=tri.index,points=ps,area=area,covered=covered,perimeter=perimeter,error=error,near=near),indent=2)+'\n');raise AssertionError(('Exported triangle coverage failure',tri.index,error))
            maximum=max(maximum,error)
    lo=[min(v.co[k] for v in m.vertices) for k in range(3)];hi=[max(v.co[k] for v in m.vertices) for k in range(3)];minimum=min(v[2] for v in points);assert minimum>11
    colour=[d.color for a in m.color_attributes for d in a.data];assert colour
    result=dict(status='FRESH_FBX_ALL_HIGH_ROOF_TRIANGLES_SUPPORTED_NORMALS_UV_COLOUR_WINDOW_CLEARANCE_PASS',export_sha256=sha(ep),fbx_sha256=sha(source),manifest_sha256=sha(mp),tool_sha256=sha(__file__),triangles=7356,projected_degenerate_triangles_segment_checked=degenerate,maximum_area_perimeter_error_metres=maximum,area_perimeter_limit_metres=1e-7,UV_channels=1,materials=[v.name for v in m.materials],all_corner_normals_down=True,colour_RGB_min=[min(c[k] for c in colour) for k in range(3)],colour_RGB_max=[max(c[k] for c in colour) for k in range(3)],unreal_bounds_min_cm=[lo[0],-hi[1],lo[2]],unreal_bounds_max_cm=[hi[0],-lo[1],hi[2]],minimum_world_z_metres=minimum,full_window_aperture_max_z_metres=11,minimum_window_vertical_clearance_metres=minimum-11,boundary='Fresh actual FBX, every triangle/degenerate segment lies within source-supported newly admitted roof footprints. Entire exported mesh is above full7-11m authored aperture, so any eye-to-aperture segment with eyeZ<=11 cannot intersect it. No claim of native lighting, bell visibility outside this aperture, physical input or source adoption.')
    result.update(source_edge_float32_conversions=list(edge_conversions.values()),maximum_source_edge_roundtrip_delta_metres=max(abs(v['delta_metres']) for v in edge_conversions.values()),representation_boundary='Exact declared study float32 -> centimetre float32 export edge conversion; original1e-7 area/perimeter limit unchanged. This records finite representational shifts rather than claiming native coordinates exact to unconverted plan edges.')
    out.write_text(json.dumps(result,indent=2)+'\n');print('HIGH_ROOF_FRESH_FBX_AUDIT_PASS',sha(out),flush=True)
if __name__=='__main__':main()
