"""Build a local evidence preview from the latest owned Catacomb material artifacts."""
import hashlib,json
from pathlib import Path
from html import escape
ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-shape-pbr-r03'
def read(p):return json.loads(p.read_text())
def main():
    native=DOC/'native-trial-r09'
    frames=list(native.glob('PBR_SavedCompleteRoom_*.png')) if native.exists() else []
    status='Astra accepted the R09 stone envelope and static props. Complete room held for forage art'
    def card(src,label):
        path=(DOC/src).resolve();assert path.is_file(),path
        return f'<figure><a href="{escape(src)}"><img loading="lazy" src="{escape(src)}" alt="{escape(label)}"></a><figcaption>{escape(label)}</figcaption></figure>'
    gallery=''.join(card('native-trial-r09/'+p.name,p.stem.replace('PBR_SavedCompleteRoom_','Saved candidate material in PIE — ')) for p in frames)
    if not gallery:
        gallery=''.join(card('grouped-pigment-r08b/'+n,l) for n,l in [('Neutral_standing.png','Offline neutral-light shape test'),('Warm_standing.png','Offline local warm-light shape test'),('Warm_tomb.png','Offline tomb detail')])
    maps=''.join(card(n,l) for n,l in [('../catacomb-reference-match-r02/Stone_AngularPigment_Albedo_r02.png','Albedo — retained layered angular pigment; sparse R08 spots rejected'),('Stone_BroadPlanes_NormalDX_R03.png','NormalDX — actual shallow-geometry bake; linear data'),('Stone_BroadPlanes_Roughness_R03.png','Roughness — independent dry-stone finish; linear data')])
    ref=card('../catacomb-reference-match-r01/USER_REFERENCE.png','User style reference')
    review=(DOC/'NATIVE_R09_ENVELOPE_AND_FORAGE_REVIEW.md')
    review_html='<p><a href="NATIVE_R09_ENVELOPE_AND_FORAGE_REVIEW.md">Astra native result review and remaining forage requirements</a></p>' if review.exists() else ''
    html=f'''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Catacomb — shape and PBR pilot</title>
<style>body{{margin:0;background:#151410;color:#eee7d5;font:16px/1.5 system-ui}}main{{max-width:1320px;margin:auto;padding:28px}}h1{{font-size:30px;margin:0}}p{{max-width:950px}}a{{color:#e9bc69}}.status{{padding:12px 16px;border-left:4px solid #d8a44b;background:#272217}}.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(310px,1fr));gap:18px}}figure{{margin:0;background:#211f19}}img{{width:100%;display:block}}figcaption{{padding:10px 12px;color:#cfc4aa}}details{{margin:20px 0}}code{{color:#e4c488}}.wide img{{max-height:700px;object-fit:contain}}hr{{border:0;border-top:1px solid #514935;margin:30px 0}}</style>
<main><h1>Catacomb · shape and PBR pilot</h1><p class="status">{escape(status)}. Source persistence and remaining-room rollout stay on hold until actual room review.</p>
<p>R09 retains the layered angular albedo. The sparse polygon experiment was rejected after an actual native comparison. Newly generated normals come from shallow stone geometry; roughness is authored separately at 0.82–0.92. Paint colour is not used as a height or roughness estimate. The normal and roughness response is restrained.</p>
{review_html}<div class="grid">{gallery}</div><hr><h2>Material assets</h2><div class="grid">{maps}</div>
<p><a href="PBR_BAKE_RECEIPT.json">Physical-map bake receipt</a> · <a href="NATIVE_R08_ALBEDO_COMPARISON.md">Why the sparse albedo was rejected</a> · <a href="NATIVE_PBR_TRIAL_GATE_R09.json">Exact native trial boundary</a></p>
<h2>Reference</h2><div class="wide">{ref}</div>
<details><summary>Repeat and grazing-light checks</summary><div class="grid">{card('periodic-data-repeat-r02/NormalAndRoughness_2x2_Grazing.png','2×2 physical data maps with albedo disconnected')}</div></details>
<p>Blender previews use an earlier local-light rig. Native captures, when present, use the actual packed pawn, real lantern and saved owned materials; isolated viewing positions do not prove expedition duration or co-op. No source map or library adoption is implied by this page.</p>
<p>Physical geometry and finish controls: <code>Tools/WarrensVariantCKit/bake_catacomb_stone_pbr.py</code>. Native R09 family strengths: <code>catacomb_r02_pbr_successor.py</code>. No source level or library save has occurred. The original level and the remaining rooms are unchanged.</p></main></html>'''
    (DOC/'PREVIEW.html').write_text(html,encoding='utf-8')
    print('PREVIEW_LINK_TARGETS_EXIST',len(frames),'native final frames',hashlib.sha256(html.encode()).hexdigest())
if __name__=='__main__':main()
