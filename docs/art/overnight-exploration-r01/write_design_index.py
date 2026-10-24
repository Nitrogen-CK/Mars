"""Readable index of the design alternatives already defined in plan.json."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
plan = json.loads((root/'plan.json').read_text(encoding='utf-8'))
categories = list(dict.fromkeys(j['category'] for j in plan['jobs']))
lines = ['# Concept directions and play proposals', '',
    'Every numbered entry is a separate visual direction. Open PREVIEW.html for images and shortlist comparisons. These are concepts, not approved lore, recipes or implemented mechanics.', '',
    '## Shared direction', '',
    'Chunky low-poly forms, faceless ivory-eyed cooks, flat matte colors, amber light against teal darkness. Cookbook and HUD graphics use large paper shapes, simple ink marks and sparse words. Silhouette and information hierarchy take priority over texture.', '',
    'The environment studies interpret the attached B/C/D layout document. They are not metric reconstruction drawings. B descends around one shaft; C separates the Well and Belfry across a canal; D uses distinct room shapes on two loops around the Well. Light should help recognize a return landmark without revealing every destination.', '',
    'The Royal Daily Feast cast anchors each intro. New incidents are alternative opening pitches. Monster loops propose one readable trigger, response and counter. Vermin roles are optional: they never consume required keys or ingredients or gate progress.', '',
    'HUD studies use one active dish, four party portraits and distinct voice states. World interaction is LMB; Q/E are cookbook previous/next; LMB also closes an open book; R is the held-item throw hint. Icons should communicate state without relying only on color.', '',
    'The requested floor puffs are explored as the attached reference\'s Flour Puff family. Each of the twelve vermin sheets includes Pantry Rat, Sootling, Flour Puff and Lint Scuttler, with different silhouettes and behavior ideas.', '']
for category in categories:
    lines += ['## '+category, '']
    for job in [j for j in plan['jobs'] if j['category'] == category]:
        lines += [f"### {job['id']} — {job['title']}", '', job['brief'], '',
                  job['notes'], '', f"[Full image]({job['image']}) · [Exact generation prompt](prompts/{job['id']}.txt)", '']
(root/'DESIGN_INDEX.md').write_text('\n'.join(lines), encoding='utf-8')
library = root/'library.py'
text = library.read_text(encoding='utf-8')
text = text.replace('<a href="plan.json">All prompts and design briefs</a>', '<a href="DESIGN_INDEX.md">Readable design briefs</a> · <a href="plan.json">All prompts</a>')
text = text.replace('<p class="notes">${escape(d.notes)}</p><div class="actions">', '<p class="notes">${escape(d.notes)}</p><details><summary>Design brief</summary><p>${escape(d.brief)}</p></details><div class="actions">')
library.write_text(text, encoding='utf-8')
print('Design index saved; gallery exposes full design briefs.')
