"""Read-only P3 goal-cue wall survey against the canonical C Diorama."""
import hashlib
import json
import math
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'Output/WarrensVariantC_Diorama.blend'
SOURCE_SHA = '2fb8dfdfbf1a3ad1a5e019204fc679d827eda137381f4b86934fd7b71dbcc7dc'
FIT = HERE / 'Output/fitted_instances.json'
PLAN = ROOT / 'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json'
OUT = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalWallSurvey/receipt.json'
OUT_CACHE = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalWallSurvey/receipt.cache.json'
OUT_REFINED = ROOT / 'Saved/WarrensCGameplay-20261024/P3GoalWallSurvey/receipt.outer2.json'
PLATE_CAMERA = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/ART_held_p3_plate_arrival.json'
CACHE_CAMERA = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/ART_held_p3_cache_before.json'
KIT_LIBRARY = HERE / 'Output/WarrensVariantC_KitLibrary.blend'
SCENE_NAME = '02_VariantC_Cutaway'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def point(plan):
    return Vector((plan[0] - 58.0, 55.0 - plan[1], plan[2]))


def plan_point(world):
    return [world.x + 58.0, 55.0 - world.y, world.z]


def ray(scene, graph, plan_origin, direction, distance=12.0):
    origin = point(plan_origin)
    vector = Vector(direction).normalized()
    hit, location, normal, face, obj, matrix = scene.ray_cast(graph, origin, vector, distance=distance)
    return dict(origin_plan=list(plan_origin), direction_blender=list(vector), hit=hit,
        hit_plan=plan_point(location) if hit else None, location=list(location) if hit else None,
        normal=list(normal) if hit else None, face_index=face if hit else None,
        object=obj.name if hit else None, object_data=obj.data.name if hit and obj.data else None,
        distance=(location-origin).length if hit else None)


def main():
    refine = '--refine' in sys.argv
    board_scale_value = 1.0 if refine else 1.1
    candidate_base_z = 3.0 if refine else 3.7
    assert sha(SOURCE) == SOURCE_SHA, 'Canonical Diorama changed; refuse survey'
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    scene = bpy.data.scenes[SCENE_NAME]
    bpy.context.window.scene = scene
    graph = bpy.context.evaluated_depsgraph_get()

    fit = json.loads(FIT.read_text(encoding='utf-8'))
    plan = json.loads(PLAN.read_text(encoding='utf-8'))
    p3 = next(item for item in plan['puzzles'] if item.get('id') == 'P3')
    assert p3['needsAt'] == [42, 66, 2.5] and p3['at'] == [100, 76, 2.5]
    rows = fit['placements']
    board_row = next(row for row in rows if row.get('tile') == 'Ossuary' and row.get('id') == 'CCS78')
    card_row = next(row for row in rows if row.get('tile') == 'Ossuary' and row.get('id') == 'WVC083_ART04')
    assert board_row['at'] == [54, 68.31, 3.7] and card_row['at'] == [54.0, 68.331, 3.7]
    board_collection = bpy.data.collections['CCS78_MaintenanceNoticeBoard']
    card_collection = bpy.data.collections['WVC083_EmblemSurfaceCarrier']
    board_obj = next(iter(board_collection.objects))
    card_obj = next(iter(card_collection.objects))
    assert board_row['scale'] == [1.1, 1, 1] and card_row['scale'] == [1, 1, 1]

    # Inspect all four local approaches; the west ray is the hypothesized closed wall.
    plate = [42.0, 66.0, 3.5]
    directions = {'west': (-1, 0, 0), 'east': (1, 0, 0), 'south': (0, 1, 0), 'north': (0, -1, 0)}
    approach_rays = {name: ray(scene, graph, plate, direction) for name, direction in directions.items()}
    west = approach_rays['west']
    print('P3_APPROACH_RAYS', json.dumps(approach_rays, sort_keys=True), flush=True)
    assert west['hit'] and west['normal'][0] > 0.95, 'Westward ray did not identify a wall facing the plate'
    gate_probe_points = ([99.0, 76.0, 3.5], [100.25, 76.0, 3.5])
    gate_probes = {str(center[:2]): {name: ray(scene, graph, center, direction, 3.0)
                      for name, direction in directions.items()} for center in gate_probe_points}
    gate_grid = []
    for x in (99.0, 99.5, 100.0, 100.5, 101.0, 101.5, 102.0):
        for y in (74.0, 74.5, 75.0, 75.5, 76.0, 76.5, 77.0, 77.5, 78.0):
            for direction_name, direction in directions.items():
                probe = ray(scene, graph, [x, y, 3.7], direction, 2.5)
                if probe['hit']:
                    gate_grid.append(dict(at=[x, y], direction=direction_name,
                        hit_plan=probe['hit_plan'], normal=probe['normal'], object=probe['object'],
                        distance=probe['distance']))
    print('P3_GATE_GRID', json.dumps(dict(hit_count=len(gate_grid),
        sample_count=len(gate_probe_points)*len(directions)), sort_keys=True), flush=True)

    # Orient the existing board to face east from the west wall (yaw -90 plan-space).
    yaw = -90.0
    angle = math.radians(-yaw)
    rotation = Matrix.Rotation(angle, 4, 'Z')
    scale = Matrix.Diagonal(Vector((board_scale_value, 1.0, 1.0, 1.0)))
    local_points = [board_obj.matrix_basis @ vertex.co for vertex in board_obj.data.vertices]
    local_y_max = max(p.y for p in local_points)
    back = [p for p in local_points if abs(p.y-local_y_max) < 1e-5]
    assert len(back) >= 4
    local_x = [p.x for p in back]
    local_z = [p.z for p in back]
    bounds = dict(local_back_y=local_y_max, local_x=[min(local_x), max(local_x)],
                  local_z=[min(local_z), max(local_z)], vertex_count=len(board_obj.data.vertices))
    source_wall_x = west['location'][0]
    transformed = [rotation @ (scale @ Vector((p.x, p.y, p.z, 1.0))) for p in back]
    x_offset = min(v.x for v in transformed)
    origin_world_x = source_wall_x - x_offset
    origin_plan = [origin_world_x + 58.0, plate[1], candidate_base_z]

    # Five inset samples on the actual rear face; preserve initial penetrations,
    # then move only toward the player until every sample is non-penetrating.
    if refine:
        xs = [min(local_x), (min(local_x)+max(local_x))*0.5, max(local_x)]
        zs = [max(local_z), (min(local_z)+max(local_z))*0.5, min(local_z)]
    else:
        xs = [min(local_x)*0.9 + max(local_x)*0.1, (min(local_x)+max(local_x))*0.5,
              min(local_x)*0.1 + max(local_x)*0.9]
        zs = [min(local_z)*0.1 + max(local_z)*0.9, (min(local_z)+max(local_z))*0.5,
              min(local_z)*0.9 + max(local_z)*0.1]
    local_samples = [(xs[0], local_y_max, zs[0]), (xs[2], local_y_max, zs[0]),
                     (xs[0], local_y_max, zs[2]), (xs[2], local_y_max, zs[2]),
                     (xs[1], local_y_max, zs[1])]
    def support_samples(board_origin_world, wall_direction):
        samples = []
        for lx, ly, lz in local_samples:
            offset = rotation @ (scale @ Vector((lx, ly, lz, 1.0)))
            rear_world = board_origin_world + offset.xyz
            ray_origin = rear_world - wall_direction * 0.05
            hit, location, normal, face, obj, matrix = scene.ray_cast(
                graph, ray_origin, wall_direction, distance=0.10)
            if not (hit and normal.dot(-wall_direction) > 0.95):
                raise AssertionError(f'Rear-face sample misses fixed wall: {lx,lz}')
            gap = (location-ray_origin).length - 0.05
            samples.append(dict(rear_world=list(rear_world), hit=list(location),
                hit_plan=plan_point(location), normal=list(normal), object=obj.name,
                source_data=obj.data.name if obj.data else None, gap_m=gap))
        return samples

    plate_origin_world = point(origin_plan)
    plate_wall_direction = Vector((-1, 0, 0))
    initial_plate_samples = support_samples(plate_origin_world, plate_wall_direction)
    plate_shift = max(0.0, -min(row['gap_m'] for row in initial_plate_samples) + 1e-6)
    plate_origin_world.x -= plate_wall_direction.x * plate_shift
    origin_plan[0] += plate_shift
    wall_samples = support_samples(plate_origin_world, plate_wall_direction)
    assert min(row['gap_m'] for row in wall_samples) >= -1e-5
    assert max(row['gap_m'] for row in wall_samples) <= 0.012

    # Record source identities and approach margins; no candidate geometry is added to the file.
    board_plan = dict(at=origin_plan, scale=[board_scale_value, 1, 1], yaw=yaw, mesh_id='CCS78',
        collection=board_collection.name, source_role=board_row['role'], collision=board_row['collision'])
    card_at = [origin_plan[0] + 0.021, origin_plan[1], candidate_base_z]
    card_plan = dict(at=card_at, scale=card_row['scale'], yaw=yaw, mesh_id='WVC083_ART04',
        collection=card_collection.name, material=card_row.get('material', 'ART04'),
        source_role=card_row['role'], collision=card_row['collision'])
    plan_delta_m = math.hypot(board_plan['at'][0]-plate[0], board_plan['at'][1]-plate[1])
    gate_delta_m = math.hypot(board_plan['at'][0]-p3['at'][0], board_plan['at'][1]-p3['at'][1])
    assert gate_delta_m > 1.0
    eye = point([42.0, 66.0, 4.0])
    target = Vector((source_wall_x-0.05, point(origin_plan).y, 3.7))
    sight = target-eye
    line = scene.ray_cast(graph, eye, sight.normalized(), distance=sight.length+0.02)
    assert line[0] and line[4].name == west['object'], 'Plate-side eye does not see the candidate wall'

    report = dict(status='SOURCE_GEOMETRY_SURVEY_COMPLETE', source=str(SOURCE.relative_to(ROOT)),
        source_sha256=SOURCE_SHA, scene=SCENE_NAME, plate=dict(plan=plate, source='P3.needsAt'),
        gate=dict(plan=p3['at'], source='P3.at', role=p3['kind']),
        approach_rays=approach_rays, gate_probe_rays=gate_probes,
        chosen_wall=dict(object=west['object'], data=west['object_data'],
            hit_plan=west['hit_plan'], normal=west['normal'], source_ray=west,
            support_objects=sorted(set(row['object'] for row in wall_samples)),
            support_x_span_m=max(row['hit'][0] for row in wall_samples)-min(row['hit'][0] for row in wall_samples)),
        source_board_row=board_row, source_card_row=card_row, board_local_bounds=bounds,
        candidate=dict(board=board_plan, card=card_plan, yaw_faces_east=True,
            source_wall_witnesses=wall_samples, plate_to_board_center_m=plan_delta_m,
            board_to_gate_center_m=gate_delta_m, plate_eye_line_of_sight=dict(hit_object=line[4].name,
                hit_plan=plan_point(line[1]), direction=list(sight.normalized()))),
        boundary='Read-only source-mesh survey. Candidate is a proposed relocation of fitted CCS78/WVC083_ART04; no object/material/collection/scene/map was added or saved. Blender source scene contains static art only and does not prove runtime gate/plate visibility, collision or gameplay approval.')
    report['candidate']['initial_penetrating_plate_support'] = initial_plate_samples
    report['candidate']['plate_shift_toward_player_m'] = plate_shift

    # Cache candidate: fixed west-facing wall strip immediately beside the gate
    # opening. This is geometry evidence only; gate leaf/frame remain runtime-only.
    cache_center = [100.0, 74.4, candidate_base_z]
    cache_probe = ray(scene, graph, [99.0, 74.4, 3.7], (1, 0, 0), 3.0)
    assert cache_probe['hit'] and cache_probe['normal'][0] < -0.95
    cache_yaw = 90.0
    cache_rotation = Matrix.Rotation(math.radians(-cache_yaw), 4, 'Z')
    cache_front = Vector((-1, 0, 0))
    cache_wall_direction = -cache_front
    cache_samples = []
    # Reuse the same rear-plane local extrema and five-point layout; cache orientation
    # uses the card-facing normal toward the outside approach (-X).
    cache_scale = Matrix.Diagonal(Vector((board_scale_value, 1.0, 1.0, 1.0)))
    cache_back_y = max(p.y for p in local_points)
    cache_back = [p for p in local_points if abs(p.y-cache_back_y) < 1e-5]
    cache_x = [p.x for p in cache_back]
    cache_z = [p.z for p in cache_back]
    if refine:
        cxs = [min(cache_x), (min(cache_x)+max(cache_x))*0.5, max(cache_x)]
        czs = [max(cache_z), (min(cache_z)+max(cache_z))*0.5, min(cache_z)]
    else:
        cxs = [min(cache_x)*0.9 + max(cache_x)*0.1, (min(cache_x)+max(cache_x))*0.5,
               min(cache_x)*0.1 + max(cache_x)*0.9]
        czs = [min(cache_z)*0.1 + max(cache_z)*0.9, (min(cache_z)+max(cache_z))*0.5,
               min(cache_z)*0.9 + max(cache_z)*0.1]
    cache_local_samples = [(cxs[0], czs[0]), (cxs[2], czs[0]), (cxs[0], czs[2]),
                           (cxs[2], czs[2]), (cxs[1], czs[1])]
    cache_world_x = cache_probe['location'][0]
    cache_origin = point(cache_center)
    cache_transformed = [cache_rotation @ (cache_scale @ Vector((x, cache_back_y, z, 1)))
                         for x, z in cache_local_samples]
    cache_origin.x = cache_world_x - min(v.x for v in cache_transformed)
    def cache_support_samples(board_origin):
        result = []
        for (lx, lz), offset in zip(cache_local_samples, cache_transformed):
            rear = board_origin + offset.xyz
            ray_origin = rear - cache_wall_direction * 0.05
            hit, loc, normal, face, obj, matrix = scene.ray_cast(
                graph, ray_origin, cache_wall_direction, distance=0.10)
            if not (hit and normal.dot(-cache_wall_direction) > 0.95):
                raise AssertionError(f'Cache rear-face sample misses fixed wall: {lx,lz}')
            gap = (loc-ray_origin).length - 0.05
            result.append(dict(rear_world=list(rear), hit=list(loc), hit_plan=plan_point(loc),
                normal=list(normal), object=obj.name, source_data=obj.data.name if obj.data else None,
                gap_m=gap))
        return result
    initial_cache_samples = cache_support_samples(cache_origin)
    cache_shift = max(0.0, -min(row['gap_m'] for row in initial_cache_samples) + 1e-6)
    cache_origin.x -= cache_shift * cache_wall_direction.x
    cache_samples = cache_support_samples(cache_origin)
    assert min(row['gap_m'] for row in cache_samples) >= -1e-5
    assert max(row['gap_m'] for row in cache_samples) <= 0.012
    cache_plan_at = plan_point(cache_origin)
    cache_board = dict(at=cache_plan_at, scale=[board_scale_value, 1, 1], yaw=cache_yaw,
        mesh_id='CCS78', collection=board_collection.name, source_role=board_row['role'],
        collision=board_row['collision'])
    cache_card = dict(at=[cache_plan_at[0]-0.021, cache_plan_at[1], candidate_base_z],
        scale=card_row['scale'], yaw=cache_yaw, mesh_id='WVC083_ART04',
        collection=card_collection.name, material=card_row.get('material', 'ART04'),
        source_role=card_row['role'], collision=card_row['collision'])
    outside_eye = point([98.5, 76.0, 4.0])
    cache_target = Vector((cache_origin.x - 0.05, cache_origin.y, cache_origin.z + 0.5))
    cache_sight = cache_target - outside_eye
    cache_los = scene.ray_cast(graph, outside_eye, cache_sight.normalized(),
                              distance=cache_sight.length + 0.02)
    report['cache_candidate'] = dict(board=cache_board, card=cache_card,
        source_wall_witness=cache_probe, initial_support=initial_cache_samples,
        support=cache_samples, shift_toward_outside_m=cache_shift,
        projected_width_m=(max(cache_x)-min(cache_x))*board_scale_value,
        fixed_strip_y_m=[74.0, 75.0],
        clearance_to_strip_edges_m=[cache_plan_at[1]-(max(cache_x)-min(cache_x))*board_scale_value/2.0-74.0,
            75.0-(cache_plan_at[1]+(max(cache_x)-min(cache_x))*board_scale_value/2.0)],
        clearance_to_runtime_gate_post_inner_edge_m=74.8-(cache_plan_at[1]+(max(cache_x)-min(cache_x))*board_scale_value/2.0),
        outside_static_sightline=dict(hit=cache_los[0],
            hit_object=cache_los[4].name if cache_los[0] else None,
            hit_plan=plan_point(cache_los[1]) if cache_los[0] else None,
            target_plan=plan_point(cache_target), outside_eye_plan=[98.5,76.0,4.0]),
        boundary='Static scene ray only. Runtime gate actor is absent; visibility through its closed/open states is unproven.')
    if refine:
        # Project every actual ART04 source vertex at the candidate transform through
        # the saved PIE camera. This is geometric frustum evidence, not a render.
        camera = json.loads(PLATE_CAMERA.read_text(encoding='utf-8'))
        def project_card(card_at_plan, card_yaw, camera_path):
            camera = json.loads(camera_path.read_text(encoding='utf-8'))
            cam = Vector(camera['camera'])
            roll, pitch_deg, yaw_deg = camera['rotation_roll_pitch_yaw']
            pitch = math.radians(pitch_deg)
            yaw_cam = math.radians(yaw_deg)
            forward = Vector((math.cos(pitch)*math.cos(yaw_cam), math.cos(pitch)*math.sin(yaw_cam), math.sin(pitch)))
            right = Vector((-math.sin(yaw_cam), math.cos(yaw_cam), 0.0))
            up = Vector((-math.sin(pitch)*math.cos(yaw_cam), -math.sin(pitch)*math.sin(yaw_cam), math.cos(pitch)))
            tan_h = math.tan(math.radians(camera['fov'])*0.5)
            aspect = 1.6
            tan_v = tan_h/aspect
            vertices = [card_obj.matrix_basis @ v.co for v in card_obj.data.vertices]
            card_rot = Matrix.Rotation(math.radians(-card_yaw), 4, 'Z')
            points = []
            for v in vertices:
                offset = card_rot @ Vector((v.x, v.y, v.z, 1.0))
                px, py = card_at_plan[0]+offset.x, card_at_plan[1]-offset.y
                pz = card_at_plan[2]+offset.z
                world = Vector(((px-70.0)*100.0, (py-55.0)*100.0, pz*100.0))
                rel = world-cam
                depth = rel.dot(forward)
                sx = rel.dot(right)/(depth*tan_h) if depth > 0 else float('inf')
                sy = rel.dot(up)/(depth*tan_v) if depth > 0 else float('inf')
                points.append(dict(world_cm=list(world), depth_cm=depth, screen_ndc=[sx,sy],
                    in_frame=depth > 0 and abs(sx) <= 1 and abs(sy) <= 1))
            return dict(camera_source=str(camera_path.relative_to(ROOT)), camera_sha256=sha(camera_path),
                all_vertices=len(points), all_in_frame=all(p['in_frame'] for p in points),
                x_range=[min(p['screen_ndc'][0] for p in points), max(p['screen_ndc'][0] for p in points)],
                y_range=[min(p['screen_ndc'][1] for p in points), max(p['screen_ndc'][1] for p in points)],
                min_depth_cm=min(p['depth_cm'] for p in points), points=points)
        plate_card_projection = project_card(card_plan['at'], yaw, PLATE_CAMERA)
        plate_card_at_original_z = list(card_plan['at'])
        plate_card_at_original_z[2] = 3.7
        plate_card_projection_at_original_z = project_card(plate_card_at_original_z, yaw, PLATE_CAMERA)
        cache_card_projection = project_card(cache_card['at'], cache_yaw, CACHE_CAMERA)
        report['refinement'] = dict(board_scale=board_scale_value, base_z=candidate_base_z,
            plate_card_frustum=plate_card_projection,
            plate_card_frustum_if_base_z_3_7=plate_card_projection_at_original_z,
            cache_card_frustum=cache_card_projection,
            board_child_transform=dict(matrix_basis=[list(row) for row in board_obj.matrix_basis],
                raw_mesh_max_y=max(v.co.y for v in board_obj.data.vertices),
                basis_transformed_max_y=max((board_obj.matrix_basis @ v.co).y for v in board_obj.data.vertices)),
            source_pair=dict(board_objects=[o.name for o in board_collection.objects],
                board_data=[o.data.name if o.data else None for o in board_collection.objects],
                board_material_slots=[[(s.link, s.material.name if s.material else None) for s in o.material_slots]
                    for o in board_collection.objects],
                card_objects=[o.name for o in card_collection.objects],
                card_data=[o.data.name if o.data else None for o in card_collection.objects],
                card_material_slots=[[(s.link, s.material.name if s.material else None) for s in o.material_slots]
                    for o in card_collection.objects],
                matching_scene_objects=[dict(name=o.name, matrix_basis=[list(row) for row in o.matrix_basis],
                    matrix_world=[list(row) for row in o.matrix_world],
                    instance_collection=o.instance_collection.name if o.instance_collection else None)
                    for o in bpy.data.objects if ('CCS78' in o.name or 'WVC083' in o.name)],
                source_placement_indices=dict(CCS78=37274, WVC083_ART04=37275),
                fitted_instances_sha256=sha(FIT), diorama_sha256=sha(SOURCE),
                kit_library_sha256=sha(KIT_LIBRARY)),
            boundary='Vertex frustum projection uses saved player camera and static candidate mesh geometry; no runtime render or walkability claim.')
    OUT.parent.mkdir(parents=True, exist_ok=True)
    output = OUT_REFINED if refine else (OUT_CACHE if '--cache-only' in sys.argv else OUT)
    output.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n', encoding='utf-8')
    print('P3_GOAL_WALL_SURVEY', json.dumps(dict(status=report['status'], wall=west['object'], board=board_plan['at'],
        gap_m=[round(x['gap_m'], 6) for x in wall_samples], cache=cache_board['at'],
        cache_gap_m=[round(x['gap_m'], 6) for x in cache_samples],
        output=str(output), plate_to_board_m=round(plan_delta_m, 3)), sort_keys=True), flush=True)


if __name__ == '__main__':
    main()
