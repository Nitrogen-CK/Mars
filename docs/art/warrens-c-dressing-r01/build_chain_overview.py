"""A six-sheet contact teaser; generated source images are untouched."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parent;OUT=ROOT/'sections/chain-crossing-sluice'
jobs={j['id']:j for j in json.loads((ROOT/'image_jobs.json').read_text())}
canvas=Image.new('RGB',(2000,1530),'#232b24');d=ImageDraw.Draw(canvas)
title=ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf',40)
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',23)
d.text((25,17),'CHAIN CROSSING & SLUICE / THE COMPLETE LOCAL KIT',font=title,fill='#ead9b7')
d.text((25,71),'88 component entries / 23 model sheets / 4 assembly and player views',font=font,fill='#c6bd9f')
selected=[('CS23','Buildable assembly hierarchy'),('CS06','Handwheel, axle, mount and drum'),('CS09','Rising gate: moving leaf and static frame'),('CS12','Local rocks and cavern walls'),('CS14','Flat water surfaces and edge cards'),('CS27','Supports, brace and recessed drain')]
for i,(ident,label) in enumerate(selected):
    x=i%2*1000;y=i//2*455+115
    with Image.open(ROOT/jobs[ident]['image']) as im:
        im=ImageOps.contain(im.convert('RGB'),(975,410));canvas.paste(im,(x+(1000-im.width)//2,y))
    d.text((x+17,y+416),ident+' / '+label,font=font,fill='#e8d6b4')
d.text((25,1495),'Concepts and Blender briefs. Source layout and gameplay contracts remain authoritative.',font=font,fill='#c6bd9f')
canvas.save(OUT/'OVERVIEW.jpg',quality=96)
print('Section overview saved.')
