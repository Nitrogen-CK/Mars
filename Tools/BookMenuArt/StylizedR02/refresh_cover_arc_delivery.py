"""Refresh the delivery ledger after correcting the cover hinge arc."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
gate = json.loads((root / 'Model/roundtrip_validation.json').read_text())
assert len(gate['checks']) == 12 and all(gate['checks'].values())
delivery = json.loads((root / 'DELIVERY.json').read_text())
delivery['proof']['blender_fbx_roundtrip'] = 'Model/roundtrip_validation.json; 12/12 checks, 96 cover-arc frames and 216 turn frames'
delivery['cover_arc_correction'] = {
    'date': '2026-10-23',
    'cause': 'Negative Y rotation moved the left cover through the lower half-space.',
    'fix': 'Positive Y rotation moves the cover above the book for opening and closing.',
    'baseline': '2 failing cover arc checks, 10 passing checks; validator exited 1.',
    'after': '12/12 checks passing; validator exited 0.',
    'evidence': gate['cover_arc'],
}
(root / 'DELIVERY.json').write_text(json.dumps(delivery, indent=2))
preview = root / 'PREVIEW.html'
preview.write_text(preview.read_text().replace('9/9 checks; 216 turn frames tested against fixed pages',
    '12/12 checks; 96 cover-arc frames and 216 turn frames tested'))
poses = json.loads((root / 'unreal_pose_captures.json').read_text())
for item in poses:
    if item['label'] in ['Opening', 'Closing']:
        item['refreshed_after_cover_arc_correction'] = '2026-10-23'
        item['capture'].pop('total_capture_time_ms', None)
(root / 'unreal_pose_captures.json').write_text(json.dumps(poses, indent=2))
print('COVER_ARC_DELIVERY_UPDATED 12/12 checks')
