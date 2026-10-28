"""Finite intensity calibration of the already-owned disposable window light."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def set_intensity(controller,value):
    import unreal as u
    gate=json.loads((DOC/'NATIVE_WINDOW_INTENSITY_GATE_R01.json').read_text());assert gate['status']=='APPROVED_OWNED_LIGHT_FINITE_INTENSITY_CALIBRATION_ONLY' and gate['tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__)
    assert value in (1800,7200,14400);controller.check();s=controller.STATE;assert s['on'] is True
    a=s['actor'];c=s['light'];assert a.get_world()==s['world'] and controller.OWNER in [str(v) for v in a.tags] and c.intensity_units==u.LightUnits.LUMENS and c.mobility==u.ComponentMobility.MOVABLE and c.get_editor_property('use_temperature') is False
    before=controller.own_light();expected=dict(before,intensity=float(value));c.set_intensity(float(value));assert controller.own_light()==expected
    # This is the expected photometry of our newly-created temporary light,
    # not the immutable five original lights. Their full sampled baseline
    # remains untouched and check() still compares it exactly.
    s['own_before']=dict(s['own_before'],intensity=float(value));controller.check();print('OWNED_WINDOW_LIGHT_CALIBRATION_LUMENS',value)
