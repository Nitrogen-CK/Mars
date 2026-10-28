"""Headless editable forage art: 5 meshes, normalized gameplay bounds, room mockups."""
import hashlib,json,math,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OLD=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/catacomb-reference-match-r02'
PBR=OLD.parent/'catacomb-shape-pbr-r03'
OUT=OLD.parent/'catacomb-forage-props-r03'
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
    import bpy,bmesh
    from mathutils import Vector
    source=PBR/'room-preview-r04/Catacomb_CleanShapes_PBR_R04.blend'
    assert Path(bpy.data.filepath).resolve()==source.resolve()
    assert not OUT.exists() or not any(OUT.iterdir());OUT.mkdir(exist_ok=True)
    # This derived source already contains the new physical maps and original family mixes.
    albedo=bpy.data.images.load(str(OLD/'Stone_AngularPigment_Albedo_r02.png'));albedo.colorspace_settings.name='sRGB';albedo.pack()
    for family in ('walls','floor','ceiling','prop'):
        mat=bpy.data.materials['CatacombPilot_R02_Paint_'+family]
        n,=[n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image and n.image.name.startswith('Stone_CleanPlanes_BaseColor')]
        n.image=albedo
    scene=bpy.data.scenes['02_VariantC_Cutaway'];bpy.context.window.scene=scene
    mats={}
    for role,color,metal,rough in [('bronze',(.22,.115,.038,1),.75,.72),('fig',(.135,.027,.064,1),0,.83),('bellnut',(.26,.125,.035,1),0,.88),('pepper',(.035,.026,.016,1),0,.9)]:
        mat=bpy.data.materials.new('Forage_R01_'+role);mat.use_nodes=True;mat.diffuse_color=color
        t=mat.node_tree;bs=t.nodes.get('Principled BSDF');bs.inputs['Metallic'].default_value=metal;bs.inputs['Roughness'].default_value=rough
        vc=t.nodes.new('ShaderNodeVertexColor');vc.layer_name='ForagePaint';t.links.new(vc.outputs['Color'],bs.inputs['Base Color'])
        mats[role]=mat
    # Existing authored palette on unchanged collision-bearing cubes, not a mesh swap.
    mats['stone']=bpy.data.materials['CatacombPilot_R02_Paint_prop']
    timber=bpy.data.materials['WarrensC_DarkTimber_Mars_MI'].copy();timber.name='Forage_PainterlyTimber_R03'
    # Broad lengthwise tonal grain; object coordinates keep the preserved structural cubes usable.
    t=timber.node_tree;t.nodes.clear();out=t.nodes.new('ShaderNodeOutputMaterial');bs=t.nodes.new('ShaderNodeBsdfPrincipled');bs.inputs['Roughness'].default_value=.86;t.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    tc=t.nodes.new('ShaderNodeTexCoord');scale=t.nodes.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(8,8,.35);t.links.new(tc.outputs['Generated'],scale.inputs[0])
    noise=t.nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=2;noise.inputs['Detail'].default_value=0;t.links.new(scale.outputs[0],noise.inputs['Vector'])
    ramp=t.nodes.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
    for pos,col in [(0,(.035,.018,.008,1)),(.38,(.075,.036,.014,1)),(.53,(.12,.058,.021,1)),(.67,(.17,.085,.029,1))]:
        el=ramp.color_ramp.elements[0] if pos==0 else ramp.color_ramp.elements.new(pos);el.color=col
    ramp.color_ramp.elements.remove(ramp.color_ramp.elements[-1]);t.links.new(noise.outputs['Fac'],ramp.inputs['Fac']);t.links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
    mats['timber']=timber
    arm_timber=timber.copy();arm_timber.name='Forage_PainterlyTimberArm_R03'
    arm_scale,=[n for n in arm_timber.node_tree.nodes if n.type=='VECT_MATH'];arm_scale.inputs[1].default_value=(.35,8,8)
    mats['timber_arm']=arm_timber
    meshes={};parts=[]
    def cyl(at,radius,depth,vertices=8,rotation=(0,0,0)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=at,rotation=rotation)
        o=bpy.context.object;parts.append(o);return o
    def torus(at,major,minor,rotation=(0,0,0)):
        bpy.ops.mesh.primitive_torus_add(major_segments=12,minor_segments=4,location=at,rotation=rotation,major_radius=major,minor_radius=minor)
        o=bpy.context.object;parts.append(o);return o
    def ico(at,radius,sub=1):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=radius,location=at)
        o=bpy.context.object;parts.append(o);return o
    def finish(name,role):
        rng=random.Random(name)
        for part in parts:
            color=part.get('paint_rgba',mats[role].diffuse_color)
            attr=part.data.color_attributes.new(name='ForagePaint',type='FLOAT_COLOR',domain='CORNER')
            for poly in part.data.polygons:
                tone=rng.uniform(.88,1.12)
                for li in poly.loop_indices:attr.data[li].color=tuple(min(.99,v*tone) for v in color[:3])+(1,)
        bpy.ops.object.select_all(action='DESELECT')
        for o in parts:o.select_set(True)
        bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
        bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
        o.data.name=name+'_Mesh';o.data.materials.clear();o.data.materials.append(mats[role])
        for p in o.data.polygons:
            p.use_smooth=False;p.material_index=0
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.015);bpy.ops.object.mode_set(mode='OBJECT')
        meshes[name]=o;parts.clear();return o
    # A perforated cage, with all body vertices inside the unchanged 50cm normalized radius.
    for z,r in [(-.3,.3),(-.15,.43),(0,.465),(.15,.43),(.3,.3)]:torus((0,0,z),r,.025)
    for i in range(8):
        a=math.tau*i/8
        profile=[Vector((r*math.cos(a),r*math.sin(a),z)) for z,r in [(-.3,.3),(-.15,.43),(0,.465),(.15,.43),(.3,.3)]]
        for lo,hi in zip(profile,profile[1:]):
            bar=cyl((lo+hi)*.5,.025,(hi-lo).length,6);bar.rotation_euler=(hi-lo).to_track_quat('Z','Y').to_euler()
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.12,radius2=.3,depth=.15,location=(0,0,-.375));parts.append(bpy.context.object)
    bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.3,radius2=.10,depth=.12,location=(0,0,.36));parts.append(bpy.context.object)
    torus((0,0,.43),.04,.012,rotation=(math.pi/2,0,0))
    body=finish('WVC_Forage_CenserBob_R01_SM','bronze')
    assert max(v.co.length for v in body.data.vertices)<=.50001
    # Unit-length chain: caller sizes only this NoCollision visual to pivot->bob-top.
    for i in range(12):
        o=torus((0,0,-.45+i*.082),.39,.055,rotation=(math.pi/2,0,0) if i%2==0 else (0,math.pi/2,0))
        # Compress the torus in its local plane, along its world-Z axis after rotation.
        # Scaling local Z flattened the tube normal and produced overlapping coils.
        if i%2==0:o.scale.y=.15
        else:o.scale.x=.15
    chain=finish('WVC_Forage_Chain_R01_SM','bronze')
    maxz=max(abs(v.co.z) for v in chain.data.vertices)
    for v in chain.data.vertices:v.co.z*=.5/maxz
    assert max(abs(v.co.z) for v in chain.data.vertices)<.50001
    # One combined yield component. Offset compensates the existing+38cm/scale.16 cluster frame.
    rng=random.Random(61026)
    for i in range(14):
        at=Vector((rng.uniform(-.25,.25),rng.uniform(-.25,.25),rng.uniform(-.2,.2)))
        ico(at,.10,1)
    pepper=finish('WVC_Forage_PepperContents_R01_SM','pepper')
    assert max(v.co.length for v in pepper.data.vertices)<.5
    for v in pepper.data.vertices:v.co.z-=2.375
    # Both vine yields stay within the original normalized knock sphere.
    fig=ico((0,0,0),.48,2)
    for v in fig.data.vertices:
        z=v.co.z;v.co.x*=.82*(1-.5*(z/.5));v.co.y*=.82*(1-.5*(z/.5));v.co.z*=.95
    def stem_and_leaf():
        stem=cyl((0,0,.47),.032,.18,6);stem['paint_rgba']=(.12,.075,.025,1)
        # One folded pointed leaf, joined to the yield so depletion removes the complete fruit.
        mesh=bpy.data.meshes.new('FoldedLeaf');mesh.from_pydata([(0,0,.42),(.18,-.07,.41),(.38,0,.37),(.18,.07,.41),(.17,0,.47)],[],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)]);mesh.update()
        leaf=bpy.data.objects.new('Leaf',mesh);bpy.context.collection.objects.link(leaf);parts.append(leaf);leaf['paint_rgba']=(.055,.095,.025,1)
    stem_and_leaf()
    fig=finish('WVC_Forage_Fig_R01_SM','fig')
    scale=.5/max(v.co.length for v in fig.data.vertices)
    for v in fig.data.vertices:v.co*=scale
    bell=ico((0,0,0),.48,2)
    for v in bell.data.vertices:
        a=math.atan2(v.co.y,v.co.x);f=(.78+.15*math.cos(6*a))*(1-.35*v.co.z/.5);v.co.x*=f;v.co.y*=f;v.co.z*=.85
    stem_and_leaf()
    bell=finish('WVC_Forage_Bellnut_R01_SM','bellnut')
    scale=.5/max(v.co.length for v in bell.data.vertices)
    for v in bell.data.vertices:v.co*=scale
    for o in meshes.values():o.hide_render=True
    exports=[]
    for name,o in meshes.items():
        bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
        path=OUT/(name+'.fbx')
        bpy.ops.export_scene.fbx(filepath=str(path),use_selection=True,object_types={'MESH'},global_scale=1,
            apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',axis_forward='-Y',axis_up='Z',use_mesh_modifiers=False,
            mesh_smooth_type='FACE',use_triangles=True,bake_anim=False,path_mode='STRIP',use_custom_props=True,colors_type='LINEAR')
        coords=[v.co for v in o.data.vertices]
        exports.append(dict(name=name,file=path.name,sha256=sha(path),vertices=len(coords),triangles=sum(len(p.vertices)-2 for p in o.data.polygons),
            blender_min_metres=[min(v[i] for v in coords) for i in range(3)],blender_max_metres=[max(v[i] for v in coords) for i in range(3)],
            role='One NoCollision visual replacement',material_role='pepper' if 'Pepper' in name else 'fig' if 'Fig' in name else 'bellnut' if 'Bellnut' in name else 'bronze',uv_channels=len(o.data.uv_layers)))
    preview=bpy.data.collections.new('Catacomb_Forage_Preview_Only');scene.collection.children.link(preview)
    created=[]
    def instance(mesh,at,scale,material=None):
        o=bpy.data.objects.new('ForagePreview_'+mesh.name,mesh.data);preview.objects.link(o);o.location=at;o.scale=scale;o.hide_render=False
        if material:
            for slot in o.material_slots:slot.link='OBJECT';slot.material=material
        created.append(o);return o
    def cube(at,scale,role):
        bpy.ops.mesh.primitive_cube_add(size=1,location=at);o=bpy.context.object;o.scale=scale;o.data.materials.append(mats[role]);created.append(o);return o
    origin=Vector((-84,-19,0))
    # Exact unchanged structural cube poses; their materials only are dressed.
    def basin(half):
        for at,scale in [((0,half,.2),(half*2+.12,.12,.4)),((0,-half,.2),(half*2+.12,.12,.4)),((half,0,.2),(.12,half*2+.12,.4)),((-half,0,.2),(.12,half*2+.12,.4))]:
            cube(origin+Vector(at),scale,'stone')
    def assembly(kind):
        basin(.7 if kind=='censer' else .8)
        if kind=='censer':
            cube(origin+Vector((0,0,2.5)),(.4,.4,.3),'stone')
            cube(origin+Vector((0,0,3.625)),(.08,.08,1.95),'timber') # NoCollision cosmetic ceiling hanger.
            instance(chain,origin+Vector((0,0,1.85)),(.06,.06,1.30))
            instance(body,origin+Vector((0,0,.9)),(.6,.6,.6))
            instance(pepper,origin+Vector((0,0,1.28)),(.16,.16,.16))
        else:
            cube(origin+Vector((-1.2,0,1.3)),(.24,.24,2.6),'timber')
            cube(origin+Vector((-.6,0,2.6)),(1.2,.12,.12),'timber_arm')
            cube(origin+Vector((0,0,2.48)),(.025,.025,.12),'timber') # Persistent NoCollision twine to the fruit's upper bound.
            instance(fig if kind=='fig' else bell,origin+Vector((0,0,2.2)),(.44,.44,.44))
    frames=[];scene.render.resolution_x=1280;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    camera_data=bpy.data.cameras.new('Forage_ActualScale_PlayerCamera');camera=bpy.data.objects.new(camera_data.name,camera_data);scene.collection.objects.link(camera)
    camera.location=(-81,-19,1.12);camera_data.lens=18;camera_data.sensor_width=36;scene.camera=camera
    lights=json.loads((OLD/'pilot-preview-r03/receipt.json').read_text())['lights']
    for l in lights:bpy.data.objects[l['name']].hide_render=l['group']!='warm'
    lamp=bpy.data.objects['CatacombPilot_R02_PlayerLanternReviewProxy'];lamp.location=(-81.2,-19.2,.75)
    for kind in ('censer','fig','bellnut'):
        for o in list(created):bpy.data.objects.remove(o,do_unlink=True)
        created.clear();assembly(kind)
        target=origin+Vector((0,0,.9 if kind=='censer' else 2.2));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
        path=OUT/(kind+'_HuskNiche_PlayerPreview.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        frames.append(dict(kind=kind,file=path.name,sha256=sha(path),camera=[list(v) for v in camera.matrix_world]))
        yield_mesh=pepper if kind=='censer' else fig if kind=='fig' else bell
        visible_yield,=[o for o in created if o.type=='MESH' and o.data==yield_mesh.data]
        visible_yield.hide_render=True
        path=OUT/(kind+'_Depleted_PlayerPreview.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
        frames.append(dict(kind=kind,state='depleted',file=path.name,sha256=sha(path)))
        visible_yield.hide_render=False
        if kind=='censer':
            from mathutils import Quaternion
            moving=[o for o in created if o.type=='MESH' and o.data in (chain.data,body.data,pepper.data)]
            rest=[(o,o.location.copy(),o.rotation_euler.copy()) for o in moving]
            pivot=origin+Vector((0,0,2.5))
            for angle in (-18,18):
                q=Quaternion((0,1,0),math.radians(angle))
                for o,at,rot in rest:o.location=pivot+q@(at-pivot);o.rotation_euler=(q@rot.to_quaternion()).to_euler()
                path=OUT/('censer_Swing'+str(angle)+'_PlayerPreview.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
                frames.append(dict(kind=kind,state='swing',angle_degrees=angle,file=path.name,sha256=sha(path)))
            for o,at,rot in rest:o.location=at;o.rotation_euler=rot
            old_camera=camera.matrix_world.copy();camera.location=(-82.8,-19,1.12);camera.rotation_euler=(origin+Vector((0,0,.9))-camera.location).to_track_quat('-Z','Y').to_euler()
            for full in (True,False):
                visible_yield.hide_render=not full;path=OUT/('censer_Close_'+('Full' if full else 'Depleted')+'.png');scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
                frames.append(dict(kind=kind,state='close_full' if full else 'close_depleted',file=path.name,sha256=sha(path)))
            visible_yield.hide_render=False;camera.matrix_world=old_camera
    blend=OUT/'Catacomb_ForageProps_Source_R01.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend),compress=True)
    report=dict(status='DERIVED_FORAGE_MESHES_AND_THREE_VARIANT_MOCKUPS',exports=exports,frames=frames,source_sha256=sha(source),derived_sha256=sha(blend),tool_sha256=sha(__file__),
        contracts=dict(censer_bob_max_normalized_radius_metres=max(v.co.length for v in body.data.vertices),bob_knock_sphere_cm=30,
            pepper_component_original_offset_cm=38,pepper_component_scale=.16,pepper_mesh_pivot_compensation_metres=-2.375,
            chain='Normalized1m mesh; only NoCollision visual sized to ArmLength-BobRadius, under original Pivot node',
            structural='Pivot, basin walls, vine post remain exactly original cube geometry/poses/BlockAll; materials only',
            ceiling_hanger='Additional optional NoCollision art rod; Catacomb niche roof4.6m. No physics body or oscillator change',
            yield_policy='One combined mesh in existing _YieldMesh slot, so original exhaustion/refill visibility remains authoritative'),
        boundary='Mockups/model assets only. Original maps/libraries unchanged; no AngelScript or runtime skin integration yet. Existing mushroom production art remains unchanged. Real Censer swing/drop/refill and all default behavior require focused tests and native review after opt-in integration.')
    (OUT/'PROP_PREVIEW_RECEIPT.json').write_text(json.dumps(report,indent=2)+'\n');print('FORAGE_ART_PREVIEW_READY',sha(OUT/'PROP_PREVIEW_RECEIPT.json'),flush=True)
if __name__=='__main__':main()
