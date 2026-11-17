"""Create the isolated R03 source revision from the retained R02 authoring pipeline."""
from pathlib import Path
import hashlib, json, shutil
root=Path(__file__).resolve().parent
old=root.parent/'StylizedR02'
model=root/'Model'; model.mkdir(exist_ok=True)
files=['build_stylized.py','export_centimetres.py','validate_and_roundtrip.py',
       'check_gutter.py','export_closed_proxy.py','export_morph_curves.py',
       'inspect_fbx_units.py','make_contact_sheet.py']
for name in files:
    source=(old/'Model'/name).read_text()
    source=source.replace('StylizedR02','StylizedR03')
    (model/name).write_text(source)
for name in ['import_unreal.py','import_closed_proxy.py','apply_morph_curves.py','gameplay_probe.py']:
    (root/name).write_text((old/name).read_text().replace('StylizedR02','StylizedR03'))
textures=root/'Textures'; textures.mkdir(exist_ok=True)
for name in ['PageLeft.png','PageRight.png']:
    shutil.copy2(old/'Textures'/name,textures/name)
f=model/'build_stylized.py'; s=f.read_text()
def replace_once(old,new):
    global s
    assert s.count(old)==1,(old,s.count(old))
    s=s.replace(old,new)
replace_once('HINGE_Z=.014; SURFACE_Z=.013; TURN_Z=.0148; BOARD_T=.003',
             'HINGE_Z=.021; SURFACE_Z=.0195; TURN_Z=.02195; BOARD_T=.006')
# Non-reading geometry was authored at R02's old Z coordinates. Apply the
# thickness map before bevels/join/shape keys; page planes and turn leaf use
# their new coupled constants directly and must not be transformed twice.
replace_once("def objmesh(name,verts,faces,mat='Cover',group='Cover_L',uvs=None):",
"""def objmesh(name,verts,faces,mat='Cover',group='Cover_L',uvs=None):
 if name in ['Rounded leather spine','Raised spine binding','Saddle stitch']:
  # A closed thick folio needs a binding spanning the new cover depth.
  verts=[(x,y,HINGE_Z+(z-.011)*(.0322/.013)*.32-.00628/.68) for x,y,z in verts]
 elif name not in ['Turning leaf','Left widget page','Right widget page']:
  verts=[(x,y,z*(2.0 if z<0 else 1.5)) for x,y,z in verts]""")
replace_once('def rounded_rect(x0,x1,y0,y1,r=.007):',
             'def rounded_rect(x0,x1,y0,y1,r=.014):')
replace_once("-.003,0,'Cover',g,.0013)","-.003,0,'Cover',g,.0026)")
replace_once('for i in range(9):\n  z=.0017+i*.00114;',
             'for i in range(5):\n  z=.0017+i*.00228;')
replace_once('z=SURFACE_Z-.0011*math.exp(-u*14)',
             'z=SURFACE_Z-.00165*math.exp(-u*14)')
replace_once("TURN_Z+(1 if layer==0 else -1)*.00015",
             "TURN_Z+(1 if layer==0 else -1)*.00045")
replace_once("'open_turning_leaf_gap':(TURN_Z-.00015-SURFACE_Z)",
             "'open_turning_leaf_gap':(TURN_Z-.00045-SURFACE_Z)")
# Retain the exact R02 width/height, BC slots, morph driver contract and
# spine-centred turn root compensation. Do not scale the whole item.
s=s.replace("  poly=[(outer,yy),(inner,yy),(inner+side*.005,yy-ysign*.012),(outer-side*.014,yy-ysign*.016),(outer-side*.014,yy-ysign*.034),(outer,yy-ysign*.034)]",
"""  # Rounded L guard follows the board's doubled plan-view corner radius.
  corner=[(.034,0),(.014,0)]
  corner += [(.014+.014*cos(math.radians(a)),.014+.014*sin(math.radians(a))) for a in [-105,-120,-135,-150,-165,-180]]
  corner += [(0,.034),(.013,.034),(.013,.023),(.023,.013),(.034,.013)]
  poly=[(outer-side*u,yy-ysign*v) for u,v in corner]""")
s=s.replace("  poly2=[(outer-side*.003,yy-ysign*.003),(inner+side*.007,yy-ysign*.003),(outer-side*.005,yy-ysign*.015)]",
"  poly2=[(outer-side*.007,yy-ysign*.007),(inner+side*.007,yy-ysign*.003),(outer-side*.006,yy-ysign*.017)]")
s=s.replace(" for b in arm.pose.bones: b.rotation_euler=(0,0,0); b.location=(0,0,0); b.scale=(1,1,1)"," for b in arm.pose.bones: b.rotation_euler=(0,0,0); b.location=(0,0,0); b.scale=(1,1,1)\n spine=arm.pose.bones['Spine']\n spine.scale.z=3.125-2.125*openness\n spine.location.z=.019625*(1.0-openness)")
s=s.replace("  for b in arm.pose.bones: b.keyframe_insert('rotation_euler',frame=f,group=b.name)","  for b in arm.pose.bones: b.keyframe_insert('rotation_euler',frame=f,group=b.name)\n  arm.pose.bones['Spine'].keyframe_insert('scale',frame=f,group='Spine')\n  arm.pose.bones['Spine'].keyframe_insert('location',frame=f,group='Spine')")
f.write_text(s)
# Pages remain the existing content. Reference existing page textures while
# generating independent R03 geometry/material/animation assets.
u=root/'import_unreal.py'; t=u.read_text()
t=t.replace("texture = unreal.load_asset(DEST + '/Textures/Cookbook_Sample_' + page_side[name] + '_T')",
            "texture = unreal.load_asset('/Game/Mars/Gameplay/PlayerCookbook/StylizedR02/Textures/Cookbook_Sample_' + page_side[name] + '_T')")
u.write_text(t)
report={'source':'StylizedR02','revision':'StylizedR03','targets':{'cover_thickness':2,'corner_radius':2,'page_stack_depth':1.5,'leaf_rim':3.0},'reading_footprint_cm':[17,23],
        'retained':['20 material slots, first eight stable','12 bone names','four morph names','six clip names','page UVs','spine-centred turn compensation','existing page content'],
        'source_sha256':{name:hashlib.sha256((old/'Model'/name).read_bytes()).hexdigest() for name in files}}
(root/'source_revision.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

