"""Exact-pose actual-lantern A/B metadata; screenshot decode is a separate gate."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
VIEWS={
    'arrival':([116,35],-2.9,[122,43,-.5]),
    'wall_grazing':([127.5,37],-2.5,[131,38,0]),
    'bank_ledge':([124,46],-2.9,[120,51,-.4]),
    'storage':([130,39.5],-2.5,[135.5,38.5,-1]),
    'ceiling':([130,39.5],-2.5,[134,38.8,2.08]),
    'bell':([120,40],-2.9,[104,50,16]),
    'barrel':([110.6,42.5],-2.5,[109.59,42.5,-1.8]),
}


def prepare(capture,view):
    assert view in VIEWS
    xy,z,target=VIEWS[view];capture.position(view,xy,z,target)


def capture_frame(capture,view,label):
    import unreal as u
    s=capture.STATE;assert s and label in ('A_source','B_surface') and s['view']==view
    assert (s['pawn'].get_actor_location()-u.Vector(*s['expected_pawn'])).length()<3,'Pawn moved from requested supported floor pose'
    capture.capture(view+'_'+label)


def verify_pair(capture,view):
    s=capture.STATE;assert s
    paths=[s['out']/(view+'_'+label+'.json') for label in ('A_source','B_surface')]
    a,b=[json.loads(p.read_text()) for p in paths]
    fields=['world','pawn','camera','rotation','fov','inventory','real_lantern','aa','source_maps','guard_sha256','world_time']
    assert all(a[k]==b[k] for k in fields),[(k,a[k],b[k]) for k in fields if a[k]!=b[k]]
    pngs=[p.with_suffix('.png') for p in paths]
    assert all(p.is_file() and p.read_bytes().endswith(bytes.fromhex('0000000049454e44ae426082')) for p in pngs)
    target=s['out']/(view+'_pair.json');assert not target.exists();target.write_text(json.dumps(dict(status='EXACT_ACTUAL_CAMERA_AND_REAL_LANTERN_METADATA_PAIR_PNG_DECODE_STILL_REQUIRED',view=view,equal_fields=fields,frames=[dict(file=p.name,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in pngs],signature={k:a[k] for k in fields},boundary='Same paused actual Main PIE world/camera/pawn/inventory/real equipped lantern/AA/source hashes. Only the three disposable NoCollision surface meshes toggle visibility. PNG IEND checked here; full pixel decode and appearance review remain separate. Teleport capture, not played duration/physical input/multiplayer proof.'),indent=2)+'\n');print('EXACT_LARDER_SURFACE_PAIR',view)
