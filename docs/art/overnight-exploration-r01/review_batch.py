"""Create a labelled review contact sheet without changing source images."""
import argparse, json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
root=Path(__file__).resolve().parent
parser=argparse.ArgumentParser();parser.add_argument('name');parser.add_argument('--approve',action='store_true');parser.add_argument('--note',default='Inspected contact sheet: category, composition and style present. Typography and precise metrics remain exploratory.')
parser.add_argument('--ids',help='Comma-separated IDs to review while other images are still generating')
args=parser.parse_args();plan=json.loads((root/'plan.json').read_text(encoding='utf-8'));progress=json.loads((root/'progress.json').read_text(encoding='utf-8'))
folder=root/'qa';folder.mkdir(exist_ok=True)
if args.approve:
    ids=json.loads((folder/(args.name+'.json')).read_text())
    for ident in ids:
        progress['completed'][ident]['review']='inspected'
        progress['quality_notes'][ident]=args.note
    (root/'progress.json').write_text(json.dumps(progress,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
else:
    selected=set(args.ids.split(',')) if args.ids else None
    jobs=[j for j in plan['jobs'] if j['id'] in progress['completed'] and progress['completed'][j['id']]['review']=='pending' and (selected is None or j['id'] in selected)]
    assert jobs,'No unreviewed images'
    sheet=Image.new('RGB',(1500,((len(jobs)+2)//3)*355),'#22271f');draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',20)
    for i,job in enumerate(jobs):
        x=i%3*500+10;y=i//3*355
        sheet.paste(Image.open(root/'thumbs'/(job['id']+'.jpg')),(x,y))
        draw.text((x,y+322),job['id']+' '+job['title'][:35],font=font,fill='#f1e4c7')
    sheet.save(folder/(args.name+'.jpg'),quality=93)
    (folder/(args.name+'.json')).write_text(json.dumps([j['id'] for j in jobs]))
print(args.name,'approved' if args.approve else 'created')
