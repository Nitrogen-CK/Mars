"""Blender 5.2 CLI: imported exact Steward rig, holding loop, separate parchment.

blender --background --python-exit-code 1 --python build_service.py
Inputs are read-only. All products go to ../Output/Art. Static prop local UE +X
is its reading normal; its manifest component transform faces the Steward +Y.
"""
import bpy, bmesh, json, math, hashlib, sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

OUT = Path(__file__).resolve().parents[1] / 'Output/Art'
SOURCE = OUT / 'Steward_Source.fbx'
FPS, END = 30, 180
# Dimensional controls, metres in Blender. UE data/manifest is derived in cm.
READ_WIDTH = .80
READ_TOP, READ_BOTTOM = .25, -.65
READ_HEIGHT = READ_TOP-READ_BOTTOM
ROLL_WIDTH, ROLL_RADIUS = .84, .052
PAPER_FRONT, PAPER_HEIGHT = .55, 1.75
WRIST_SIDE, WRIST_HEIGHT = .50, 1.96
SAFE_WIDTH, SAFE_HEIGHT = .76, .855
WIDGET_CENTRE_Z, WIDGET_SCALE = -.19, .095
TAIL_FLOOR_HEIGHT = .02
DRAPE_FLOOR_START, DRAPE_APRON_END = .43, .65
DRAPE_CONTROL_1, DRAPE_CONTROL_2 = (0,-1.18), (.14,-1.73)
DRAPE_CURL_RADIUS, DRAPE_EDGE_WAVE = .05, .006
SHEET_THICKNESS = .004
TAIL_END_Z = TAIL_FLOOR_HEIGHT - PAPER_HEIGHT
PAPER_AT = Vector((0, -PAPER_FRONT, PAPER_HEIGHT))

def wrist_target(sign):return Vector((sign*WRIST_SIDE,-PAPER_FRONT,WRIST_HEIGHT))

def material(name, color, rough=.85):
    m = bpy.data.materials.new(name); m.diffuse_color = (*color, 1); m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = rough
    return m

def mesh_object(name, verts, faces, mat):
    me = bpy.data.meshes.new(name); me.from_pydata(verts, [], faces); me.update()
    o = bpy.data.objects.new(name, me); bpy.context.scene.collection.objects.link(o); me.materials.append(mat)
    uv = me.uv_layers.new(name='UVMap')
    for loop in me.loops:
        co = me.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (co.y / READ_WIDTH + .5, (co.z-READ_BOTTOM) / READ_HEIGHT)
    return o

def parchment():
    """Local Blender +X normal; export Y reflection gives local UE +X normal."""
    paper = material('ServiceParchment_Mars_M', (.63, .43, .20))
    verts, faces = [], []
    # Constant planar centre, thin solid sheet, no UI baked into it.
    half_w,half_h=READ_WIDTH/2,READ_TOP
    for x in [-SHEET_THICKNESS, 0]:
        verts += [(x, y, z) for y, z in [(-half_w,READ_BOTTOM),(half_w,READ_BOTTOM),(half_w,READ_TOP),(-half_w,READ_TOP)]]
    faces += [(4,5,6,7),(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    panel = mesh_object('Paper_FlatReadingArea', verts, faces, paper)
    group=panel.vertex_groups.new(name='ReadingPanel');group.add(list(range(len(verts))),1,'REPLACE')
    parts = [panel]
    # Closed six-sided ribbons across the width; curled sections never cross the reading rectangle.
    def ribbon(name, profile, width=ROLL_WIDTH):
        vs=[]; fs=[]
        for i,(x,z) in enumerate(profile):
            w=width[i] if isinstance(width,list) else width
            vs += [(x,-w/2,z),(x,w/2,z),(x-SHEET_THICKNESS,-w/2,z),(x-SHEET_THICKNESS,w/2,z)]
        for i in range(len(profile)-1):
            a=i*4;b=a+4
            fs += [(a,a+1,b+1,b),(a+3,a+2,b+2,b+3),(a+2,a,b,b+2),(a+1,a+3,b+3,b+1)]
        a=len(vs)-4
        fs += [(0,2,3,1),(a,a+1,a+3,a+2)]
        result=mesh_object(name,vs,fs,paper);parts.append(result)
        return result
    for label,sign in [('Top',1)]:
        profile=[(0,half_h)]
        for i in range(29):
            t=i/28*math.pi*1.6
            # The complete roll stays above the flat reading rectangle, including
            # its return arc. A short sheet segment reaches its raised start.
            profile.append((ROLL_RADIUS*(1-math.cos(t)),sign*(half_h+ROLL_RADIUS+ROLL_RADIUS*math.sin(t))))
        top_curl=ribbon('Paper_'+label+'Curl',profile)
        assert min(v.co.z for v in top_curl.data.vertices)>=half_h-1e-7,'Top curl overlaps reading rectangle'
        group=top_curl.vertex_groups.new(name='TopCurl')
        group.add(list(range(len(top_curl.data.vertices))),1,'REPLACE')
    # Smooth sag: vertical tangent at reading-panel edge, horizontal tangent
    # at the ground. A short loose apron unrolls forward before its end curl.
    p0=Vector((0,READ_BOTTOM));p1=Vector(DRAPE_CONTROL_1)
    p2=Vector(DRAPE_CONTROL_2);p3=Vector((DRAPE_FLOOR_START,TAIL_END_Z))
    tail=[]
    for i in range(49):
        t=i/48;q=(1-t)**3*p0+3*(1-t)**2*t*p1+3*(1-t)*t*t*p2+t**3*p3;tail.append(tuple(q))
    for i in range(1,17):
        t=i/16;tail.append((DRAPE_FLOOR_START+(DRAPE_APRON_END-DRAPE_FLOOR_START)*t,TAIL_END_Z))
    for i in range(1,33):
        a=i/32*math.pi*1.4
        tail.append((DRAPE_APRON_END+DRAPE_CURL_RADIUS*math.sin(a),TAIL_END_Z+DRAPE_CURL_RADIUS*(1-math.cos(a))))
    (OUT/'drape_profile.json').write_text(json.dumps(dict(profile_xz_m=tail,static_authored_drape=True,runtime_cloth=False,
        controls=dict(control_1=DRAPE_CONTROL_1,control_2=DRAPE_CONTROL_2,floor_start=DRAPE_FLOOR_START,apron_end=DRAPE_APRON_END,
                      curl_radius=DRAPE_CURL_RADIUS,edge_wave=DRAPE_EDGE_WAVE)),indent=2))
    # Subdivided width permits subtle edge waviness while keeping the centre
    # relaxed. Thickness follows the section normal, including on the floor.
    columns=9;vs=[];fs=[];stride=columns*2
    for i,(x,z) in enumerate(tail):
        a=Vector(tail[max(0,i-1)]);b=Vector(tail[min(len(tail)-1,i+1)])
        tangent=(b-a).normalized();normal=Vector((-tangent.y,tangent.x))
        fade=min(1,i/12);fade=fade*fade*(3-2*fade)
        for back in [0,1]:
            for j in range(columns):
                u=j/(columns-1)*2-1
                wave=DRAPE_EDGE_WAVE*abs(u)**3*math.sin(i*.19+u*1.4)*fade
                offset=wave-back*SHEET_THICKNESS
                vs.append((x+normal.x*offset,u*READ_WIDTH/2,z+normal.y*offset))
    for i in range(len(tail)-1):
        a=i*stride;b=a+stride
        for j in range(columns-1):
            fs.extend([(a+j,a+j+1,b+j+1,b+j),(a+columns+j+1,a+columns+j,b+columns+j,b+columns+j+1)])
        fs.extend([(a,a+columns,b+columns,b),(a+columns-1,b+columns-1,b+stride-1,a+stride-1)])
    for j in range(columns-1):
        fs.append((j+1,j,columns+j,columns+j+1))
        a=(len(tail)-1)*stride;fs.append((a+j,a+j+1,a+columns+j+1,a+columns+j))
    drape=mesh_object('Paper_SuppleDrapeAndFloorApron',vs,fs,paper);parts.append(drape)
    faces_per_section=2*(columns-1)+2
    for face in drape.data.polygons:
        # Caps and thin edge walls must not bend the broad sheet's shading
        # normal into a visible hinge where it leaves the flat UI panel.
        face.use_smooth=face.index<(len(tail)-1)*faces_per_section and face.index%faces_per_section<2*(columns-1)
    group=drape.vertex_groups.new(name='LowerDrape');group.add(list(range(len(vs))),1,'REPLACE')
    # Raised wax seal on outer top roll: understated accent, outside widget bounds.
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=.028, depth=.009, location=(2*ROLL_RADIUS+.007,READ_WIDTH*.367,half_h+ROLL_RADIUS+.005), rotation=(0,math.pi/2,0))
    seal=bpy.context.object;seal.name='Paper_WaxSeal';seal.data.materials.append(material('ServiceSeal_Mars_M',(.22,.035,.018)));parts.append(seal)
    # Join for one static asset, keeping distinct flat/curl/tail islands and material slots.
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=panel;bpy.ops.object.join();panel.name='ServiceParchment_Mars_SM'
    bm=bmesh.new();bm.from_mesh(panel.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges),'Parchment islands must be closed solids'
    bm.to_mesh(panel.data);bm.free()
    return panel

def world_head(arm,name):return arm.matrix_world @ arm.pose.bones[name].head

def rotate_world(arm,name,rotation):
    pb=arm.pose.bones[name];world=arm.matrix_world @ pb.matrix
    q=world.to_quaternion();world=Matrix.LocRotScale(world.translation,rotation @ q,world.to_scale())
    pb.matrix=arm.matrix_world.inverted() @ world;bpy.context.view_layer.update()

def aim_child(arm,name,child,target):
    origin=world_head(arm,name);before=world_head(arm,child)-origin
    rotate_world(arm,name,before.rotation_difference(target-origin))

def correct_garment_weights(body):
    """Remove proven cross-surface auto-rig leaks only on isolated skirt panels.

    Source topology separates seven long lower garment islands from gloves:
    garment |X|<.429 m, glove |X|>=.473 m. Material 0 is the textured body.
    The low min-Z and bounded max-Z exclude torso/sleeves/hand islands.
    """
    me=body.data;before={v.index:{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in me.vertices}
    def finger(n):return n.startswith(('hand_','thumb_','index_','middle_','ring_','pinky_'))
    adj=[set() for _ in me.vertices]
    for e in me.edges:
        a,b=e.vertices;adj[a].add(b);adj[b].add(a)
    unseen=set(range(len(me.vertices)));garment=set();islands=[]
    while unseen:
        todo=[unseen.pop()];ids=[]
        while todo:
            i=todo.pop();ids.append(i)
            for j in adj[i]&unseen:unseen.remove(j);todo.append(j)
        points=[body.matrix_world @ me.vertices[i].co for i in ids]
        low=[min(p[k] for p in points) for k in range(3)];high=[max(p[k] for p in points) for k in range(3)]
        has_finger_weights=any(any(finger(n) for n in before[i]) for i in ids)
        if has_finger_weights and low[2]<.5 and high[2]<1.6 and max(abs(low[0]),abs(high[0]))<.45:
            materials={p.material_index for p in me.polygons if any(i in ids for i in p.vertices)}
            if materials=={0}:
                garment.update(ids);islands.append(dict(vertices=len(ids),bounds_min_m=low,bounds_max_m=high))
    assert len(islands)==7 and len(garment)==719,(len(islands),len(garment))
    changed=[]
    for i in sorted(garment):
        old=before[i];removed={n:w for n,w in old.items() if finger(n)}
        if not removed:continue
        retained={n:w for n,w in old.items() if not finger(n)};total=sum(retained.values())
        assert total>0,(i,old)
        for n in removed:body.vertex_groups[n].remove([i])
        for n,w in retained.items():body.vertex_groups[n].add([i],w/total,'REPLACE')
        changed.append(dict(vertex=i,before=old,removed=removed,after={n:w/total for n,w in retained.items()}))
    after={v.index:{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in me.vertices}
    assert all(before[i]==after[i] for i in before if i not in garment),'Non-garment weights changed'
    assert all(not any(finger(n) for n in after[i]) for i in garment)
    report=dict(garment_islands=islands,garment_vertices=len(garment),changed_vertices=len(changed),
                all_other_vertices_unchanged=True,hand_vertices_unchanged=True,changes=changed)
    (OUT/'garment_weight_correction.json').write_text(json.dumps(report,indent=2))
    return report

def export_service_mesh(arm,root,body):
    """New camp-only mesh, original skeleton rest matrices and object transforms."""
    action=arm.animation_data.action if arm.animation_data else None
    if arm.animation_data:arm.animation_data.action=None
    for pb in arm.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update();bpy.ops.object.select_all(action='DESELECT')
    for o in [arm,root,body]:o.select_set(True)
    bpy.context.view_layer.objects.active=arm
    old=root.name;root.name='Armature'
    names=[m.name for m in body.data.materials]
    for m,n in zip(body.data.materials,['M_Steward','M_EyePlate']):m.name=n
    bpy.ops.export_scene.fbx(filepath=str(OUT/'Steward_Service_Mars_SK.fbx'),use_selection=True,
        object_types={'EMPTY','ARMATURE','MESH'},axis_forward='-Z',axis_up='Y',global_scale=1,
        apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',add_leaf_bones=False,
        primary_bone_axis='Y',secondary_bone_axis='X',use_armature_deform_only=False,
        bake_anim=False,armature_nodetype='NULL',mesh_smooth_type='FACE',path_mode='STRIP')
    for m,n in zip(body.data.materials,names):m.name=n
    root.name=old
    if action:arm.animation_data.action=action

def orient_palm(arm,side,sign):
    """Two axes remove the unconstrained roll from a single-vector wrist aim.

    The source's bone tails are auto-rig display axes, not finger directions.
    Use actual knuckle landmarks: long axis wrist->middle, side index->pinky.
    Thumbs face the centre symmetrically; fingers rise onto the upper roll.
    """
    wrist=world_head(arm,'hand_'+side)
    long=(world_head(arm,'middle_01_'+side)-wrist).normalized()
    across=world_head(arm,'index_01_'+side)-world_head(arm,'pinky_01_'+side)
    across=(across-long*across.dot(long)).normalized()
    desired_long=Vector((-sign*.55,-.15,.82)).normalized()
    desired_across=Vector((-sign,0,0))
    desired_across=(desired_across-desired_long*desired_across.dot(desired_long)).normalized()
    before=Matrix((long,across,long.cross(across))).transposed()
    after=Matrix((desired_long,desired_across,desired_long.cross(desired_across))).transposed()
    rotate_world(arm,'hand_'+side,(after @ before.transposed()).to_quaternion())

def hold(arm,t):
    for pb in arm.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    breath=math.sin(t*2*math.pi*2)
    # Chest/head motion only; analytic arm solve restores exact stationary wrist contact afterward.
    rotate_world(arm,'spine_03',Quaternion((1,0,0),math.radians(.6*breath)))
    rotate_world(arm,'head',Quaternion((1,0,0),math.radians(3+.5*breath)))
    errors={}
    for side,sgn in [('l',1),('r',-1)]:
        upper,lower,hand='upperarm_'+side,'lowerarm_'+side,'hand_'+side
        a=world_head(arm,upper);b=world_head(arm,lower);c=world_head(arm,hand)
        target=wrist_target(sgn)
        l1,l2=(b-a).length,(c-b).length;d=(target-a).length
        assert abs(l1-l2)<d<l1+l2,(side,l1,l2,d)
        axis=(target-a).normalized();pole=Vector((sgn*.7,-.12,1.55))-a
        radial=(pole-axis*pole.dot(axis)).normalized()
        along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along))
        elbow=a+axis*along+radial*height
        aim_child(arm,upper,lower,elbow);aim_child(arm,lower,hand,target)
        orient_palm(arm,side,sgn)
        # Flexion happens around the horizontal roll axis, in world space. The
        # previous 12-degree distal-only pose left the hand visibly open.
        for finger in ['index','middle','ring','pinky']:
            for joint,angle in [('01',55),('02',65),('03',55)]:
                rotate_world(arm,finger+'_'+joint+'_'+side,Quaternion((1,0,0),math.radians(angle)))
        # Thumb comes from below the fingers and opposes their grip at the roll.
        thumb='thumb_01_'+side
        aim_child(arm,thumb,'thumb_02_'+side,Vector((sgn*.39,-.60,2.045)))
        aim_child(arm,'thumb_02_'+side,'thumb_03_'+side,Vector((sgn*.365,-.635,2.065)))
        errors[side]=(world_head(arm,hand)-target).length*100
    return errors

def export_animation(arm,root):
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);root.select_set(True)
    bpy.context.view_layer.objects.active=arm
    old=root.name;root.name='Armature'
    bpy.ops.export_scene.fbx(filepath=str(OUT/'Steward_Present_Mars_AS.fbx'),use_selection=True,
        object_types={'EMPTY','ARMATURE'},axis_forward='-Z',axis_up='Y',global_scale=1,
        apply_unit_scale=True,apply_scale_options='FBX_SCALE_NONE',add_leaf_bones=False,
        primary_bone_axis='Y',secondary_bone_axis='X',use_armature_deform_only=False,
        bake_anim=True,bake_anim_use_all_bones=True,bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,bake_anim_force_startend_keying=True,bake_anim_step=1,
        bake_anim_simplify_factor=0,armature_nodetype='NULL')
    root.name=old

def render(scene,arm,paper):
    # Existing exported materials have no exported texture: neutral body plus a dark face plate.
    for o in scene.objects:
        if o.type=='MESH' and o!=paper:
            for m in o.data.materials:
                if m:
                    m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
                    if p:
                        for link in list(p.inputs['Base Color'].links):m.node_tree.links.remove(link)
                        p.inputs['Base Color'].default_value=(.035,.025,.019,1) if 'Eye' in m.name else (.19,.155,.12,1)
                        texture=OUT/'Steward_BaseColor.tga'
                        if 'Eye' not in m.name and texture.exists():
                            tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(texture),check_existing=True)
                            m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.world=bpy.data.worlds.new('ReviewWorld');scene.world.color=(.12,.12,.12)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.01));floor=bpy.context.object;floor.data.materials.append(material('ReviewFloor',(.085,.095,.10)))
    for name,loc,power,size in [('Key',(3,-4,5),900,4),('Fill',(-3,-2,3),550,3),('Rim',(0,3,4),1000,3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1.5))-o.location).to_track_quat('-Z','Y').to_euler()
    d=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',d);scene.collection.objects.link(cam);scene.camera=cam
    d.type='ORTHO';d.ortho_scale=3.35
    for name,loc in [('Review_Front',(0,-7,2.05)),('Review_ThreeQuarter',(4,-6,2.7)),('Review_Side',(7,0,2.15))]:
        cam.location=loc;cam.rotation_euler=(Vector((0,-.12,1.45))-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
    # Close-up physical contact view uses the exact same pose, without UI.
    d.ortho_scale=1.55
    cam.location=(2.4,-3,2.25);cam.rotation_euler=(Vector((0,-.47,2.0))-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.filepath=str(OUT/'Review_GripDetail.png');bpy.ops.render.render(write_still=True)

def main():
    OUT.mkdir(parents=True,exist_ok=True);source_hash=hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    parchment_only='--parchment-only' in sys.argv
    protected={name:hashlib.sha256((OUT/name).read_bytes()).hexdigest() for name in ['Steward_Service_Mars_SK.fbx','Steward_Present_Mars_AS.fbx']} if parchment_only else {}
    bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene
    bpy.ops.import_scene.fbx(filepath=str(SOURCE));arm=next(o for o in scene.objects if o.type=='ARMATURE');root=arm.parent
    body=next(o for o in scene.objects if o.type=='MESH')
    weight_report=correct_garment_weights(body)
    if not parchment_only:export_service_mesh(arm,root,body)
    bones=[b.name for b in arm.data.bones];rest={b.name:[list(r) for r in b.matrix_local] for b in arm.data.bones}
    assert root is not None and abs(root.scale.x-.01)<1e-6
    scene.render.fps=FPS;scene.frame_start=0;scene.frame_end=END
    arm.animation_data_create();act=bpy.data.actions.new('Steward_Present_Mars_AS');arm.animation_data.action=act
    maximum=0
    for frame in range(0,END+1,5):
        errors=hold(arm,(frame%END)/END);maximum=max(maximum,*errors.values())
        for pb in arm.pose.bones:
            pb.rotation_mode='QUATERNION'
            pb.keyframe_insert('rotation_quaternion',frame=frame,group=pb.name)
            pb.keyframe_insert('location',frame=frame,group=pb.name)
            pb.keyframe_insert('scale',frame=frame,group=pb.name)
    for fc in act.layers[0].strips[0].channelbags[0].fcurves:
        for k in fc.keyframe_points:k.interpolation='LINEAR'
    assert maximum<.05,maximum
    assert rest=={b.name:[list(r) for r in b.matrix_local] for b in arm.data.bones}
    scene.frame_set(0)
    if not parchment_only:export_animation(arm,root)
    paper=parchment();bpy.ops.object.select_all(action='DESELECT');paper.select_set(True);bpy.context.view_layer.objects.active=paper
    # Default metre scene exports the FBX unit conversion itself. Keep global scale 1.
    bpy.ops.export_scene.fbx(filepath=str(OUT/'ServiceParchment_Mars_SM.fbx'),use_selection=True,
        object_types={'MESH'},axis_forward='-Y',axis_up='Z',global_scale=1,apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_NONE',bake_anim=False,use_triangles=True,mesh_smooth_type='FACE',path_mode='STRIP')
    paper.location=PAPER_AT;paper.rotation_euler.z=-math.pi/2
    wrist={s:[round(v*100,3) for v in world_head(arm,'hand_'+s)] for s in ['l','r']}
    manifest=dict(source_sha256=source_hash,skeleton_bones=bones,source_height_cm=289.858,
        animation=dict(file='Steward_Present_Mars_AS.fbx',fps=FPS,frames=END,duration_seconds=6,root_motion=False),
        prop=dict(file='ServiceParchment_Mars_SM.fbx',local_front_ue='+X',width_cm=ROLL_WIDTH*100,reading_size_cm=[READ_WIDTH*100,READ_HEIGHT*100],
                  component_relative_location_cm=[0,PAPER_FRONT*100,PAPER_HEIGHT*100],component_relative_rotation_pyr=[0,90,0],
                  assembly_root_relative_location_cm=[PAPER_FRONT*100,0,PAPER_HEIGHT*100],assembly_root_relative_rotation_pyr=[0,0,0],
                  tail_floor_height_cm=TAIL_FLOOR_HEIGHT*100,scale=[1,1,1]),
        widget=dict(parent='parchment',location_cm=[.25,0,WIDGET_CENTRE_Z*100],rotation_pyr=[0,0,0],size_cm=[SAFE_WIDTH*100,SAFE_HEIGHT*100],
                    draw_size=[800,900],scale=WIDGET_SCALE),
        hold_sockets_component_cm={s:[v[0],-v[1],v[2]] for s,v in wrist.items()},
        hold_sockets_assembly_root_cm={s:[-v[1],-v[0],v[2]] for s,v in wrist.items()},
        service_mesh=dict(file='Steward_Service_Mars_SK.fbx',skeleton='existing Steward_Mars_SKEL',material_slots=['M_Steward','M_EyePlate'],
                          garment_weight_vertices=weight_report['changed_vertices']),
        validation=dict(bones_preserved=True,rest_matrices_preserved=True,max_wrist_error_cm=maximum,
                        source_preserved=source_hash==hashlib.sha256(SOURCE.read_bytes()).hexdigest()),
        limits=['Body preview uses exported base color when available','Hand skin contact requires Unreal review',
                'Animation skeleton compatibility requires Unreal import and playback review'])
    (OUT/'art_manifest.json').write_text(json.dumps(manifest,indent=2))
    render(scene,arm,paper);bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'StewardService_Review.blend'))
    if protected:
        assert all(hashlib.sha256((OUT/n).read_bytes()).hexdigest()==h for n,h in protected.items()),'Protected character output changed'
        (OUT/'protected_character_hashes.json').write_text(json.dumps(dict(unchanged=True,sha256=protected),indent=2))
    print('STEWARD_SERVICE_ART_OK',json.dumps(manifest))

if __name__=='__main__':main()
