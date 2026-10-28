"""Read binary FBX properties directly; no scene/source modifications."""
import os,json
from io_scene_fbx import parse_fbx
OUT=os.path.dirname(os.path.abspath(__file__))
def child(node,name): return next((e for e in node.elems if e.id==name),None)
def properties(node):
 p=child(node,b'Properties70')
 return {e.props[0].decode():list(e.props[4:]) for e in p.elems if e.id==b'P'} if p else {}
report={}
for file in sorted(os.listdir(os.path.join(OUT,'FBX'))):
 if not file.endswith('.fbx'): continue
 root,version=parse_fbx.parse(os.path.join(OUT,'FBX',file))
 objects=child(root,b'Objects'); connections=child(root,b'Connections')
 models={int(o.props[0]):o for o in objects.elems if o.id==b'Model'}
 names={ident:node.props[1].split(b'\x00')[0].decode() for ident,node in models.items()}
 masterid=next(i for i,n in names.items() if n=='Master'); armid=next(i for i,n in names.items() if n=='Armature')
 entry={'unit_scale_factor':properties(child(root,b'GlobalSettings'))['UnitScaleFactor'],'models':{names[i]:properties(models[i]) for i in [masterid,armid]}}
 scale_nodes=[int(c.props[1]) for c in connections.elems if len(c.props)>3 and c.props[0]==b'OP' and int(c.props[2])==masterid and c.props[3]==b'Lcl Scaling']
 curves=[]
 for scaleid in scale_nodes:
  ids=[int(c.props[1]) for c in connections.elems if len(c.props)>3 and int(c.props[2])==scaleid]
  for ident in ids:
   curve=next(o for o in objects.elems if int(o.props[0])==ident); values=child(curve,b'KeyValueFloat')
   if values: curves.extend(float(v) for v in values.props[0])
 entry['master_animation_scale_values_range']=[min(curves),max(curves)] if curves else None
 entry['checks']={'cm_metadata':entry['unit_scale_factor']==[1.0], 'master_rest_scale1':entry['models']['Master'].get('Lcl Scaling',[1.,1.,1.])==[1.,1.,1.], 'dummy_rest_scale1':entry['models']['Armature'].get('Lcl Scaling',[1.,1.,1.])==[1.,1.,1.], 'animated_master_scale1':not curves or all(abs(v-1)<1e-6 for v in curves)}
 report[file]=entry
json.dump(report,open(os.path.join(OUT,'fbx_binary_units.json'),'w'),indent=2,default=lambda value:value.decode() if isinstance(value,bytes) else list(value))
print('BINARY_FBX_UNIT_CHECKS '+json.dumps({f:e['checks'] for f,e in report.items()}))
assert all(all(e['checks'].values()) for e in report.values())
