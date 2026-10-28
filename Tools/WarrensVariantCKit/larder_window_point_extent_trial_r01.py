"""Final finite emitter-extent diagnostic; every existing caster stays enabled."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def set_extent(controller,near_point):
    import unreal as u
    gate=json.loads((DOC/'NATIVE_WINDOW_POINT_EXTENT_GATE_R01.json').read_text())
    assert gate['status']=='APPROVED_OWNED_WINDOW_POINT_EXTENT_ABA_DIAGNOSTIC_ONLY' and gate['tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__)
    assert isinstance(near_point,bool)
    controller.check();s=controller.STATE;c=s['light']
    assert s['on'] and c.intensity==7200 and c.cast_shadows and c.intensity_units==u.LightUnits.LUMENS and c.mobility==u.ComponentMobility.MOVABLE and c.get_editor_property('use_temperature') is False
    assert controller.OWNER in [str(v) for v in s['actor'].tags]
    assert (c.source_width,c.source_height) in ((220.,400.),(1.,1.))
    width,height=(1.,1.) if near_point else (220.,400.)
    before=controller.own_light();expected=dict(before,width=width,height=height)
    c.set_source_width(width);c.set_source_height(height)
    assert controller.own_light()==expected
    s['own_before']=dict(s['own_before'],width=width,height=height)
    controller.check();print('OWNED_WINDOW_FINAL_POINT_EXTENT_CM',width,height)
