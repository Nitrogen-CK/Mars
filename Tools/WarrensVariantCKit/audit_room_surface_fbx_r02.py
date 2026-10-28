"""Full horizontal-normal FBX successor audit, including exact non-normal equality."""
import argparse,collections,hashlib,importlib.util,json,math,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()


def f32(v):return struct.unpack('f',struct.pack('f',v))[0]


def exported_boundary(axis,value):
    """Exact arithmetic of the builder's stored point and FBX export pivot.

    This is not general epsilon growth. Record every original/mapped edge.
    The frozen native/region inputs retain their original double values.
    """
    original=(value-58,55-value,value)[axis];pivot=(62,15,-2.5)[axis]
    cm=f32(f32(f32(original)-f32(pivot))*100)
    return (cm/100+120,40-cm/100,cm/100-2.5)[axis]


def module(name):
    p=Path(__file__).with_name(name+'.py');s=importlib.util.spec_from_file_location('_fbx_'+name,p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m


def main():
    import bpy
    from mathutils import Vector
    p=argparse.ArgumentParser();p.add_argument('--export',required=True);p.add_argument('--regions',required=True);a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);folder=(ROOT/a.export).resolve();ep=folder/'export.json';e=json.loads(ep.read_text());mp=ROOT/a.regions;r=json.loads(mp.read_text());assert sha(mp)==e['manifest_sha256']
    g=module('catacomb_pilot_manifest');audit=module('audit_room_study_triangles_r01');bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=.01;rows=[];edges={}
    for row in e['exports']:
        path=ROOT/row['file'];assert sha(path)==row['sha256'];before=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(path),use_custom_normals=True);objects=[o for o in bpy.data.objects if o not in before and o.type=='MESH'];o,=objects;mesh=o.data;mesh.calc_loop_triangles();assert len(mesh.loop_triangles)==row['triangles'];assert len(mesh.materials)==2
        normal_proof=None
        if row['family'] in ('floor','ceiling'):
            sign=1 if row['family']=='floor' else -1;minimum=min(v.vector.z*sign for v in mesh.corner_normals);assert minimum>.9999,(row['family'],minimum)
            shape=module('refine_catacomb_veneer_normals').shape;new_shape=shape(mesh);prior=json.loads((folder.parent/'export-r01/export.json').read_text());oldrow,=[v for v in prior['exports'] if v['family']==row['family']];old_objects=set(bpy.data.objects);bpy.ops.import_scene.fbx(filepath=str(ROOT/oldrow['file']),use_custom_normals=True);oldobj,=[v for v in bpy.data.objects if v not in old_objects and v.type=='MESH'];old_shape=shape(oldobj.data);assert new_shape==old_shape,(row['family'],'Non-normal data changed',new_shape,old_shape);bpy.data.objects.remove(oldobj,do_unlink=True)
            normal_proof=dict(all_actual_fbx_corners_vertical=True,minimum_dot_expected_z=minimum,non_normal_shape_uv_colour_material_index_sha256=new_shape,exact_previous_fbx_non_normal_data_equal=True)
        world=[o.matrix_world@v.co for v in mesh.vertices];lo=[min(v[k] for v in world) for k in range(3)];hi=[max(v[k] for v in world) for k in range(3)]
        expected_lo=[row['unreal_bounds_min_cm'][0],-row['unreal_bounds_max_cm'][1],row['unreal_bounds_min_cm'][2]];expected_hi=[row['unreal_bounds_max_cm'][0],-row['unreal_bounds_min_cm'][1],row['unreal_bounds_max_cm'][2]]
        error=max(abs(x-y) for aa,bb in ((lo,expected_lo),(hi,expected_hi)) for x,y in zip(aa,bb));print('FBX_UNIT_BOUND_WITNESS',row['family'],lo,hi,'errorcm',error,flush=True);assert error<.002
        # FBX importer axis conversion adds a measured tiny Z rotation to the
        # object: off-diagonals +/-8.742277657347586e-8, otherwise identity.
        # Audit the actual stored mesh in its declared local coordinate frame,
        # and separately pin/bound that importer transform. The later bell ray
        # still uses the actual imported world transform without normalization.
        matrix=[list(v) for v in o.matrix_world]
        assert all(abs(matrix[i][j]-(1 if i==j else 0))<1e-7 for i in range(4) for j in range(4))
        local=[v.co for v in mesh.vertices];displacement=max((w-v).length for w,v in zip(world,local));assert displacement<.00025
        local_lo=[min(v[k] for v in local) for k in range(3)];local_hi=[max(v[k] for v in local) for k in range(3)]
        assert max(abs(x-y) for aa,bb in ((local_lo,expected_lo),(local_hi,expected_hi)) for x,y in zip(aa,bb))<1e-6
        points=[(v.x/100+120,40-v.y/100,v.z/100-2.5) for v in local];groups=collections.defaultdict(list);family=row['family']
        if family=='walls':
            for f in r['wall_faces']:groups[f['axis'],f['normal_sign'],f['plane']].append([f['tangent_bounds'][0],f['z_bounds'][0],f['tangent_bounds'][1],f['z_bounds'][1]])
        else:
            for c in r['admitted_floor_cells' if family=='floor' else 'ceiling_faces']:groups[2,1 if family=='floor' else -1,c['z']].append(c['rect'])
        for key,rects in groups.items():
            axes=(0,1) if key[0]==2 else (1-key[0],2)
            mapped=[]
            for rect in rects:
                values=[]
                for k,value in enumerate(rect):
                    axis=axes[k%2];wanted=exported_boundary(axis,value);assert abs(wanted-value)<2e-6
                    edges[axis,value]=dict(axis=axis,source=value,exported=wanted,delta_metres=wanted-value);values.append(wanted)
                mapped.append(values)
            groups[key]=mapped
        back,front=(.009,.012) if family=='floor' else (.013,.018);possible={}
        for key in groups:
            axis,sign,plane=key
            for i,point in enumerate(points):
                if back-3e-5<=(point[axis]-plane)*sign<=front+3e-5:possible.setdefault(i,set()).add(key)
        failures=[];maximum=0.;segment_count=0
        for tri in mesh.loop_triangles:
            ids=tuple(tri.vertices);keys=set.intersection(*(possible.get(i,set()) for i in ids));valid=False
            for key in keys:
                axis=key[0];xy=[(points[i][0],points[i][1]) if axis==2 else (points[i][1-axis],points[i][2]) for i in ids];low=[min(v[k] for v in xy) for k in (0,1)];high=[max(v[k] for v in xy) for k in (0,1)];rects=[v for v in groups[key] if all(v[k]<=high[k]+3e-5 and v[k+2]>=low[k]-3e-5 for k in (0,1))];area=g.area(xy)
                if area<1e-9:
                    okay=all(audit.segment_covered(xy[i],xy[(i+1)%3],rects) for i in range(3))
                else:
                    covered=sum(g.area(g.clip(xy,g.rectpoly(v))) for v in rects);perimeter=sum(math.dist(xy[i],xy[(i+1)%3]) for i in range(3));delta=abs(covered-area)/max(perimeter,1e-12);okay=delta<=1e-7 or abs(covered-area)<1e-10
                    if okay:maximum=max(maximum,delta)
                if okay:segment_count+=area<1e-9;valid=True;break
            if not valid:failures.append(dict(triangle=tri.index,points=[points[i] for i in ids]))
        if failures:
            fp=folder/(family+'_fbx_failure_r03.json');assert not fp.exists();fp.write_text(json.dumps(failures,indent=2)+'\n')
        assert not failures,(family,len(failures),failures[:1])
        rows.append(dict(horizontal_normal_and_non_normal_equality=normal_proof,family=family,triangles=len(mesh.loop_triangles),stone_and_backing_local_geometry_fully_checked=True,bounds_error_cm=error,fbx_import_object_matrix=matrix,max_import_transform_vertex_displacement_cm=displacement,max_area_perimeter_boundary_error_metres=maximum,degenerate_edges_checked=segment_count,material_slots=[v.name for v in mesh.materials],uv_layers=[v.name for v in mesh.uv_layers],colours=[dict(name=v.name,type=v.data_type,domain=v.domain) for v in mesh.color_attributes]))
        print('FULL_FBX_TRIANGLE_PASS',family,len(mesh.loop_triangles),flush=True)
    # Exact authored bell direction is intentionally distinct from the earlier
    # art inspection camera; test actual imported triangles, no AABB proxy.
    origin=Vector((0,0,(-1.777+2.5)*100));target=Vector(((104-120)*100,(40-50)*100,(16+2.5)*100));direction=(target-origin).normalized();length=(target-origin).length;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();hit,at,normal,index,obj,world=scene.ray_cast(deps,origin,direction,distance=length);assert not hit,('New veneer blocks authored bell ray',obj.name,list(at))
    result=dict(status='FBX_ROUNDTRIP_ALL_STONE_BACKING_TRIANGLES_AND_AUTHORED_BELL_RAY_PASS',export_sha256=sha(ep),manifest_sha256=sha(mp),tool_sha256=sha(__file__),polygon_helper_sha256=sha(g.__file__),segment_helper_sha256=sha(audit.__file__),meshes=rows,explicit_export_boundary_conversion=list(edges.values()),max_boundary_conversion_metres=max(abs(v['delta_metres']) for v in edges.values()),authored_bell_ray=dict(from_plan=[120,40,-1.777],to_plan=[104,50,16],new_mesh_intersection=False),boundary='Actual FBX import units, all primary/backing local triangles and18mm/12mm shells checked against explicitly recorded float32 source-point/pivot/centimetre boundary conversion. Original region/native inputs remain unmodified. Imported object transform is separately pinned/bounded; actual world bell ray uses it unchanged. No new triangle intersects exact authored bell centre ray. Aperture edge/frame thickness and all corridor/collision/gameplay are not exhaustively proved. Native reimport/readback and disposable real-context PIE still required.')
    p=folder/'fbx_roundtrip_r02.json';assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print('FBX_ROUNDTRIP_AUDIT_PASS',sha(p),flush=True)


if __name__=='__main__':main()
