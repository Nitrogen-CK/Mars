from pathlib import Path
import json
ROOT=Path(__file__).resolve().parent
jobs=json.loads((ROOT/'image_jobs.json').read_text())
j=next(j for j in jobs if j['id']=='CS06')
prompt='''Use case: precise-object-edit. Edit target is the attached CS06 HandwheelPedestalAndDrum production sheet. Correct ONE modeling contract: CCS21 handwheel is a small 50cm-diameter BLACK IRON rim-and-spoke wheel, not the oversized wooden ship wheel shown. In every assembled view, keep the small chef approximately120cm in world height and make the wheel diameter clearly less than half that height, about50cm. Keep wheel center aligned to the existing straight axle, mount and drum; it must still reach the existing axle. In the isolated wheel views change its material from timber to matte charcoal iron; retain thick simple low-poly spokes. Existing straight axle, static pedestal, chain drum, their separation, neutral background, simple flat-shaded style, CCS IDs and front/side/exploded views stay unchanged. Remove any wooden rim appearance. Use one short accurate label beside CCS21: "50 cm diameter". Do not add gears or additional controls. Save a corrected full landscape sheet.'''
j['image']='sections/chain-crossing-sluice/art/CS06-r02.png'
j['edit_prompt']='prompts/CS06_r02-edit.txt'
j['revision_reference']='sections/chain-crossing-sluice/art/CS06.png'
(ROOT/'prompts/CS06_r02-edit.txt').write_text(prompt+'\n')
(ROOT/'image_jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
print('CS06 corrected revision selected; original retained.')
