"""Read-only source FBX island audit. Outputs only under ../Output/Arch."""
import bpy, json
from pathlib import Path
from mathutils import Vector

OUT = Path(__file__).resolve().parents[1] / 'Output/Arch'
report = {}
for source in ['Source_ExtractionArch.fbx', 'Source_BarredArch.fbx']:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(OUT / source))
    objects = []
    for obj in bpy.data.objects:
        if obj.type != 'MESH':
            continue
        mesh = obj.data
        adjacent = {v.index: set() for v in mesh.vertices}
        for edge in mesh.edges:
            a, b = edge.vertices
            adjacent[a].add(b); adjacent[b].add(a)
        pending = set(adjacent); islands = []
        while pending:
            seed = min(pending); stack = [seed]; group = set()
            while stack:
                current = stack.pop()
                if current in group:
                    continue
                group.add(current); pending.discard(current)
                stack.extend(adjacent[current] - group)
            points = [obj.matrix_world @ mesh.vertices[i].co for i in group]
            polygons = [p for p in mesh.polygons if p.vertices[0] in group]
            islands.append(dict(index=len(islands), vertices=len(group), faces=len(polygons),
                vertex_ids=sorted(group), materials=sorted(set(p.material_index for p in polygons)),
                min=[min(v[i] for v in points) for i in range(3)],
                max=[max(v[i] for v in points) for i in range(3)]))
        objects.append(dict(name=obj.name, matrix=[list(r) for r in obj.matrix_world],
            materials=[m.name if m else None for m in mesh.materials],
            uv_layers=[uv.name for uv in mesh.uv_layers], islands=islands))
    report[source] = objects
(OUT / 'source_islands.json').write_text(json.dumps(report, indent=2))
print(json.dumps({k:[dict(name=o['name'],materials=o['materials'],uv=o['uv_layers'],
    islands=[{key:value for key,value in item.items() if key != 'vertex_ids'} for item in o['islands']])
    for o in v] for k,v in report.items()}, indent=2))
