"""Read final saved Blender actions and sample evaluated morph values.

Does not modify/save the source blend or FBX files. Run on Cookbook_StylizedR02.blend.
"""
import bpy, json, os, math

OUT=os.path.dirname(os.path.abspath(__file__))
arm=bpy.data.objects['Cookbook_Slim_Armature']
mesh=bpy.data.objects['SK_Cookbook_StylizedR02']
scene=bpy.context.scene
names=['PageBend_%02d'%i for i in range(1,5)]
report={'source_blend':bpy.data.filepath,'fps':60,'time_origin':'(source_frame - 1) / 60','sample_source':'evaluated mesh shape_keys.key_blocks[name].value after frame_set and depsgraph update; values include Blender driver/clamp evaluation','actions':{}}
for track in arm.animation_data.nla_tracks: track.mute=True
for action in sorted(bpy.data.actions,key=lambda a:a.name):
 if not action.name.startswith('Book_'): continue
 arm.animation_data.action=action; arm.animation_data.action_slot=action.slots[0]
 first,last=map(int,action.frame_range)
 data={'source_frame_start':first,'source_frame_end':last,'frames':[],'times':[],'curves':{n:[] for n in names},'ranges':{},'crosscheck':{}}
 for frame in range(first,last+1):
  scene.frame_set(frame); bpy.context.view_layer.update()
  dg=bpy.context.evaluated_depsgraph_get(); dg.update()
  evaluated=mesh.evaluated_get(dg)
  data['frames'].append(frame); data['times'].append((frame-1)/60)
  for name in names:
   value=float(evaluated.data.shape_keys.key_blocks[name].value)
   if not math.isfinite(value): raise ValueError('Nonfinite morph value: '+action.name+' '+name)
   data['curves'][name].append(value)
 for name,values in data['curves'].items():
  data['ranges'][name]={'min':min(values),'max':max(values),'nonzero_samples':sum(abs(v)>1e-8 for v in values)}
 # The underlying data-key's driven values should agree with evaluated values.
 data['crosscheck']['evaluated_vs_original_keys_at_last_frame']={name:abs(data['curves'][name][-1]-float(mesh.data.shape_keys.key_blocks[name].value)) for name in names}
 report['actions'][action.name]=data
path=os.path.join(OUT,'morph_curves.json')
with open(path,'w') as stream: json.dump(report,stream,indent=2)
print('MORPH_CURVES_EXPORTED '+path)
for name,data in report['actions'].items(): print(name+' '+json.dumps(data['ranges']))
assert len(report['actions'])==6
assert max(report['actions']['Book_Lying_Open_Page_Turn_R_to_L_02']['curves']['PageBend_01'])>0
