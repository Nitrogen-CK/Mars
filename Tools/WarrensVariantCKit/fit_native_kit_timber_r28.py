"""Move only the new Timber review camera to fit actual specimen/text bounds."""
import hashlib
import json
import math
from pathlib import Path
def fit(lib):
    import unreal as u
    s=lib.STATE;assert s['target']=='KitLibrary' and s['stage']=='staged' and lib.LOADED==lib.sha(lib.__file__)=='733c673f671fb4e0a97c6e83075d8d5ac2d18da01b38cc59a7261b1f19421ccc';lib.guard();assert s['source'].dirty()==dict(maps=[lib.MAPS['KitLibrary']],content=[])
    camera,=[a for a in s['created'] if isinstance(a,u.CameraActor) and a.get_actor_label()=='CP23_Kit_Timber'];before=lib.extra(camera);root=lib.RUN/'native_kit_framing_r28';assert not root.exists();root.mkdir();bounds=[];points=[]
    for a in s['created']:
        if a.get_actor_label() not in ('CP23_Kit_TimberPost','CP23_Kit_TimberArm','CP23_Label_TimberPost','CP23_Label_TimberArm'):continue
        components=a.get_components_by_class(u.StaticMeshComponent)+a.get_components_by_class(u.TextRenderComponent);assert len(components)==1
        for c in components:
            centre,extent,radius=u.SystemLibrary.get_component_bounds(c);centre=list(centre.to_tuple());extent=list(extent.to_tuple());bounds.append(dict(actor=a.get_name(),component=c.get_name(),origin=centre,extent=extent))
            points += [[centre[i]+signs[i]*extent[i] for i in range(3)] for signs in ((x,y,z) for x in (-1,1) for y in (-1,1) for z in (-1,1))]
    assert len(bounds)==4 and len(points)==32
    forward=list(u.MathLibrary.get_forward_vector(camera.get_actor_rotation()).to_tuple());right=list(u.MathLibrary.get_right_vector(camera.get_actor_rotation()).to_tuple());up=list(u.MathLibrary.get_up_vector(camera.get_actor_rotation()).to_tuple());centre=[sum((min(p[i] for p in points),max(p[i] for p in points)))/2 for i in range(3)]
    fov=camera.camera_component.field_of_view;aspect=camera.camera_component.aspect_ratio;assert fov==65 and abs(aspect-16/9)<1e-6;tx=math.tan(math.radians(fov/2));ty=tx/aspect
    dot=lambda a,b:sum(x*y for x,y in zip(a,b));deltas=[[p[i]-centre[i] for i in range(3)] for p in points];distance=1.15*max(max(abs(dot(v,right))/tx,abs(dot(v,up))/ty)-dot(v,forward) for v in deltas);location=[centre[i]-forward[i]*distance for i in range(3)];assert camera.set_actor_location(u.Vector(*location),False,True)
    after=lib.extra(camera);assert before['details']==after['details'] and before['pose']['q']==after['pose']['q'];expected,=[r for r in s['extras'] if r['actor']==camera.get_name()];assert expected==before;expected.update(after)
    projected=[]
    for p in points:
        v=[p[i]-location[i] for i in range(3)];depth=dot(v,forward);assert depth>0;projected.append([.5+dot(v,right)/(2*depth*tx),.5-dot(v,up)/(2*depth*ty)])
    assert all(.02<p[0]<.98 and .02<p[1]<.98 for p in projected)
    row=dict(status='NEW_TIMBER_CAMERA_ONLY_FITTED_TO_ACTUAL_BOUNDS',before=before,after=after,bounds=bounds,projected_min=[min(p[i] for p in projected) for i in (0,1)],projected_max=[max(p[i] for p in projected) for i in (0,1)],tool_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest());out=root/'camera_fit.json';out.write_text(json.dumps(row,indent=2)+'\n');lib.guard();snapshot=lib.snapshot('timber_fitted_r28');lib.verify(snapshot);print('NEW_TIMBER_CAMERA_FITTED',lib.sha(out));return camera
