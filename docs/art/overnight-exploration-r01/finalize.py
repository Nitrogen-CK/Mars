"""Finalize the index and assemble a representative overview after all sheets exist."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parent
plan = json.loads((root/'plan.json').read_text(encoding='utf-8'))
progress = json.loads((root/'progress.json').read_text(encoding='utf-8'))
assert len(progress['completed']) == 108
assert all(v['review'] == 'inspected' for v in progress['completed'].values())
for job in plan['jobs']:
    job['status'] = 'generated-and-inspected'
(root/'plan.json').write_text(json.dumps(plan, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
selected = [('CB-02', 'COOKBOOK / 12 page treatments'),
            ('ENVB-02', 'WARRENS B / 12 paired views'),
            ('ENVC-01', 'WARRENS C / 12 paired views'),
            ('ENVD-06', 'WARRENS D / 12 paired views'),
            ('IN-01', 'INTRO / 12 six-frame openings'),
            ('HUD-04', 'HUD / 12 complete directions'),
            ('MECH-01', 'MECHANISMS / 12 clue treatments'),
            ('MON-01', 'MONSTERS / 12 simple play loops'),
            ('VER-01', 'VERMIN / 12 ideas for each family')]
sheet = Image.new('RGB', (1500, 1260), '#20271f')
draw = ImageDraw.Draw(sheet)
heading = ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf', 38)
label = ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf', 21)
small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 21)
draw.text((22, 16), 'MISE EN MONSTRE / 108 CONCEPT SHEETS', font=heading, fill='#f3e6c7')
draw.text((24, 69), '12 directions in every collection. Full images, briefs and shortlist tools in PREVIEW.html.', font=small, fill='#c5b89c')
for index, (ident, caption) in enumerate(selected):
    x = index%3*500+10
    y = index//3*370+115
    with Image.open(root/'thumbs'/f'{ident}.jpg') as image:
        sheet.paste(image, (x,y))
    draw.text((x+4, y+328), caption, font=label, fill='#efdfb9')
draw.text((24, 1220), 'Exploration only. No live map or gameplay changes.', font=small, fill='#c5b89c')
sheet.save(root/'OVERVIEW.jpg', quality=94)
print('Final plan statuses and representative overview saved.')
