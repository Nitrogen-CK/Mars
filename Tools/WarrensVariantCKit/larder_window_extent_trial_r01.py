"""One-axis A/B/A source-extent test on the existing disposable window light."""
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/larder-complete-room-r01'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def set_extent(controller,small):
    import unreal as u
    gate=json.loads((DOC/'NATIVE_WINDOW_EXTENT_GATE_R01.json').read_text());assert gate['status']=='APPROVED_OWNED_LIGHT_SOURCE_EXTENT_ABA_ONLY' and gate['tool_sha256']==sha(__file__) and gate['controller_sha256']==sha(controller.__file__)
    assert isinstance(small,bool);controller.check();s=controller.STATE;c=s['light'];assert s['on'] and c.intensity==7200 and c.intensity_units==u.LightUnits.LUMENS and c.mobility==u.ComponentMobility.MOVABLE and c.get_editor_property('use_temperature') is False
    assert controller.OWNER in [str(v) for v in s['actor'].tags]
    width,height=(22.,40.) if small else (220.,400.);before=controller.own_light();expected=dict(before,width=width,height=height);c.set_source_width(width);c.set_source_height(height);assert controller.own_light()==expected
    s['own_before']=dict(s['own_before'],width=width,height=height);controller.check();print('OWNED_WINDOW_SOURCE_EXTENT_CM',width,height)
