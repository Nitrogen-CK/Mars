"""Derive an open source-kit frame; never modify source FBX or game assets."""
import bpy, bmesh, json, hashlib, math
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'Output/Arch'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(OUT/'Source_ExtractionArch.fbx'))
audit = json.loads((OUT/'source_islands.json').read_text())['Source_ExtractionArch.fbx']
visual = bpy.data.objects['CryptExtractionArch_Mars_SM']
source_collision = bpy.data.objects['UCX_CryptExtractionArch_Mars_SM']
islands = next(o['islands'] for o in audit if o['name']==visual.name)
assert len(islands)==24 and islands[22]['vertices']==30 and islands[23]['vertices']==65
assert islands[22]['min'][0] > .74 and islands[22]['max'][0] < 3.26
removed = set(islands[22]['vertex_ids']+islands[23]['vertex_ids'])
before = [(tuple(visual.data.vertices[i].co), tuple(loop.uv))
          for poly in visual.data.polygons if not any(i in removed for i in poly.vertices)
          for i,loop in zip(poly.vertices,[visual.data.uv_layers[0].data[j] for j in poly.loop_indices])]
bm=bmesh.new(); bm.from_mesh(visual.data); bm.verts.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[bm.verts[i] for i in sorted(removed)], context='VERTS')
bm.to_mesh(visual.data); bm.free(); visual.data.update()
after=[(tuple(visual.data.vertices[i].co),tuple(loop.uv)) for poly in visual.data.polygons
       for i,loop in zip(poly.vertices,[visual.data.uv_layers[0].data[j] for j in poly.loop_indices])]
assert before==after, 'Retained geometry/UV changed'
visual.name='CampOpenArch_Mars_SM'; visual.data.name=visual.name
collision_audit=next(o['islands'] for o in audit if o['name']==source_collision.name)
collision=[]
for island in collision_audit:
    ids=island['vertex_ids']; remap={v:i for i,v in enumerate(ids)}
    verts=[source_collision.data.vertices[i].co[:] for i in ids]
    faces=[[remap[i] for i in p.vertices] for p in source_collision.data.polygons if p.vertices[0] in remap]
    mesh=bpy.data.meshes.new('collision'); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new('UCX_CampOpenArch_Mars_SM_%02d'%island['index'],mesh)
    bpy.context.collection.objects.link(obj); obj.matrix_world=source_collision.matrix_world.copy(); collision.append(obj)
bpy.data.objects.remove(source_collision,do_unlink=True)
bpy.ops.object.select_all(action='DESELECT')
for obj in [visual]+collision: obj.select_set(True)
bpy.context.view_layer.objects.active=visual
bpy.ops.export_scene.fbx(filepath=str(OUT/'CampOpenArch_Mars_SM.fbx'),use_selection=True,
    object_types={'MESH'},axis_forward='-Y',axis_up='Z',global_scale=1,apply_unit_scale=True,
    apply_scale_options='FBX_SCALE_NONE',bake_anim=False,use_triangles=True,mesh_smooth_type='FACE',path_mode='STRIP')
report=dict(removed_islands=[{k:v for k,v in i.items() if k!='vertex_ids'} for i in islands[22:]],
    retained_islands=22,retained_vertices=len(visual.data.vertices),retained_triangles=sum(len(p.vertices)-2 for p in visual.data.polygons),
    retained_uv_geometry_exact=True,collision=collision_audit,
    source_fbx_sha256=hashlib.sha256((OUT/'Source_ExtractionArch.fbx').read_bytes()).hexdigest())
(OUT/'derivation_report.json').write_text(json.dumps(report,indent=2))
# Review-only material; runtime retains original atlas material and UVs.
mat=bpy.data.materials.new('ReviewStone'); mat.diffuse_color=(.30,.34,.39,1)
visual.data.materials.clear(); visual.data.materials.append(mat)
for p in visual.data.polygons:p.material_index=0
for obj in collision:obj.hide_render=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32
scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.color=(.28,.28,.28)
bpy.ops.mesh.primitive_plane_add(size=200,location=(2,0,-.41));floor=bpy.context.object
ground=bpy.data.materials.new('ReviewGround');ground.diffuse_color=(.12,.15,.18,1);floor.data.materials.append(ground)
def point(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(0,-4,6));bpy.context.object.data.energy=900;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5;point(bpy.context.object,(2,0,1.5))
bpy.ops.object.camera_add(location=(2,-8,1.5));cam=bpy.context.object;point(cam,(2,0,1.5));cam.data.type='ORTHO';cam.data.ortho_scale=4.7;scene.camera=cam
scene.render.resolution_x=1000;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.filepath=str(OUT/'OpenArch_Front.png');bpy.ops.render.render(write_still=True)
cam.location=(5.7,-7,3.7);point(cam,(2,-.1,1.4));scene.render.filepath=str(OUT/'OpenArch_Oblique.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'CampOpenArch_Review.blend'))
print('OPEN_ARCH_DERIVED',json.dumps({k:v for k,v in report.items() if k!='collision'}))
