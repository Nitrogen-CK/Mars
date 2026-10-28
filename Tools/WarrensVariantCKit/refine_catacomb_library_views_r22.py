"""Presentation-only successor: unchanged art, isolated readable library views."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev'
OWNER='Mars.WarrensVariantC.Catacomb.LibraryViews.R22'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def module(name):
    s=importlib.util.spec_from_file_location('_cp22_'+name,HERE/(name+'.py'));m=importlib.util.module_from_spec(s);s.loader.exec_module(m);return m
def main():
    import bpy
    from mathutils import Vector
    p=argparse.ArgumentParser();p.add_argument('--target',required=True,choices=('Diorama','KitLibrary'));a=p.parse_args(sys.argv[sys.argv.index('--')+1:]);target=a.target
    previous=DOC/'catacomb-library-sync-r21'/target;r=json.loads((previous/'receipt.json').read_text());source=ROOT/r['candidate'];assert Path(bpy.data.filepath).resolve()==source.resolve() and sha(source)==r['candidate_sha256']
    writer=module('stage_catacomb_blender_libraries_r21');sync=module('sync_art_libraries');writer.guards();original_before=json.loads((previous/'before.json').read_text());active=bpy.context.window.scene
    loaded=writer.snapshot(sync);writer.assert_originals(original_before,loaded,r['allowed_collection_reference_changes'])
    before_meshes=loaded['meshes'];before_mats=loaded['materials'];before_models={o.name:dict(basis=[list(v) for v in o.matrix_basis],data=o.data.name if o.data else None,instance=o.instance_collection.name if o.instance_collection else None,materials=[(s.link,s.material.name if s.material else None) for s in o.material_slots]) for o in bpy.data.objects if o.type in ('MESH','EMPTY')}
    out=DOC/'catacomb-library-sync-r22'/target;out.mkdir(parents=True,exist_ok=False)
    selection=json.loads((DOC/'catacomb-reference-match-r02/LIBRARY_SELECTION_R21.json').read_text());cells={v['role']:v['centre_blender_metres'] for v in selection['kit_cells']};cy=cells['Fig'][1]
    models={role:bpy.data.objects['CP21_Kit_'+role] for role in cells}
    label=bpy.data.materials.new('CP22_Label');label.use_nodes=True;nt=label.node_tree;nt.nodes.clear();em=nt.nodes.new('ShaderNodeEmission');em.inputs['Color'].default_value=(.8,.76,.65,1);em.inputs['Strength'].default_value=1;output=nt.nodes.new('ShaderNodeOutputMaterial');nt.links.new(em.outputs[0],output.inputs['Surface'])
    for obj in bpy.data.objects:
        if obj.type=='FONT' and obj.name.startswith('CP21_'):
            if obj.data.materials:obj.data.materials[0]=label
            else:obj.data.materials.append(label)
    def group(name,roles):
        c=bpy.data.collections.new('CP22_'+name);c['Owner']=OWNER
        for role in roles:c.objects.link(models[role])
        return c
    studio=bpy.data.collections['CP21_Kit_StudioLights'];base=bpy.data.scenes['CP21_Catacomb_Kit']
    base.collection.children.unlink(bpy.data.collections['CP21_Kit_Exhibits']);base.collection.children.link(group('ForageModels',['Fig','Censer','Bellnut']));base.camera.data.lens=40
    def camera(scene,name,at,target,lens):
        d=bpy.data.cameras.new('CP22_'+name);d.lens=lens;d.clip_end=2000;o=bpy.data.objects.new('CP22_'+name,d);scene.collection.objects.link(o);o.location=at;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o['Owner']=OWNER;scene.camera=o;return o
    def text(col,role,upright=False,body=None):
        source=bpy.data.objects['CP21_Label_'+role];o=source.copy();o.name='CP22_'+col.name+'_'+role;o['Owner']=OWNER
        if body is not None:o.data=source.data.copy();o.data.name=o.name+'_Font';o.data.body=body
        if upright:o.location=(cells[role][0],cy+1.2,.2);o.rotation_euler=(1.5707963267948966,0,3.141592653589793)
        else:o.rotation_euler.z=3.141592653589793
        col.objects.link(o);return o
    def scene(name,roles,at,target,lens,upright=False):
        s=bpy.data.scenes.new('CP22_'+name);s.render.engine='BLENDER_EEVEE';s.render.resolution_x=1400;s.render.resolution_y=875;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.eevee.taa_render_samples=128;s.eevee.shadow_ray_count=4;s.eevee.shadow_step_count=12;s.view_settings.view_transform='AgX';s.world=base.world
        c=group(name+'_Models',roles);s.collection.children.link(c);s.collection.children.link(studio)
        labels=bpy.data.collections.new('CP22_'+name+'_Labels');s.collection.children.link(labels)
        for role in roles:text(labels,role,upright)
        camera(s,name+'_Camera',at,target,lens);return s
    props=scene('Props',['Tomb','Lid','Bone','Urn'],(34.5,cy+22,9),(34.5,cy,.5),32)
    surfaces=scene('Surfaces',['Walls','Floor','Ceiling'],(59.5,cy+20,5),(59.5,cy,1),35)
    ceiling=scene('CeilingUnderside',['Ceiling'],(66.5,cy+5,.9),(66.5,cy,2),35)
    for o in list(bpy.data.collections['CP22_CeilingUnderside_Labels'].objects):bpy.data.objects.remove(o,do_unlink=True)
    # This light is shared only by new presentation scenes, not either original library scene.
    light=bpy.data.lights.new('CP22_CeilingPresentationFill','POINT');light.energy=30;light.color=(1,.92,.8);light.shadow_soft_size=.3;lo=bpy.data.objects.new(light.name,light);studio.objects.link(lo);lo.location=(66.5,cy+1,1.1);lo['Owner']=OWNER
    timber=scene('Timber',['TimberPost','TimberArm'],(77,cy+9,1.8),(77,cy,1.4),35,True)
    details=[]
    for role in ('Fig','Censer','Bellnut'):
        x=cells[role][0];distance=8 if role=='Censer' else 5;height=2.3 if role=='Censer' else 1.3;lens=38 if role=='Censer' else 40
        s=scene(role+'_Detail',[role],(x,cy+distance,height),(x,cy,height),lens,True);details.append((role.lower()+'_detail',s))
    views=[('room',bpy.data.scenes['CP21_Catacomb_CompleteRoom']),('cutaway',bpy.data.scenes['CP21_Catacomb_Cutaway']),('forage_kit',base),('props',props),('surfaces',surfaces),('ceiling',ceiling),('timber',timber)]+details
    bpy.context.window.scene=active;bpy.context.view_layer.update();current=writer.snapshot(sync);writer.assert_originals(original_before,current,r['allowed_collection_reference_changes'])
    assert before_meshes=={k:current['meshes'][k] for k in before_meshes};assert before_mats=={k:current['materials'][k] for k in before_mats}
    for name,row in before_models.items():
        o=bpy.data.objects[name];assert row==dict(basis=[list(v) for v in o.matrix_basis],data=o.data.name if o.data else None,instance=o.instance_collection.name if o.instance_collection else None,materials=[(s.link,s.material.name if s.material else None) for s in o.material_slots]),('Art object changed',name)
    writer.guards();candidate=out/('WarrensVariantC_'+target+'_Catacomb_R22.blend');bpy.ops.wm.save_as_mainfile(filepath=str(candidate),compress=True,relative_remap=False)
    frames=[]
    for name,s in views:
        bpy.context.window.scene=s;bpy.context.view_layer.update();s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True);frames.append(dict(view=name,file=name+'.png',sha256=sha(out/(name+'.png')),camera=[list(v) for v in s.camera.matrix_world],lens=s.camera.data.lens))
    bpy.context.window.scene=active;bpy.context.view_layer.update();writer.assert_originals(original_before,writer.snapshot(sync),r['allowed_collection_reference_changes']);writer.guards()
    report=dict(status='PRESENTATION_ONLY_LIBRARY_SUCCESSOR_RENDERED',target=target,source=source.relative_to(ROOT).as_posix(),source_sha256=sha(source),candidate=candidate.relative_to(ROOT).as_posix(),candidate_sha256=sha(candidate),writer_sha256=sha(__file__),stage_writer_sha256=sha(HERE/'stage_catacomb_blender_libraries_r21.py'),sync_helper_sha256=sha(HERE/'sync_art_libraries.py'),material_helper_sha256=sha(HERE/'catacomb_blender_materials_r21.py'),geometry_and_art_materials_unchanged_from_r21=True,original_baseline=(previous/'before.json').relative_to(ROOT).as_posix(),allowed_collection_reference_changes=r['allowed_collection_reference_changes'],frames=frames,boundary='Derived library presentation only. Separate-process reopen audit and independent visual approval required before originals are replaced. No native library write; pending Sluice work unchanged.')
    (out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n');print('PRESENTATION_SUCCESSOR_READY',target,sha(out/'receipt.json'))
if __name__=='__main__':main()
