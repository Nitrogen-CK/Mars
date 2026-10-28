from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
out=Path(__file__).resolve().parent
frames=[]
try: font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
except OSError: font=ImageFont.load_default()
for file in sorted((out/'MotionFrames').glob('*.png')):
 im=Image.open(file).convert('RGB'); d=ImageDraw.Draw(im)
 i=int(file.stem)
 title='CLOSED' if i<3 or i>=63 else 'OPENING' if i<15 else 'PAGE TURN / RIGHT TO LEFT' if i<33 else 'PAGE TURN / LEFT TO RIGHT' if i<51 else 'CLOSING'
 d.rectangle((0,518,700,550),fill='#302c24'); d.text((16,525),title,font=font,fill='#ead7af'); frames.append(im)
frames[0].save(out/'Renders'/'CookbookMotion.gif',save_all=True,append_images=frames[1:],duration=90,loop=0,optimize=True)
print('GIF_COMPLETE frames=%d'%len(frames))
