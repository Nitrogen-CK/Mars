"""Headless, parameterized moving P2 visuals; collision belongs to its owner.

Blender metres and negative Y export to Unreal centimetres and positive Y.
The origin stays at the seated span's near edge/top; no bounds recentering.
Only this directory's Output is written. Existing kit/library are untouched.
"""
import importlib.util
import json
import hashlib
from pathlib import Path

import bpy

HERE = Path(__file__).resolve().parent
OUT = HERE / 'Output'


def export_with_collision(obj, name, hulls):
    bpy.ops.object.select_all(action='DESELECT')
    obj.name = name + '_SOURCE'
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.scene.collection.objects.link(copy)
    copy.name = name
    temporary = [copy]
    for i, hull in enumerate(hulls):
        bpy.ops.mesh.primitive_cube_add(size=1, location=hull['centre_m'])
        collider = bpy.context.object
        collider.dimensions = hull['size_m']
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        collider.name = 'UCX_' + name + '_' + str(i).zfill(2)
        temporary.append(collider)
    bpy.ops.object.select_all(action='DESELECT')
    for item in temporary:
        for vertex in item.data.vertices:
            vertex.co *= 100
        item.select_set(True)
    bpy.context.view_layer.objects.active = copy
    scene = bpy.context.scene
    scale = scene.unit_settings.scale_length
    scene.unit_settings.scale_length = .01
    target = OUT / 'FBX' / (name + '.fbx')
    bpy.ops.export_scene.fbx(filepath=str(target), use_selection=True, object_types={'MESH'},
        global_scale=1, apply_unit_scale=True, apply_scale_options='FBX_SCALE_NONE',
        axis_forward='-Y', axis_up='Z', use_mesh_modifiers=False, mesh_smooth_type='FACE',
        use_triangles=True, bake_anim=False, path_mode='STRIP', use_custom_props=True)
    for item in temporary:
        bpy.data.objects.remove(item, do_unlink=True)
    scene.unit_settings.scale_length = scale
    obj.name = name
    return str(target.relative_to(OUT))


def finish(core, builder, name, hulls):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in builder.objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)
    for obj in builder.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = builder.objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.name = name
    obj.data.name = name + '_Mesh'
    uv = obj.data.uv_layers.new(name='UVMap')
    for face in obj.data.polygons:
        face.use_smooth = False
        axis = max(range(3), key=lambda k: abs(face.normal[k]))
        axes = [k for k in range(3) if k != axis]
        key = obj.data.materials[face.material_index]['catalog_key']
        tile = core.specs[key].get('tile_metres', [1, 1])
        for loop in face.loop_indices:
            vertex = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = tuple(vertex[a]/tile[k] for k, a in enumerate(axes))
    bounds = [[min(v.co[k] for v in obj.data.vertices)*100 for k in range(3)],
              [max(v.co[k] for v in obj.data.vertices)*100 for k in range(3)]]
    obj['collision_policy'] = 'Authored simple UCX boxes; same owner moves visual and collision'
    obj.asset_mark()
    fbx = export_with_collision(obj, name, hulls)
    return dict(id=builder.id, name=name, fbx=fbx,
                dimensions_cm=[bounds[1][k]-bounds[0][k] for k in range(3)],
                actual_dimensions_cm=[bounds[1][k]-bounds[0][k] for k in range(3)],
                bounds_min_cm=bounds[0], bounds_max_cm=bounds[1],
                materials=[m.name for m in obj.data.materials],
                material_keys=[m['catalog_key'] for m in obj.data.materials],
                triangles=sum(len(f.vertices)-2 for f in obj.data.polygons),
                collision_boxes_blender=hulls, expected_convex_count=len(hulls),
                source_sha256=hashlib.sha256((OUT/fbx).read_bytes()).hexdigest(), flags={})


def main(length=10.5, width=2.5, thickness=.2, height=2.2, screen=.1, canopy=.08):
    assert length > 0 and width > 2*screen and height > canopy
    spec = importlib.util.spec_from_file_location('p2_shared_blender', HERE.parents[1]/'ChainCrossingKit/build_kit.py')
    core = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(core)
    core.OUT = OUT
    for folder in ('FBX', 'Previews', 'Reports'):
        (OUT/folder).mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    core.setup_scene(scene, 'P2_SlidingSpan', .4)
    mats = core.load_materials()
    rows = []
    for ident, label in [('P2S01', 'Deck'), ('P2S02', 'Cage'), ('P2S03', 'Guard')]:
        col = bpy.data.collections.new('P2_' + label)
        scene.collection.children.link(col)
        part = dict(id=ident, materials=['TX08','TX09'], dimensions_cm=dict(width=width*100, depth=length*100, height=height*100))
        b = core.Builder(part, mats, col)
        if label == 'Deck':
            hulls = [dict(centre_m=[0,-length/2,-thickness/2], size_m=[width,length,thickness])]
            # A continuous support bed plus broad plank seams; exact top stays Z0.
            b.box('ContinuousBed', (0,-length/2,-thickness*.65), (width,length,thickness*.7), 'TX09', bevel=0)
            count = round(length/.35)
            for i in range(count):
                b.box('Plank'+str(i), (0,-(i+.5)*length/count,-thickness*.15),
                      (width,length/count-.012,thickness*.3), 'TX08', bevel=.008)
        elif label == 'Cage':
            hulls = [dict(centre_m=[side*(width-screen)/2,-length/2,height/2],
                          size_m=[screen,length,height]) for side in (-1,1)]
            hulls.append(dict(centre_m=[0,-length/2,height-canopy/2], size_m=[width,length,canopy]))
            # Closely spaced visible wire/slat screens explain their continuous
            # collision boundary; no opening is wide enough for a chef/pack.
            for side in (-1,1):
                x = side*(width/2-screen/2)
                for z in (.06, .75, 1.45, height-.06):
                    b.box('LongitudinalFrame', (x,-length/2,z), (screen,length,.12), 'TX09', bevel=.009)
                count = round(length/.28)
                for i in range(count+1):
                    y = -.0225-i*(length-.045)/count
                    b.box('ScreenUpright', (x,y,height/2), (screen,.045,height), 'TX09', bevel=.005)
                for z in [j*.24 for j in range(1,9)]:
                    b.box('ScreenCross', (x,-length/2,z), (.045,length,.035), 'TX09', bevel=0)
            # Canopy underside is exactly 2.12 m over the deck.
            b.box('Canopy', (0,-length/2,height-canopy/2), (width,length,canopy), 'TX08', bevel=0)
        else:
            guard_width, guard_depth = width-2*screen, .08
            hulls = [dict(centre_m=[0,0,height/2],size_m=[guard_width,guard_depth,height])]
            count = round(guard_width/.14)
            for i in range(count+1):
                x = -guard_width/2+.025+i*(guard_width-.05)/count
                b.box('GuardUpright',(x,0,height/2),(.05,guard_depth,height),'TX09',bevel=.004)
            for z in [.04,.55,1.1,1.65,height-.04]:
                b.box('GuardCross',(0,0,z),(guard_width,guard_depth,.08),'TX09',bevel=.005)
        rows.append(finish(core,b,'WarrensC_'+ident+'_'+label+'_Mars_SM',hulls))
    core.camera(scene,(10,-17,10),(0,-length/2,1),17)
    core.light(scene,'Key',(5,-8,10),2500,size=8,target=(0,-5,1))
    core.light(scene,'Fill',(-6,-2,5),1200,size=7,target=(0,-5,1))
    scene.render.resolution_x=1200
    scene.render.resolution_y=800
    scene.render.filepath=str(OUT/'Previews/P2_SlidingSpan.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'P2_SlidingSpan.blend'))
    bpy.ops.render.render(write_still=True)
    manifest=dict(assets=rows,parameters_metres=dict(length=length,width=width,thickness=thickness,
                  height=height,screen=screen,canopy=canopy),
                  collision='Authored UCX: deck1, cage3, guard1. Import must preserve/verify them; no generated hull.',
                  source_axes='Blender X,-Y,Z to Unreal X,Y,Z; pivot is seated near edge, deck top Z0')
    (OUT/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))
    print('P2_SPAN_GENERATED',json.dumps(manifest))


if __name__ == '__main__':
    main()
