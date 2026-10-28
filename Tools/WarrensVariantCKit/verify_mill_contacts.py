"""Measure actual hopper foot support against the mill mesh, not its envelope."""
import json
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
KIT = Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(KIT / 'Output/WarrensVariantC_KitLibrary.blend'))
mill = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('WarrensC_WVC023_'))
hopper = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('WarrensC_WVC062_'))
tree = BVHTree.FromPolygons([v.co.copy() for v in mill.data.vertices], [list(f.vertices) for f in mill.data.polygons])
bottom = min(v.co.z for v in hopper.data.vertices)
feet = [v.co.copy() for v in hopper.data.vertices if abs(v.co.z - bottom) < .00001]
rows = []
for sx, sy in [(-1, -1), (-1, 1), (1, -1), (1, 1)]:
    vertices = [v for v in feet if v.x * sx > 0 and v.y * sy > 0]
    center = sum(vertices, Vector()) / len(vertices)
    hits = []
    for v in vertices + [center]:
        hit = tree.ray_cast(Vector((v.x, v.y, 3)), Vector((0, 0, -1)))
        assert hit[0] is not None, 'Unsupported foot'
        hits.append(float(hit[0].z))
    rows.append(dict(foot=[sx, sy], center_xy=list(center)[:2], support_local_z_min=min(hits), support_local_z_max=max(hits)))
z = [r['support_local_z_min'] for r in rows]
assert max(z) - min(z) < .00001
suggested = 5 + min(z) - bottom
report = dict(feet=rows, hopper_mesh_bottom_z=bottom, suggested_plan_bottom_z=suggested,
              envelope_based_plan_bottom_z=7, envelope_placement_gap_cm=(7 - suggested) * 100)
out = ROOT / 'docs/art/warrens-c-gameplay-review-20261024/mill-composition/contacts.json'
out.write_text(json.dumps(report, indent=2) + '\n')
print('MILL_MESH_CONTACTS', json.dumps(report), flush=True)
