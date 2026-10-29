"""Read an Unreal-exported Steward FBX and report actual imported rig frames."""
import bpy, json, sys
from pathlib import Path
from mathutils import Vector

root = Path(__file__).resolve().parents[1] / 'Output/Art'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=str(root / 'Steward_Source.fbx'))
report = []
for o in bpy.context.scene.objects:
    row = dict(name=o.name, type=o.type, parent=o.parent.name if o.parent else None,
               matrix=[list(r) for r in o.matrix_world], dimensions=list(o.dimensions))
    if o.type == 'ARMATURE':
        row['bones'] = [dict(name=b.name, parent=b.parent.name if b.parent else None,
                            head=list(o.matrix_world @ b.head_local), tail=list(o.matrix_world @ b.tail_local))
                        for b in o.data.bones]
    if o.type == 'MESH':
        row['materials'] = [m.name if m else None for m in o.data.materials]
    report.append(row)
(root / 'source_inspection.json').write_text(json.dumps(report, indent=2))
print('STEWARD_SOURCE_INSPECTED', json.dumps(report))
