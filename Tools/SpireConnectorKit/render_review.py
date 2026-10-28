import sys,argparse
from pathlib import Path
import bpy
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from scenes import render_scene
p=argparse.ArgumentParser();p.add_argument('--scene',default='Diorama');p.add_argument('--samples',type=int,default=12);a=p.parse_args(sys.argv[sys.argv.index('--')+1:])
s=bpy.data.scenes['Spire_'+a.scene];s.cycles.samples=a.samples;render_scene(s,a.scene)
print('SPIRE_RENDER_COMPLETE',s.render.filepath,flush=True)
