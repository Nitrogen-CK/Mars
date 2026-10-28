"""Publish actual R11 comparison evidence, keeping the failed capture explicit."""
import copy
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT/'docs/art/warrens-c-gameplay-review-20261024'
OUT = DOC/'lookdev/larder-complete-room-r01/native-high-roof-r11'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def normalized(record):
    result = copy.deepcopy(record)
    result.pop('view')
    result['high_roof_state'].pop('visible')
    roof = result['art_state'][-1]
    assert 'HighRoof' in roof['mesh']
    roof.pop('visible')
    roof.pop('hidden')
    roof['lighting_flags'].pop('visible')
    roof['lighting_flags'].pop('hidden_in_game')
    return result


def main():
    pairs = [('roof_window_A', 'roof_window_B'), ('direct_roof_A', 'direct_roof_B'), ('low_ceiling_A', 'low_ceiling_B'), ('roof_window_B_repeat', 'roof_window_A_return_valid'), ('roof_window_A_return_valid', 'roof_window_B_return_valid')]
    records = []
    for a, b in pairs:
        left, right = [json.loads((OUT/(name+'.json')).read_text()) for name in (a, b)]
        assert normalized(left) == normalized(right), (a, b)
        assert left['high_roof_state']['visible'] != right['high_roof_state']['visible']
        for name in (a, b):
            with Image.open(OUT/(name+'.png')) as picture:
                picture.load()
                assert picture.size == (1600, 1000)
        records.append(dict(a=a, b=b, metadata_equal_except_roof_visibility_and_view=True, a_png_sha256=sha(OUT/(a+'.png')), b_png_sha256=sha(OUT/(b+'.png'))))
    restoration = ROOT/'Saved/WarrensCGameplay-20261024/LarderRollout/finish_room_trial_r07/restored.json'
    cleanup = json.loads(restoration.read_text())
    assert cleanup['status'] == 'LATER_TURN_OWNED_ACTOR_ABSENCE_ORIGINAL_HISMS_AND_FIVE_LIGHTS_EXACT'
    assert len(cleanup['removed']) == 8 and cleanup['hisms'] == 383 and cleanup['instances'] == 45452
    result = dict(status='VALID_NATIVE_ROOF_COMPARISONS_COMPLETE_FINISH_HELD_FOR_CONTEXT', comparisons=records, rejected_capture=dict(file='roof_window_C.png', reason='Camera advanced in same RPC after queued screenshot request. Image does not match sidecar. Replaced by separate-RPC decoded B/A/B.'), restoration_sha256=sha(restoration), source_geometry_restored=True, boundary='Real Main PIE with normal bag/lantern use. Paused teleported appearance only. Roof candidate covers admitted source-supported shell; pale shared connector/niche context remains unfinished. No whole-room acceptance, native source/library save, physical traversal, pacing, multiplayer or packaged proof.')
    (OUT/'native_roof_comparisons_r01.json').write_text(json.dumps(result, indent=2)+'\n')
    html = ['<!doctype html><meta charset="utf-8"><title>Larder roof and shared context</title><style>body{background:#17191d;color:#eee;font:16px system-ui;margin:24px}section{display:grid;grid-template-columns:1fr 1fr;gap:14px}img{width:100%}figure{margin:10px 0}p{max-width:1000px}a{color:#edc47b}</style><h1>Larder roof — native comparison</h1><p>Continuing candidate. Complete-room acceptance is held for pale shared connector/niche surfaces. The actual bell remains visible. These images use the real carried lantern; no source packages or libraries were changed.</p>']
    for a, b in pairs[:3]:
        html.append('<section>'+''.join('<figure><figcaption>'+name+'</figcaption><img src="'+name+'.png"></figure>' for name in (a, b))+'</section>')
    html.append('<h2>Complete working finishes</h2><section>'+''.join('<figure><figcaption>'+name+'</figcaption><img src="'+name+'.png"></figure>' for name in ('complete_storage', 'complete_barrel_aisle'))+'</section><p>Rejected: roof_window_C.png mismatches its camera metadata. Valid replacement B/A/B and exact comparison records are in <a href="native_roof_comparisons_r01.json">the evidence receipt</a>. All eight temporary actors were removed; original 383 HISM components / 45,452 instances and five original lights restored exactly.</p>')
    (OUT/'PREVIEW.html').write_text('\n'.join(html), encoding='utf-8')
    print('NATIVE_ROOF_PACKAGE', len(records), 'matched pairs; cleanup exact; whole-room held')


if __name__ == '__main__':
    main()
