from PIL import Image,ImageOps,ImageDraw,ImageFont
from pathlib import Path
out=Path(__file__).resolve().parent
shots=[('01-closed','CLOSED / raised pot, patch, sewn spine'),('02-open','OPEN / widget-ready page UVs'),('03-rear','REAR / repair patch and corner guards'),('04-side','PROFILE / slim physical page block'),('05-page-turn','TURN / eight-bone flexible leaf'),('08-opening','OPENING / real cover hinge')]
sheet=Image.new('RGB',(2400,1460),'#302c24'); d=ImageDraw.Draw(sheet)
try: font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',22)
except OSError: font=ImageFont.load_default()
for i,(f,label) in enumerate(shots):
 x=(i%3)*800; y=(i//3)*730
 im=Image.open(out/'Renders'/f'{f}.png').convert('RGB'); im=ImageOps.contain(im,(790,680))
 sheet.paste(im,(x+(800-im.width)//2,y+(680-im.height)//2))
 d.text((x+20,y+690),label,font=font,fill='#ead7af')
sheet.save(out/'Renders'/'ContactSheet.png')
print(out/'Renders'/'ContactSheet.png')
