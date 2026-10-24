from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parent
jobs=json.loads((ROOT/'image_jobs.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
for kind in ['painted','model-sheet','dressing-sheet']:
    items=[j for j in jobs if j['type']==kind];cols=3 if kind=='painted' else 2
    sheet=Image.new('RGB',(cols*500,((len(items)+cols-1)//cols)*355),'#283027');draw=ImageDraw.Draw(sheet)
    for i,j in enumerate(items):
        x=i%cols*500+10;y=i//cols*355
        sheet.paste(Image.open(ROOT/'qa'/(j['id']+'.jpg')),(x,y));draw.text((x,y+322),j['id']+' '+j['title'],font=font,fill='#efdfbb')
    sheet.save(ROOT/'qa'/(kind+'-contact.jpg'),quality=94)
sheet=Image.new('RGB',(1600,1200),'#20291f');draw=ImageDraw.Draw(sheet)
big=ImageFont.truetype('C:/Windows/Fonts/georgiab.ttf',37);draw.text((22,18),'WARRENS C / BLENDER DRESSING PACK',font=big,fill='#f1e0bc')
rows=[('qa/NEUTRAL_MATERIALS.png','19 surface families / 35 material assets'),
      ('art/model-sheets/MODEL16_LargeRockSilhouettes.png','150 prop briefs / rocks and architecture'),
      ('art/model-sheets/MODEL06_SaltMillCuringStation.png','38 modeling sheets / 11 district assemblies'),
      ('qa/painted-contact.jpg','6 painted emblems / 20 vector icons')]
for i,(path,label) in enumerate(rows):
    x=i%2*800+10;y=i//2*540+85
    with Image.open(ROOT/path) as image:
        image=ImageOps.contain(image.convert('RGB'),(780,490));sheet.paste(image,(x+(780-image.width)//2,y+(490-image.height)//2))
    draw.text((x+8,y+496),label,font=font,fill='#efdfbb')
draw.text((22,1170),'Material maps, packed Blender library, per-tile dressing and a 24-entry first batch. Live level unchanged.',font=font,fill='#bdb799')
sheet.save(ROOT/'OVERVIEW.jpg',quality=94)
print('Current art contacts and overview saved.')
