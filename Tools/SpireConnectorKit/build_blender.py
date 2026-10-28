"""Procedural Blender assets, linked scenes and FBX manifest. Run with Blender."""
import argparse,sys,json,math,hashlib
from pathlib import Path
import bpy
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[1];OUT=HERE/'Output'
sys.path.insert(0,str(HERE))
from geometry import Mesh,materials,export_fbx,record

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--fixture-only',action='store_true');ap.add_argument('--no-render',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for name in ['FBX','Blender','Renders','Reports']:(OUT/name).mkdir(parents=True,exist_ok=True)
    spec=json.loads((REPO/'Docs/design/spire-blender-handoff-20261026/spire_spec.json').read_text(encoding='utf-8'))
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.name='00_AssetSources';scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    mats=materials(spec);m=Mesh();m.box((0,0,0),(100,100,100),'M01');m.box((150,0,0),(20,20,20),'M06');m.box((0,200,0),(20,20,20),'M07');m.box((0,0,250),(20,20,20),'M04')
    fixture=m.object('Spire_AxisGauge_Mars_SM',mats,scene.collection);export_fbx(fixture,OUT/'FBX'/('Spire_AxisGauge_Mars_SM.fbx'));row=record(fixture);row.update(id='AxisGauge',fbx='FBX/Spire_AxisGauge_Mars_SM.fbx')
    (OUT/'axis_fixture.json').write_text(json.dumps(row,indent=2));print('SPIRE_AXIS_FIXTURE_EXPORTED',json.dumps(row),flush=True)
    if args.fixture_only:return
    from production import build_all
    build_all(spec,scene,mats,args)

if __name__=='__main__':main()
