__file__='D:/Repositories/CkRepos/Orion/Tools/SpireConnectorKit/validate_blender.py'
exec(open('Tools/SpireConnectorKit/validate_blender.py').read().replace("if errors:raise RuntimeError('Blender audit failed')",''))
c=spec['concepts'][3]
for b in c['supports']['floor_bore_placements']:
 if b['id'] not in ['HL-BORE-11','HL-BORE-15']:continue
 a=next(a for a in c['areas'] if a['id']==b['landing']);o=objects[next(p['asset'] for p in data['assemblies']['HL'] if p.get('source_id')==a['id'])];angle=math.radians(b['angle_unwrapped_deg']-a['angle_center_unwrapped_deg']);hit,pos,n,idx=cast(o,Vector((5.3*math.cos(angle),-5.3*math.sin(angle),.1)),Vector((0,0,-1)),.7);print('BORE_HIT',b['id'],tuple(pos),idx)

