"""Small local review-gallery refinements; no generated image changes."""
from pathlib import Path
import json

root = Path(__file__).resolve().parent
path = root / 'library.py'
text = path.read_text(encoding='utf-8')
text = text.replace("()=>openImage(visible[(current-1+visible.length)%visible.length].id)", "()=>{if(visible.length)openImage(visible[(current-1+visible.length)%visible.length].id)}")
text = text.replace("()=>openImage(visible[(current+1)%visible.length].id)", "()=>{if(visible.length)openImage(visible[(current+1)%visible.length].id)}")
text = text.replace("shortlist';let selected", "shortlist';let selected")
text = text.replace('providing12 designs', 'providing 12 designs')
text = text.replace('Interpretations must not be mistaken for revised level layouts.', 'These are mood, prop and lighting studies, not metric construction drawings; some shaft views exaggerate depth. Interpretations must not be mistaken for revised level layouts.')
text = text.replace('Royal Daily Feast cast and the dust-creature reference supply the visual anchors.', 'Royal Daily Feast cast and the dust-creature reference supply the visual anchors. The requested floor puffs are explored as the reference image\'s Flour Puff family.')
# Keep the single-quoted Python source string valid after adding a possessive.
text = text.replace("image's Flour", "image\\'s Flour")
path.write_text(text, encoding='utf-8')

plan_path = root / 'plan.json'
plan = json.loads(plan_path.read_text(encoding='utf-8'))
original = """Create a polished landscape 3:2 GAME CONCEPT ART SHEET for MISE EN MONSTRE, concept CB-01 'Apprentice's Margin Doodles'. A cute, very simple stylized cookbook page design, not a realistic old tome. Show TWO LARGE FLAT PARCHMENT PAGES side by side, thin olive book frame and narrow sewn brown centre. Left page is a MONSTER FIELD NOTE about a Pickle Mimic: a chunky green pickle inside an angular jar with a black face and two warm ivory eyes. Four confident black ink strokes per shape, generous blank paper, hand-drawn arrows, a tiny bell doodle for sound, one pasted silhouette sticker, one red '!' stamp. Right page is DISH PREPARATION for Tomb-Truffle Broth: 4 huge pictorial steps using pot, cloche, truffle, brine jar, herb leaf; simple line icons and an ivory-eyed chef mitten drawing. Big dark hand lettering, short readable headings only: 'PICKLE MIMIC', 'LISTEN', 'TOMB-TRUFFLE BROTH', 'SIMMER', 'COVER', 'OFF HEAT', 'BRINE + HERBS'. Use sage green, parchment cream, charcoal ink and one red stamp accent; paper mostly clean flat cream, cut-paper stickers with simple torn silhouettes, playful kitchen notes. Distinct sparse low-detail handwriting instead of dense realistic illustration, no ornate floral border, no photorealism, no microtexture, no tiny paragraphs, no glowing UI or modern glossy panels. Usable at gameplay distance: large 4-step grid, picture-first, strong hierarchy. A small isolated row underneath shows the bell sticker, warning stamp, Q/E torn-paper tabs and one ingredient sticker at their actual design style. Attractive professional art-direction board, crisp graphic shapes and few colors. Tiny top label 'CB-01'."""
next(j for j in plan['jobs'] if j['id'] == 'CB-01')['actual_prompt'] = original
plan_path.write_text(json.dumps(plan, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
(root/'prompts/CB-01.txt').write_text(original, encoding='utf-8')
print('Gallery navigation guards, source limits and exact initial prompt saved.')
