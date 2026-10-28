"""Read-only P1/P5 placement survey against the canonical C Diorama."""
import hashlib
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'Output/WarrensVariantC_Diorama.blend'
SOURCE_SHA = '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'
FIT = HERE / 'Output/fitted_instances.json'
PLAN = ROOT / 'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json'
P1_VIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/ART_held_p1_lock_held_inspection.json'
P5_VIEW = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/ART_observe_p5_loft_lever.json'
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/P1P5MechanismFit/receipt.corrected.json'
SCENE = '02_VariantC_Cutaway'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def point(plan):
    return Vector((plan[0] - 58.0, 55.0 - plan[1], plan[2]))


def plan_point(world):
    return [world.x + 58.0, 55.0 - world.y, world.z]


def cast(scene, graph, plan_start, plan_end=None, direction=None, distance=30.0):
    start = point(plan_start)
    if plan_end is not None:
        vector = point(plan_end) - start
        distance = vector.length
    else:
        vector = Vector(direction).normalized()
    hit, location, normal, face, obj, matrix = scene.ray_cast(graph, start, vector.normalized(), distance=distance)
    return dict(start=list(plan_start), end=list(plan_end) if plan_end else None,
        direction=list(vector.normalized()), hit=hit,
        location=plan_point(location) if hit else None, normal=list(normal) if hit else None,
        object=obj.name if hit else None, data=obj.data.name if hit and obj.data else None,
        distance=(location-start).length if hit else None)


def main():
    assert sha(SOURCE) == SOURCE_SHA, 'Canonical Diorama changed; refuse survey'
    assert not OUT.exists(), 'Preserve earlier survey receipts'
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes[SCENE]
    bpy.context.window.scene = scene
    graph = bpy.context.evaluated_depsgraph_get()
    plan = json.loads(PLAN.read_text(encoding='utf-8'))
    p1 = next(p for p in plan['puzzles'] if p['id'] == 'P1')
    p5 = next(p for p in plan['puzzles'] if p['id'] == 'P5')
    assert p1['at'] == [57,60,-5.0] and p1['needsAt'] == [104,60,2.5]
    assert p5['at'] == [104,56,0] and p5['needsAt'] == [102,60,2.5]
    fit = json.loads(FIT.read_text(encoding='utf-8'))

    # P5 candidate at the Reliquary stair head. Sample the 0.7 m player footprint,
    # the approach line and static overhead/body-height clearance.
    lever = [93.0, 73.5, 2.503]
    stair_head = [92.0, 72.0, 2.5]
    offsets = [(0,0),(-.35,-.35),(0,-.35),(.35,-.35),(-.35,0),(.35,0),
               (-.35,.35),(0,.35),(.35,.35)]
    floors = []
    for dx,dy in offsets:
        floors.append(dict(offset=[dx,dy], ray=cast(scene,graph,[lever[0]+dx,lever[1]+dy,10],
            direction=(0,0,-1),distance=20)))
    path_floors = []
    for i in range(13):
        t=i/12
        x=stair_head[0]+(lever[0]-stair_head[0])*t
        y=stair_head[1]+(lever[1]-stair_head[1])*t
        path_floors.append(dict(t=t,at=[x,y],ray=cast(scene,graph,[x,y,10],direction=(0,0,-1),distance=20)))
    body_rays=[]
    for dx,dy in ((1,0),(.707,.707),(0,1),(-.707,.707),(-1,0),(-.707,-.707),(0,-1),(.707,-.707)):
        body_rays.append(dict(direction=[dx,dy],ray=cast(scene,graph,[lever[0],lever[1],3.5],
            direction=(dx,-dy,0),distance=.35)))
    approach_eye=[92.0,72.0,3.9]
    lever_eye=[lever[0],lever[1],lever[2]+1.0]
    lever_sight=cast(scene,graph,approach_eye,plan_end=lever_eye)
    # Candidate frame checks: Lever is a runtime entity, so this is only a static LOS/floor test.

    # Source floor and occlusion evidence for current and proposed P1 wall mounts.
    p1_view=json.loads(P1_VIEW.read_text(encoding='utf-8'))
    p1_camera_world=p1_view['camera']
    # The persistent-world transform uses plan pivot (70,55,0), centimeters.
    camera=[p1_camera_world[0]/100.0+70.0,p1_camera_world[1]/100.0+55.0,p1_camera_world[2]/100.0]
    current_lock=[56.0,58.3,-5.0]
    candidate_lock=[56.5,58.512,-4.0]
    current_face=[current_lock[0],current_lock[1],current_lock[2]+.07]
    candidate_face=[candidate_lock[0],candidate_lock[1]+.07,candidate_lock[2]]
    occlusion=dict(camera_plan=camera, camera_rotation=p1_view['rotation_roll_pitch_yaw'],
        current_lock_center=current_lock, current_face_target=current_face,
        current_los=cast(scene,graph,camera,plan_end=current_face),
        candidate_lock_root=candidate_lock, candidate_face_target=candidate_face,
        candidate_los=cast(scene,graph,camera,plan_end=candidate_face))
    support=[]
    for xoff,zoff in ((-.2,.2),(.2,.2),(-.2,-.2),(.2,-.2),(0,0)):
        start=[candidate_lock[0]+xoff,60.0,candidate_lock[2]+zoff]
        support.append(dict(plate_back_point=[candidate_lock[0]+xoff,candidate_lock[1],candidate_lock[2]+zoff],
            ray=cast(scene,graph,start,direction=(0,1,0),distance=4)))
    wall_grid=[]
    for x in (56.3,56.5,56.7):
        for z in (-4.2,-4.0,-3.8):
            wall_grid.append(dict(at=[x,58.512,z],ray=cast(scene,graph,[x,60,z],direction=(0,1,0),distance=4)))
    gate=dict(center=p1['at'],opening_cm=[200,220],frame_depth_cm=40,
        leaf_thickness_cm=10,threshold_depth_cm=80,
        candidate_lock_root=candidate_lock,
        plate_aabb_plan=dict(x=[candidate_lock[0]-.2,candidate_lock[0]+.2],
                             y=[candidate_lock[1],candidate_lock[1]+.06],
                             z=[candidate_lock[2]-.2,candidate_lock[2]+.2]),
        frame_clearance_estimate_cm=dict(x_to_gate_front=(57.0-.2-(candidate_lock[0]+.2))*100,
                                         y_to_near_post=(58.8-(candidate_lock[1]+.06))*100))

    report=dict(status='SOURCE_GEOMETRY_SURVEY_COMPLETE',source=str(SOURCE.relative_to(ROOT)),
        source_sha256=SOURCE_SHA,scene=SCENE,inputs={str(p.relative_to(ROOT)):sha(p) for p in (FIT,PLAN,P1_VIEW,P5_VIEW)},
        p5=dict(source_plan_anchor=p5,proposed_lever_root=lever,lever_script='Mars_Lever_EntityScript',
        lever_runtime_geometry_cm={'base_diameter':24,'base_thickness':50,'handle_height':90,
            'base_axis':'local Y after source roll=90'},
        measured_candidate_floor_center_z=2.50300002098083,
            candidate_stair_head=stair_head,floor_footprint_rays=floors,
            approach_floor_rays=path_floors,body_height_clearance_rays=body_rays,
            source_eye_to_candidate_sight=lever_sight,
            boundary='Static source geometry only. No runtime lever, collider or player capsule is in the Diorama scene.'),
        p1=dict(source_plan_lock=plan['locks'][0],current_lock_and_face_los=occlusion,
            candidate_mount=candidate_lock,candidate_wall_support_rays=support,
            candidate_wall_grid=wall_grid,gate_dimensions=gate,
            face_orientation=dict(current_pitch=0,current_yaw=90,current_local_plus_z='world +Z',
                candidate_pitch=-90,candidate_yaw=90,candidate_local_plus_z='plan +Y'),
            boundary='Static source geometry only. Runtime keylock, gate leaf, frame and probe are absent from the Diorama scene.'),
        boundary='Read-only geometry survey. No Blender object, scene, map, asset or fitted source placement was changed.')
    OUT.parent.mkdir(parents=True,exist_ok=True)
    OUT.write_text(json.dumps(report,sort_keys=True,indent=2)+'\n',encoding='utf-8')
    print('MECHANISM_FIT_SURVEY',json.dumps(dict(status=report['status'],p5_candidate=lever,
        p5_floor_hits=sum(row['ray']['hit'] for row in floors),p5_los=lever_sight['hit'],
        p1_current_hit=occlusion['current_los']['object'],p1_candidate_hit=occlusion['candidate_los']['object'],
        output=str(OUT)),sort_keys=True),flush=True)


if __name__ == '__main__':
    main()
