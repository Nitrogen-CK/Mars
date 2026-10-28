"""Build the current wheel-art evidence sheet from hashed real-pawn captures."""
import hashlib
import html
import json
from pathlib import Path

REVIEW = Path(__file__).resolve().parents[2] / 'docs/art/warrens-c-gameplay-review-20261024'


def figure(stem, label):
    image = REVIEW / (stem + '.png')
    record = json.loads(image.with_suffix('.json').read_text(encoding='utf-8'))
    assert hashlib.sha256(image.read_bytes()).hexdigest() == record['image_sha256']
    intensity = record.get('actual_held_light', {}).get('intensity')
    light = f'Actual held intensity {intensity:.0f}.' if intensity is not None else 'Empty hands; saved practicals.'
    return (f'<figure><a href="{stem}.png"><img loading="lazy" src="{stem}.png" alt="{html.escape(label)}"></a>'
            f'<figcaption>{html.escape(label)} · FOV{record["fov"]:.0f}. {light} '
            f'<a href="{stem}.json">Capture record</a></figcaption></figure>')


def pair(title, left, right, explanation):
    return (f'<section><h2>{html.escape(title)}</h2><p>{html.escape(explanation)}</p><div class="pair">'
            + figure(*left) + figure(*right) + '</div></section>')


def main():
    sections = [pair('Fresh saved-source candidate',
        ('ART_held_wheel_final_front', 'Final source-bound wheel: unfocused front'),
        ('ART_held_wheel_final_oblique', 'Final source-bound wheel: oblique'),
        'Existing CCS21 spoke wheel, local axial offset +2.5 cm, yaw +90°, unit scale and existing TX09. '
        'The sole Canal spawner opts in; mover, probe, collision, mount, drive and lights are unchanged. '
        'These are isolated real-pawn views, not a walked approach or novice-comprehension result.')]
    sections.append(pair('One-axis fit comparison',
        ('ART_held_wheel_fit_before_oblique', 'Before: wheel overlaps the shaft end'),
        ('ART_held_wheel_fit_offset_oblique', 'After: rear face meets the shaft end'),
        'Only wheel visual translation changes. Grid material retained. Actual lantern fuel falls between captures; '
        'this compares the joint and silhouette, not identical-light material brightness.'))
    sections.append(pair('One-axis material comparison',
        ('ART_held_wheel_fit_offset_front', 'Offset spoke wheel: diagnostic grid'),
        ('ART_held_wheel_fit_tx09_front', 'Same offset spoke wheel: TX09 iron'),
        'Only the wheel material changes. All five spokes remain visible without focus highlighting. '
        'TX09 is accepted for the observed held-light conditions; painterly texture finish remains separate.'))
    sections.append(pair('Source-bound offset at separated input-driven poses',
        ('ART_observe_wheel_offset_input180_oblique', 'Partial pose: oblique joint'),
        ('ART_observe_wheel_offset_input360_front', 'Later partial pose: front silhouette'),
        'Actual Use/look/release/regrip generated five distinct sampled orientations with a fixed hub center; '
        'the span seated and both guards opened. Capture labels describe input deltas, not measured wheel degrees. '
        'Discrete observations do not establish continuous all-angle clearance.'))
    sections.append(pair('Historical silhouette comparison',
        ('ART_held_wheel_front_grid_unfocused', 'Legacy solid-looking disc'),
        ('ART_held_wheel_front_spokes_grid_unfocused', 'Existing reusable CCS21 spoke wheel'),
        'Original grid material retained for this mesh-only comparison. These older transient trials precede '
        'the source-bound fit and material work above.'))
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>P2 wheel: fit, silhouette and source-bound art</title><style>
body{margin:0;background:#142025;color:#ede7d7;font:17px/1.5 system-ui}main{max-width:1500px;margin:auto;padding:28px}
h1,h2{font-family:Georgia,serif;font-weight:400}a{color:#edc47e}section{border-top:1px solid #3f535a;padding:22px 0}
.pair{display:grid;grid-template-columns:1fr 1fr;gap:18px}figure{margin:0}img{width:100%;display:block}
figcaption{font-size:13px;color:#b6c6c8;padding-top:8px}@media(max-width:850px){.pair{grid-template-columns:1fr}}</style><main>
<p><a href="final-room-plates/index.html">24 room references</a> · <a href="PROGRESS.md">Current state</a></p>
<h1>P2: a readable wheel on the existing extending span</h1>
<p>Local art validation is separate from remote control-to-span comprehension, final pacing, packaged collision and co-op.
Nothing is committed or pushed. The full source-bound retention verdict is recorded in the linked review.</p>
<p><a href="P2_WHEEL_STAGED_BINDING_REVIEW.md">Astra review and exact acceptance boundary</a> ·
<a href="P2_WHEEL_FINAL_IDENTITY.json">Fresh runtime identity</a> · <a href="P2_WHEEL_OFFSET_MOTION.json">Offset operation</a> ·
<a href="P2_WHEEL_BUILD_TEST.json">Focused build/test: 3/3 baseline → 3/3</a></p>'''
    page += ''.join(sections)
    page += ('<section><h2>Rejected brass trial</h2><p>TX10 on the prototype wheel and passive drive made a flat hotspot '
             'and darkened the drive. All six slots were restored. No shared material or lighting change followed.</p>'
             '<a href="ART_observe_sluice_brass.png">Preserved rejected frame</a></section></main></html>')
    (REVIEW / 'P2_WHEEL_PREVIEW.html').write_text(page, encoding='utf-8')
    print('WHEEL_SHEET_BUILT', len(sections), 'pairs; all capture hashes verified')


if __name__ == '__main__':
    main()
