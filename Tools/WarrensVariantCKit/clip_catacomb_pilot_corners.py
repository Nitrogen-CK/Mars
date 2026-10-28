"""Clip generated bevel triangles to real floor/ceiling support, preserving UV/color."""
import hashlib,importlib.util,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02';PREFIX='CatacombPilot_R02_'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def read(p):return json.loads(Path(p).read_text())
def clipped(poly,axis,bound,sign):
    result=[];old=poly[-1];od=(old['xy'][axis]-bound)*sign
    for cur in poly:
        d=(cur['xy'][axis]-bound)*sign
        if (d>=0)!=(od>=0):
            t=od/(od-d);v={k:[a+(b-a)*t for a,b in zip(old[k],cur[k])] for k in ('co','uv','color','xy')};result.append(v)
        if d>=0:result.append(cur)
        old,od=cur,d
    return result
def main():
    import bpy
    from mathutils import Vector
    source=DOC/'pilot-preview-r02';out=DOC/'pilot-preview-r03';r=read(source/'receipt.json')
    assert sha(bpy.data.filepath)==r['derived_sha256'] and not out.exists()
    assert all(sha(ROOT/k)==v for k,v in r['guards'].items())
    s=importlib.util.spec_from_file_location('_cornerclip_sync',HERE/'sync_art_libraries.py');sync=importlib.util.module_from_spec(s);s.loader.exec_module(sync)
    manifest=read(DOC/'geometry-r05/room_geometry.json');cells={tuple(c['cell']):c for c in manifest['admitted_floor_cells']};ceil={tuple(c['cell']):c for c in manifest['ceiling_faces']}
    changes=[]
    for kind in ('floor','ceiling'):
        obj=bpy.data.objects[PREFIX+kind];old=obj.data;old.calc_loop_triangles();uv=old.uv_layers['PigmentUV'];color=old.color_attributes['StoneTint'];data=[];indices=[];seen=set()
        for tri in old.loop_triangles:
            poly=[]
            for vi,li in zip(tri.vertices,tri.loops):
                co=list(old.vertices[vi].co);poly.append(dict(co=co,xy=[co[0]+58,55-co[1]],uv=list(uv.data[li].uv),color=list(color.data[li].color)))
            lo=[min(v['xy'][i] for v in poly) for i in (0,1)];hi=[max(v['xy'][i] for v in poly) for i in (0,1)]
            nearby=[]
            for ix in range(math.floor((lo[0]-1e-6)/.5),math.floor((hi[0]+1e-6)/.5)+1):
                for iy in range(math.floor((lo[1]-1e-6)/.5),math.floor((hi[1]+1e-6)/.5)+1):
                    cell=(cells if kind=='floor' else ceil).get((ix,iy))
                    if cell and (kind=='floor' or all(.0128<=cell['z']-v['co'][2]<=.0181 for v in poly)):nearby.append(cell['rect'])
            assert nearby,(kind,tri.index,lo,hi)
            if any(all(rect[0]-1e-7<=v['xy'][0]<=rect[2]+1e-7 and rect[1]-1e-7<=v['xy'][1]<=rect[3]+1e-7 for v in poly) for rect in nearby):polygons=[poly]
            else:
                polygons=[]
                for rect in nearby:
                    p=poly
                    for axis,bound,sign in ((0,rect[0],1),(0,rect[2],-1),(1,rect[1],1),(1,rect[3],-1)):
                        if p:p=clipped(p,axis,bound,sign)
                    if len(p)>=3:polygons.append(p)
            for p in polygons:
                for i in range(1,len(p)-1):
                    triangle=[p[0],p[i],p[i+1]]
                    if (Vector(triangle[1]['co'])-Vector(triangle[0]['co'])).cross(Vector(triangle[2]['co'])-Vector(triangle[0]['co'])).length<1e-12:continue
                    key=tuple(sorted(tuple(round(x,7) for x in v['co']) for v in triangle))
                    if key in seen:continue
                    seen.add(key);n=len(data);data+=triangle;indices.append((n,n+1,n+2))
        new=bpy.data.meshes.new(PREFIX+kind+'_SourceClippedMesh');new.from_pydata([v['co'] for v in data],[],indices);new.materials.clear()
        for mat in old.materials:new.materials.append(mat)
        uvl=new.uv_layers.new(name='PigmentUV');cl=new.color_attributes.new(name='StoneTint',type='FLOAT_COLOR',domain='CORNER')
        for face in new.polygons:
            for li in face.loop_indices:
                item=data[new.loops[li].vertex_index];uvl.data[li].uv=item['uv'];cl.data[li].color=item['color']
        new.update();obj.data=new
        changes.append(dict(kind=kind,old_mesh=old.name,new_mesh=new.name,old_triangles=len(old.loop_triangles),new_triangles=len(indices),policy='Actual triangle clipping against exact admitted source cells; no support tolerance expansion. UV and StoneTint interpolated at new boundary vertices.'))
        rec=next(v for v in r['new_geometry'] if v['kind']==kind);rec.update(mesh_inventory=sync.mesh_hash(new),vertices=len(new.vertices),polygons=len(new.polygons))
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    out.mkdir();frames=[];lantern=bpy.data.objects[PREFIX+'PlayerLanternReviewProxy']
    for stage in ('C_angular_pigment_neutral','D_local_warm_lights'):
        warm=stage.startswith('D')
        for l in r['lights']:bpy.data.objects[l['name']].hide_render=(l['group']=='warm')!=warm
        for label in ('standing','ceiling','reverse','tomb'):
            camera=bpy.data.objects[PREFIX+label];lantern.location=camera.location+(camera.matrix_world.to_quaternion()@Vector((.25,-.45,-.45)));scene.camera=camera;bpy.context.view_layer.update()
            path=out/(stage+'_'+label+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
            frames.append(dict(stage=stage,view=label,file=path.name,sha256=sha(path),camera_matrix=[list(v) for v in camera.matrix_world],review_player_lantern_at=list(lantern.location) if warm else None));print('CLIPPED_PILOT_FRAME',path.name,flush=True)
    derived=out/'CatacombPilot_R02.blend';bpy.ops.wm.save_as_mainfile(filepath=str(derived),compress=True,relative_remap=False)
    assert all(sha(ROOT/k)==v for k,v in r['guards'].items())
    r.update(status='DERIVED_ROOM_PILOT_CLIPPED_BEVEL_REVIEW_REQUIRED',frames=frames,derived_sha256=sha(derived),parent_study_receipt_sha256=sha(source/'receipt.json'),corner_clip_changes=changes,corner_clip_tool_sha256=sha(__file__))
    (out/'receipt.json').write_text(json.dumps(r,indent=2)+'\n');print('CLIPPED_PILOT_DONE',sha(out/'receipt.json'),flush=True)
if __name__=='__main__':main()
