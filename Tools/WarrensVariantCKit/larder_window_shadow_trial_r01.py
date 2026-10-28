"""Diagnostic only: one owned window light's shadow contribution, A/B/A."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def set_shadow(controller,on):
    import unreal as u
    gate=json.loads((DOC/'NATIVE_WINDOW_SHADOW_GATE_R01.json').read_text());assert gate['status']=='APPROVED_OWNED_WINDOW_SHADOW_ABA_DIAGNOSTIC_ONLY' and gate['tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__)
    assert isinstance(on,bool);controller.check();s=controller.STATE;c=s['light'];assert s['on'] and c.intensity==7200 and c.source_width==220 and c.source_height==400 and c.intensity_units==u.LightUnits.LUMENS and c.mobility==u.ComponentMobility.MOVABLE and c.get_editor_property('use_temperature') is False
    assert controller.OWNER in [str(v) for v in s['actor'].tags]
    before=controller.own_light();expected=dict(before,shadow=on);c.set_cast_shadows(on);assert controller.own_light()==expected
    s['own_before']=dict(s['own_before'],shadow=on);controller.check();print('OWNED_WINDOW_SHADOW_DIAGNOSTIC',on)
