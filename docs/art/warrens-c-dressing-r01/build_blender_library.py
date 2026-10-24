"""Headless Blender material library + neutral/lantern inspection scenes; no level dressing."""
import bpy,json,math,os
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent
OUT=ROOT/'blender'
bpy.context.preferences.filepaths.save_version=0
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for material in list(bpy.data.materials):bpy.data.materials.remove(material)
scene=bpy.context.scene;scene.name='01_NeutralMaterialReview'
geometry=bpy.data.collections.new('MaterialSwatches_NotGameProps');scene.collection.children.link(geometry)
images={};materials={}
def load(path,color=True):
    key=(path,color)
    if key not in images:
        image=bpy.data.images.load(str(ROOT/path),check_existing=False)
        image.colorspace_settings.name='sRGB' if color else 'Non-Color'
        images[key]=image
    return images[key]
def base(name,ident):
    m=bpy.data.materials.new(name);m.use_nodes=True;m.use_fake_user=True
    m['catalog_id']=ident;m['source_pack']='Warrens C dressing r01'
    if not ident.startswith('QA_'):
        m.asset_mark();m.asset_data.description='Stylized C dressing material. Art resource only; no Unreal import or gameplay edits.'
    n=m.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');out.location=(680,0)
    bs=n.new('ShaderNodeBsdfPrincipled');bs.location=(360,0);m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    bs.inputs['Roughness'].default_value=.8
    return m,bs
def texture(m,path,color,location):
    t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=load(path,color);t.location=location;t.label=path.split('/')[-1]
    return t
def surface(spec):
    ident=spec['id'];m,bs=base(f"WarrensC_{spec['name']}_Mars_MI",ident);links=m.node_tree.links
    t=texture(m,spec['maps']['BaseColor'],True,(-600,240));links.new(t.outputs['Color'],bs.inputs['Base Color'])
    orm=texture(m,spec['maps']['ORM'],False,(-600,-30));sep=m.node_tree.nodes.new('ShaderNodeSeparateColor');sep.location=(-260,-30)
    links.new(orm.outputs['Color'],sep.inputs['Color']);links.new(sep.outputs['Green'],bs.inputs['Roughness']);links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
    normal=texture(m,spec['maps']['NormalGL'],False,(-600,-350));node=m.node_tree.nodes.new('ShaderNodeNormalMap');node.location=(-160,-280)
    links.new(normal.outputs['Color'],node.inputs['Color']);links.new(node.outputs['Normal'],bs.inputs['Normal'])
    m['tile_metres']=spec.get('tile_metres',[1,1]);m['normal_convention']='OpenGL +Y; Unreal import uses separately supplied NormalDX'
    m['ao_channel']='ORM.R, deliberately not baked/multiplied into base color';materials[ident]=m
    return m
specs=json.loads((ROOT/'materials.json').read_text())
for spec in specs:surface(spec)
for spec in json.loads((ROOT/'trim_metadata.json').read_text()):
    m=surface(spec);m['uv_usage']='Repeat U only; keep V inside selected band plus its documented gutter.'
m,bs=base('WarrensC_FlatPalette_Mars_MI','AT01');t=texture(m,'textures/atlases/AT01_Palette_BaseColor.png',True,(-350,0));t.interpolation='Closest'
m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color']);materials['AT01']=m
def alpha_material(ident,name,path):
    m,bs=base(name,ident);t=texture(m,path,True,(-350,0));m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color']);m.node_tree.links.new(t.outputs['Alpha'],bs.inputs['Alpha'])
    m.surface_render_method='DITHERED';m['usage']='alpha decal/card. Fit separate thin geometry; no collision.';materials[ident]=m;return m
alpha_material('AT04','WarrensC_GlyphAtlas_Mars_MI','textures/atlases/AT04_GlyphAndNavigation_Alpha.png')
jobs=json.loads((ROOT/'image_jobs.json').read_text())
for job in jobs:
    if job['type']=='painted':alpha_material(job['id'],f"WarrensC_{job['title']}_Mars_MI",job['image'])
for ident in ['Wear_DampLeak','Wear_SaltResidue','Wear_SootFan','Wear_FlourScuff']:
    alpha_material(ident,f'WarrensC_{ident}_Mars_MI',f'textures/decals/{ident}.png')
m=alpha_material('FX_Flame','WarrensC_FlameCard_Mars_MI','textures/fx/FlameCard_RGBA.png');bs=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED');t=next(n for n in m.node_tree.nodes if n.type=='TEX_IMAGE')
m.node_tree.links.new(t.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=1.5
m,bs=base('WarrensC_Water_Mars_MI','FX_Water');bs.inputs['Base Color'].default_value=(.055,.12,.095,1);bs.inputs['Roughness'].default_value=.24;bs.inputs['Transmission Weight'].default_value=.25
t=texture(m,'textures/fx/Water_NormalGL.png',False,(-350,0));n=m.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.35
m.node_tree.links.new(t.outputs['Color'],n.inputs['Color']);m.node_tree.links.new(n.outputs['Normal'],bs.inputs['Normal']);materials['FX_Water']=m
materials['FX_Dust']=materials['Wear_FlourScuff']

def move_to(obj,collection):
    for c in list(obj.users_collection):c.objects.unlink(obj)
    collection.objects.link(obj)
def cube(name,loc,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);obj=bpy.context.object;obj.name=name;obj.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);obj.data.materials.append(mat);move_to(obj,geometry)
    mod=obj.modifiers.new('OneBroadBevel','BEVEL');mod.width=.035;mod.segments=1
    return obj
def uv_metres(obj,tile):
    uv=obj.data.uv_layers.active or obj.data.uv_layers.new()
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda k:abs(face.normal[k]));axes=[k for k in range(3) if k!=axis]
        for li in face.loop_indices:
            co=obj.data.vertices[obj.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[axes[0]]/tile[0],co[axes[1]]/tile[1])
def text(body,loc,size=.2):
    data=bpy.data.curves.new(body,'FONT');data.body=body;data.size=size;data.align_x='CENTER'
    obj=bpy.data.objects.new(body,data);geometry.objects.link(obj);obj.location=loc;return obj
label,bs=base('ReviewLabel_NotExport','QA_Label');bs.inputs['Base Color'].default_value=(.68,.64,.49,1)
for i,spec in enumerate(specs):
    x=(i%5-2)*3.2;y=(i//5)*3.2
    obj=cube(spec['id']+'_'+spec['name'],(x,y,.9),(1.85,1.85,1.8),materials[spec['id']]);uv_metres(obj,spec['tile_metres'])
    obj['not_production_mesh']=True
    obj=text(spec['id']+' '+spec['name'],(x,y-1.25,.025),.18);obj.data.materials.append(label)
ground,bs=base('ReviewGround_NotExport','QA_Ground');bs.inputs['Base Color'].default_value=(.075,.087,.072,1)
cube('ReviewGround',(0,5,-.15),(19,17,.25),ground)
def camera_for(sc):
    data=bpy.data.cameras.new('ReviewCamera');obj=bpy.data.objects.new('ReviewCamera',data);sc.collection.objects.link(obj)
    obj.location=(12,-17,19);target=Vector((0,4.6,.5));obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler();data.type='ORTHO';data.ortho_scale=23;sc.camera=obj
def light(sc,name,loc,energy,color,size):
    data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.color=color;data.shape='DISK';data.size=size
    obj=bpy.data.objects.new(name,data);sc.collection.objects.link(obj);obj.location=loc;obj.rotation_euler=(Vector((0,4,0))-obj.location).to_track_quat('-Z','Y').to_euler()
def setup(sc,name,ambient):
    sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True
    sc.render.resolution_x=1800;sc.render.resolution_y=1400;sc.render.resolution_percentage=100
    sc.world=bpy.data.worlds.new(name);sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.16,.18,.16,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=ambient
    sc.view_settings.view_transform='Standard';sc.render.image_settings.file_format='PNG';sc.render.film_transparent=False
    sc.unit_settings.system='METRIC';sc.unit_settings.scale_length=1
    camera_for(sc)
setup(scene,'NeutralReviewWorld',.6)
light(scene,'NeutralKey',(-5,-1,13),2300,(1,1,1),10);light(scene,'NeutralFill',(7,8,10),1800,(1,1,1),9)
lantern=bpy.data.scenes.new('02_LanternReadabilityStudy');lantern.collection.children.link(geometry);setup(lantern,'LanternReviewWorld',.035)
light(lantern,'WarmLanternStudy',(-5,-2,5),1350,(1,.48,.16),5);light(lantern,'CoolDepthStudy',(6,11,9),850,(.22,.44,.52),7)
# Third scene contains the atlases, glyphs and transparent art sources on simple display cards.
atlas_scene=bpy.data.scenes.new('03_AtlasesAndPaintedArt');setup(atlas_scene,'AtlasReviewWorld',.6)
cards=bpy.data.collections.new('AtlasReviewCards_NotGameProps');atlas_scene.collection.children.link(cards)
for i,ident in enumerate(['AT01','AT02','AT03','AT04']+[j['id'] for j in jobs if j['type']=='painted']):
    bpy.ops.mesh.primitive_plane_add(size=2,location=((i%5-2)*3.2,(i//5)*3.6,0))
    obj=bpy.context.object;obj.name=ident+'_Card_NotExport';obj.data.materials.append(materials[ident]);move_to(obj,cards)
light(atlas_scene,'CardKey',(-5,-3,12),2500,(1,1,1),10)
atlas_scene.camera.data.ortho_scale=19;atlas_scene.camera.location=(5,-10,18);atlas_scene.camera.rotation_euler=(Vector((0,2,0))-atlas_scene.camera.location).to_track_quat('-Z','Y').to_euler()
manifest={'blender_version':bpy.app.version_string,'units':'metres;1.0 Blender unit =100cm','material_count':len({m.name for m in materials.values()}),
    'materials':{k:v.name for k,v in materials.items()},'scenes':[s.name for s in [scene,lantern,atlas_scene]],
    'image_count':len(images),'packed_images':True,'render_note':'Studio studies only. Not Unreal/PIE lighting calibration.',
    'production_meshes_generated':False,'normal_convention_in_blend':'OpenGL','unreal_normal_files':'NormalDX'}
bpy.context.window.scene=scene
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_perspective='CAMERA'
bpy.ops.file.pack_all()
for (path,color),image in images.items():image.filepath='//../'+path
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'WarrensC_MaterialLibrary.blend'),compress=True)
(OUT/'library_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for sc,name in [(scene,'NEUTRAL_MATERIALS'),(lantern,'LANTERN_MATERIALS'),(atlas_scene,'ATLASES_AND_ART')]:
    bpy.context.window.scene=sc;sc.render.filepath=str(ROOT/'qa'/f'{name}.png');bpy.ops.render.render(write_still=True)
print('BLENDER_LIBRARY_AND_RENDERS_COMPLETE',flush=True)
