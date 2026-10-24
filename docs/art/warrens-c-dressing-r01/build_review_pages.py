"""Contact sheets for visual review, with originals preserved unmodified."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont,ImageOps
ROOT=Path(__file__).resolve().parent
jobs=json.loads((ROOT/'image_jobs.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',23)
items=[j for j in jobs if j['type']!='painted' and (ROOT/j['image']).is_file() and (j['id'].startswith(('CS','DRESS')) or int(j['id'][5:])>=29)]
folder=ROOT/'qa/review-pages';folder.mkdir(exist_ok=True)
pages=[]
for start in range(0,len(items),4):
    group=items[start:start+4]
    image=Image.new('RGB',(2000,1420),'#232b24');d=ImageDraw.Draw(image)
    for i,j in enumerate(group):
        x=i%2*1000;y=i//2*710
        with Image.open(ROOT/j['image']) as im:
            im=ImageOps.contain(im.convert('RGB'),(980,653));image.paste(im,(x+10,y+10))
        d.text((x+15,y+667),j['id']+' / '+j['title'],fill='#eddcbc',font=font)
    path=folder/f'review-{start//4+1:02}.jpg';image.save(path,quality=96)
    pages.append({'image':str(path),'ids':[j['id'] for j in group]})
(folder/'index.json').write_text(json.dumps(pages,indent=2)+'\n')
print(json.dumps(pages))
