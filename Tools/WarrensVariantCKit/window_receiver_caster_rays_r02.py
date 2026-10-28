"""Attribute an actual centre-pixel noisy receiver, then its 3x3 emitter rays.

Centre rays use the live native camera forward vector and require no guessed
screenshot aspect/FOV conversion. Root must inspect/decode the context PNG.
"""
import hashlib,importlib.util,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
RUN=ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def probe(controller,label):
    import unreal as u
    assert re.fullmatch('[a-z0-9_]+',label);controller.check();s=controller.STATE;world=s['world'];folder=s['capture'].STATE['out'];frame=folder/(label+'.json');png=folder/(label+'.png');r=json.loads(frame.read_text());assert png.read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082'))
    camera=u.GameplayStatics.get_player_camera_manager(world,0);assert list(camera.get_camera_location().to_tuple())==r['camera'];rotation=camera.get_camera_rotation();assert dict(pitch=rotation.pitch,yaw=rotation.yaw,roll=rotation.roll)==r['rotation']
    sp=importlib.util.spec_from_file_location('_visible_segments',Path(__file__).with_name('trace_visible_mesh_segments_r01.py'));query=importlib.util.module_from_spec(sp);sp.loader.exec_module(query)
    origin=camera.get_camera_location();forward=u.MathLibrary.get_forward_vector(rotation);camera_rays=query.trace(world,[dict(label='actual_context_centre_pixel',origin=list(origin.to_tuple()),target=list((origin+forward*10000).to_tuple()),hits=[])])
    receiver=camera_rays['rays'][0]['hits'][0];assert receiver['materials'] and all(m['blend']=='<BlendMode.BLEND_OPAQUE: 0>' for m in receiver['materials']);point=u.Vector(*receiver['world_hit']);light=s['light'];tf=light.get_world_transform();rays=[]
    for y in (-1,0,1):
        for z in (-1,0,1):
            at=tf.transform_location(u.Vector(0,y*light.source_width/2,z*light.source_height/2));delta=point-at;end=point+delta*(2/delta.length())
            rays.append(dict(label=f'emitter_{y}_{z}_to_actual_receiver',origin=list(at.to_tuple()),target=list(end.to_tuple()),receiver=list(point.to_tuple()),hits=[]))
    casters=query.trace(world,rays,True);controller.check();result=dict(status='ACTUAL_CONTEXT_CENTRE_RECEIVER_AND_NINE_RENDER_CASTER_SEGMENTS',context_frame=frame.relative_to(ROOT).as_posix(),context_frame_sha256=sha(frame),context_png_sha256=sha(png),actual_light=controller.own_light(),receiver=receiver,camera_segments=camera_rays,caster_segments=casters,tool_sha256=sha(__file__),boundary='The context PNG centre ray is native camera forward, independent of guessed screenshot projection. Root visually checks it is the noisy band. Actual visible render triangles identify the receiver and nearest potential caster per SMC/ISM/HISM, including NoCollision decoration and new veneers. Each light segment extends2cm past that exact receiver. CPU geometry does not evaluate opacity/WPO or prove VSM sample causality; renderer diagnosis still requires separate evidence. All source, camera, light and art state unchanged by this read-only probe.')
    p=RUN/(label+'_receiver_caster_r02.json');assert not p.exists();p.write_text(json.dumps(result,indent=2)+'\n');print('ACTUAL_NOISY_RECEIVER',receiver['label'],receiver['instance'],receiver['plan_hit']);print('NINE_FIRST_CASTERS',[(q['label'],[(round(h['distance_cm'],2),h['label'],h['instance'],h['plan_hit']) for h in q['hits'][:2]]) for q in casters['rays']])
