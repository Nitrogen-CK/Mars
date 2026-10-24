"""Source A/I artwork through the shared Builder; no runtime or Blender calls.

Reference identity follows model_catalog.json, not conflicting district labels.
Geometry is in metres, front -Y; import reflects Y. Runtime pivots remain owned
by their existing actors. The wrapper normalizes to the declared envelope.
"""
import math


OWNED = {'A05','A06','A07','A08','A09','A11','A12','A13','A19','A20','A23','A24',
         'I01','I02','I04','I05','I06','I08','I09','I10','I11','I12','I13',
         'I15','I16','I17','I18','I19','I20'}


def _profile(b, name, points, depth, material, y=0):
    """Closed prism along Y; an individual stone, never an aperture cap."""
    n=len(points)
    vertices=[(x,y+dy,z) for dy in (-depth/2,depth/2) for x,z in points]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return b.mesh(name,vertices,faces,material)


def _octagon(w,d,chamfer=.14):
    c=min(w,d)*chamfer
    return [(-w/2+c,-d/2),(w/2-c,-d/2),(w/2,-d/2+c),(w/2,d/2-c),
            (w/2-c,d/2),(-w/2+c,d/2),(-w/2,d/2-c),(-w/2,-d/2+c)]


def _annulus_y(b,name,outer,inner,depth,material,y=0):
    """Matching XZ loops; annular faces leave the center physically open."""
    n=len(outer)
    assert n==len(inner)
    vertices=[(x,y+dy,z) for dy in (-depth/2,depth/2) for loop in (outer,inner) for x,z in loop]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)]
    return b.mesh(name,vertices,faces,material)


def _ring_y(b,name,at,outer,inner,depth,material,sides=12):
    x,y,z=at
    a=[(x+outer*math.cos(i*math.tau/sides),z+outer*math.sin(i*math.tau/sides)) for i in range(sides)]
    c=[(x+inner*math.cos(i*math.tau/sides),z+inner*math.sin(i*math.tau/sides)) for i in range(sides)]
    return _annulus_y(b,name,a,c,depth,material,y)


def _arch(b,w,d,h,clear,material,window=False):
    """Jamb courses and separate voussoirs; no backing across the opening."""
    t=(w-clear)/2
    assert t>0
    spring=h-w/2
    assert spring>0
    rows=max(2,round(spring/.55))
    for sign in (-1,1):
        for row in range(rows):
            b.box('ArchJamb', (sign*(clear/2+t/2),0,(row+.5)*spring/rows),
                  (t,d,spring/rows-.008),material,.035)
    for i in range(11):
        a=math.pi*i/11+.002;c=math.pi*(i+1)/11-.002
        p=[(w/2*math.cos(a),spring+w/2*math.sin(a)),
           (w/2*math.cos(c),spring+w/2*math.sin(c)),
           (clear/2*math.cos(c),spring+clear/2*math.sin(c)),
           (clear/2*math.cos(a),spring+clear/2*math.sin(a))]
        _profile(b,'ArchVoussoir',p,d,material)
    if window:
        b.flag('physical_window_aperture',True)
    b.flag('clear_width_m',clear)
    b.flag('clear_spring_height_m',spring)
    b.flag('open_aperture_no_backing',True)


def _bands(b,w,d,h,material):
    for z in (.22*h,.72*h):
        b.box('FrontRail',(0,-d*.34,z),(w,d*.32,h*.075),material,.012)


def _gate_leaf(b,w,d,h,material,pointed=False):
    count=max(4,round(w/.28))
    thickness=min(.09,w/count*.28)
    for i in range(count):
        x=-w/2+thickness/2+i*(w-thickness)/(count-1)
        z0=.12*h if pointed else 0
        b.box('VerticalGateBar',(x,0,(h+z0)/2),(thickness,d*.48,h-z0),material,.014)
        if pointed:
            _profile(b,'BluntBarToe',[(x-thickness/2,z0),(x+thickness/2,z0),(x,0)],d*.48,material)
    _bands(b,w,d,h,material)
    b.flag('moving_leaf_only_no_static_surround',True)
    b.flag('runtime_binding','Existing gate component owns motion, collision, travel and pivot adapter')


def _plinth(b,w,d,h,stone,metal=None):
    b.box('PlinthFoot',(0,0,h*.12),(w,d,h*.24),stone,.045)
    b.box('PlinthCourse',(0,0,h*.53),(w*.91,d*.91,h*.60),stone,.04)
    # Straps sit on the cap; coincident top faces rendered as black lanes.
    b.box('BroadCap',(0,0,h*(.89 if metal else .91)),
          (w,d,h*(.14 if metal else .18)),stone,.025)
    if metal:
        for x in (-w*.38,w*.38):
            b.box('CapStrap',(x,0,h*.98),(w*.075,d*.96,h*.04),metal,.008)


def _lever_arm(b,w,d,h,wood,iron):
    # Moving arm/hub only: a static wall plate must not rotate with this mesh.
    hinge=(0,0,h*.18)
    b.cyl('HingeHub',hinge,min(w*.24,h*.13),d,iron,'Y',10)
    b.rod('LeverArm',hinge,(w*.24,-d*.12,h*.82),w*.075,wood,sides=6)
    b.box('Grip',(w*.24,-d*.12,h*.88),(w*.45,d*.72,h*.24),iron,.03)
    b.flag('lever_arm_only_no_wall_backplate',True)
    b.flag('requires_runtime_hinge_adapter',True)
    b.flag('runtime_binding','Map production bottom-center mesh to existing actor hinge/grip; do not infer actor pivot from artist view')


def _vat(b,w,d,h,wood,iron,glass):
    outer=_octagon(w,d);inner=_octagon(w-.22,d-.22)
    n=len(outer);base=.12*h
    vertices=[(x,y,z) for z in (0,h) for loop in (outer,inner) for x,y in loop]
    faces=[]
    for i in range(n):
        j=(i+1)%n
        faces += [(i,j,2*n+j,2*n+i),(n+i,3*n+i,3*n+j,n+j),
                  (2*n+i,2*n+j,3*n+j,3*n+i),(i,n+i,n+j,j)]
    b.mesh('OpenVatWallAndRim',vertices,faces,wood)
    b.extrude('RecessedVatFloor',inner,base*.25,base,wood)
    # Interior material lies at the bottom, never a lid filling the open mouth.
    b.mesh('ShallowInteriorCarrier',[(x*.995,y*.995,base+.005)for x,y in inner],
           [tuple(range(n))],glass)
    for z in (h*.2,h*.72):
        for i in range(n):
            j=(i+1)%n
            a=(outer[i][0],outer[i][1],z);c=(outer[j][0],outer[j][1],z)
            # Rods form continuous flat-shaded edge straps without a hidden cap.
            b.rod('VatIronBand',a,c,.035,iron,sides=4)
    b.flag('open_mouth_real_inner_walls',True)
    b.flag('inner_floor_height_m',base)
    b.flag('lid_separate_source_id','I13')
    b.flag('collision','NoCollision; existing vat actor owns hand/pack interaction')


def build(b,part):
    sid=part['source_id']
    if sid not in OWNED:
        raise ValueError('Architecture/interaction family does not own '+sid)
    w,d,h=b.size
    mats=part['materials'];primary=mats[0]
    secondary=mats[1] if len(mats)>1 else primary
    b.flag('source_id',sid)
    b.flag('collision','NoCollision visual skin; retained source authoritative')
    b.flag('production_pivot',part.get('production_pivot',part['pivot']))
    b.flag('source_pivot_contract',part.get('source_pivot_contract',''))
    b.flag('front','Blender -Y; imported Unreal +Y')
    if sid in ('A05','A06'):
        levels=((0,.27,1),(.27,.72,.90),(.72,1,.78)) if sid=='A05' else ((0,.26,.72),(.26,.60,.84),(.60,.85,.94),(.85,1,1))
        for a,c,span in levels:
            b.box('SteppedPierCourse',(0,0,h*(a+c)/2),(w*span,d*span,h*(c-a)),primary,.035)
    elif sid in ('A07','A08'):
        _arch(b,w,d,h,3 if sid=='A07' else 2.5,primary)
    elif sid=='A09':
        _profile(b,'BroadKeystone',[(-w*.32,0),(w*.32,0),(w/2,h),(-w/2,h)],d,primary)
    elif sid=='A11':
        # One quarter rib, not a whole narrow arch stretched across the bridge.
        t=min(w,h)*.19
        for i in range(7):
            a=i*math.pi/14;c=(i+1)*math.pi/14
            p=[(w*(1-math.cos(a)),h*math.sin(a)),(w*(1-math.cos(c)),h*math.sin(c)),
               ((w-t)*(1-math.cos(c))+t,(h-t)*math.sin(c)),
               ((w-t)*(1-math.cos(a))+t,(h-t)*math.sin(a))]
            _profile(b,'FossilRibSegment',p,d,primary)
        b.flag('sectional_rib_only',True)
        b.flag('placement_contract','Repeat/mirror on retained bridge exterior; preserve its full 3m clear deck')
    elif sid=='A12':
        b.box('BonePostFoot',(0,0,h*.08),(w,d,h*.16),primary,.03)
        b.box('BonePostShaft',(0,0,h*.48),(w*.64,d*.64,h*.66),primary,.035)
        b.cone('BroadBonePostCap',(0,0,h*.89),w*.5,w*.20,h*.22,primary,sides=4)
    elif sid=='A13':
        for i in range(3):
            b.box('BoneCoping',(w*(i-1)/3,0,h/2),(w/3-.008,d,h),primary,.035)
    elif sid=='A19':
        b.box('FlushThreshold',(0,0,-h/2),(w,d,h),primary,.004)
        b.flag('walking_plane_z',0)
        b.flag('thickness_below_walk_plane',True)
    elif sid=='A20':
        # Closed burial niche, not a new doorway. Pointed slab and frame are static.
        _profile(b,'ClosedNicheBacking',[(-w*.39,0),(w*.39,0),(w*.39,h*.68),(0,h*.94),(-w*.39,h*.68)],d*.45,primary,y=d*.25)
        for sign in (-1,1):
            b.box('NicheJamb',(sign*w*.43,0,h*.395),(w*.14,d,h*.57),primary,.025)
            b.rod('PointedNicheHead',(sign*w*.43,0,h*.68),(0,0,h),w*.065,secondary,sides=4)
        b.box('NicheSill',(0,0,h*.055),(w,d,h*.11),primary,.02)
        b.flag('closed_decorative_niche_no_passage',True)
    elif sid=='A23':
        p=[(-w/2,0),(-w*.17,h*.08),(w*.14,0),(w/2,h*.08),
           (w/2,h*.90),(w*.18,h),(-w*.12,h*.92),(-w/2,h)]
        _profile(b,'IrregularSeamCover',p,d,primary)
        b.flag('never_cover_source_window_cut',True)
    elif sid=='A24':
        _arch(b,w,d,h,w*.72,primary,True)
    elif sid=='I01':
        _plinth(b,w,d,h,primary,secondary)
        b.flag('existing_key_pickup_only',True)
    elif sid=='I02':
        b.box('BlankPanelBack',(0,d*.30,h*.5),(w*.91,d*.40,h*.91),primary,.035)
        for x in (-w*.45,w*.45):
            b.box('PanelSide',(x,0,h*.5),(w*.10,d,h*.78),primary,.035)
        for z in (h*.055,h*.945):
            b.box('PanelCrossbar',(0,0,z),(w,d,h*.11),secondary,.025)
        centers=[]
        for x in (-w*.29,0,w*.29):
            _ring_y(b,'EmptyDialSeat',(x,-d*.44,h*.68),w*.12,w*.087,d*.10,secondary)
            centers.append([x,-d*.44,h*.68])
        b.flag('empty_dial_seats_no_glyphs',True)
        b.flag('dial_socket_centres_before_finish_m',centers)
        b.flag('runtime_binding','Existing panel owns phrase, sockets, dials and rewards; socket adapter required')
    elif sid=='I04':
        b.cyl('Axle',(0,0,0),min(w,h)*.31,d,primary,'Y',10)
        for y in (-d*.42,d*.42):
            b.cyl('AxleEndCollar',(0,y,0),min(w,h)/2,d*.12,primary,'Y',10)
        b.flag('axis','Y');b.flag('solid_axle_not_hollow_pipe',True)
        b.flag('production_to_actor_axis_adapter','Imported +Y to actor +X uses yaw -90deg if actor contract requires +X')
    elif sid in ('I05','I09','I18'):
        _gate_leaf(b,w,d,h,primary,pointed=sid=='I05')
        if sid=='I18':
            b.flag('shared_seal_separate_source_id','P29')
            b.flag('source_p3_latches_no_hold_required',True)
    elif sid=='I06':
        b.box('PlateBody',(0,0,h*.42),(w,d,h*.84),primary,.045)
        rim=min(w,d)*.075
        for x in (-w/2+rim/2,w/2-rim/2):
            b.box('PlateEdge',(x,0,h*.92),(rim,d,h*.16),secondary,.015)
        for y in (-d/2+rim/2,d/2-rim/2):
            b.box('PlateEdge',(0,y,h*.92),(w-rim*2,rim,h*.16),secondary,.015)
        b.flag('wide_empty_plate_center',True)
        b.flag('source_p3_latches_no_hold_required',True)
    elif sid=='I08':
        b.cyl('BlankDialFace',(0,0,0),w/2,d,primary,'Y',12)
        _ring_y(b,'DialRim',(0,-d*.49,0),w*.49,w*.42,d*.18,secondary)
        b.flag('axis','Y');b.flag('blank_runtime_glyph_face',True)
    elif sid in ('I10','I15'):
        wood=secondary if secondary=='TX08' else primary
        _lever_arm(b,w,d,h,wood,primary)
        if sid=='I15':b.flag('backside_only_no_hall_handle',True)
    elif sid=='I11':
        # Matching 12-point loops yield a real traditional keyhole aperture.
        outer=[(-w*.30,-h/2),(w*.30,-h/2),(w/2,-h*.32),(w/2,0),
               (w/2,h*.32),(w*.30,h/2),(0,h/2),(-w*.30,h/2),
               (-w/2,h*.32),(-w/2,0),(-w/2,-h*.32),(-w*.40,-h*.44)]
        inner=[(-w*.07,-h*.28),(w*.07,-h*.28),(w*.06,-h*.01),(w*.18,h*.05),
               (w*.20,h*.18),(w*.13,h*.29),(0,h*.33),(-w*.13,h*.29),
               (-w*.20,h*.18),(-w*.18,h*.05),(-w*.06,-h*.01),(-w*.065,-h*.15)]
        _annulus_y(b,'RedKeyEscutcheon',outer,inner,d,primary)
        b.flag('physical_keyhole_aperture',True)
        b.flag('no_new_key_type',True)
    elif sid=='I12':
        _vat(b,w,d,h,primary,secondary,mats[2])
    elif sid=='I13':
        # Flat chamfered lid and low handle are separate from the vat mouth.
        b.extrude('OctagonalVatLid',_octagon(w,d),0,h*.55,primary)
        for x in (-w*.30,w*.30):
            b.box('LidStrap',(x,0,h*.59),(w*.055,d*.94,h*.10),secondary,.008)
        for x in (-w*.065,w*.065):
            b.box('HandleFoot',(x,0,h*.75),(w*.035,d*.10,h*.30),secondary,.006)
        b.box('LidHandle',(0,0,h*.94),(w*.16,d*.10,h*.12),secondary,.008)
        b.flag('separate_lid_never_join_vat',True)
        b.flag('runtime_handle_adapter_required',True)
    elif sid in ('I16','I17'):
        for x in (-w*.44,w*.44):
            b.box('LadderRail',(x,0,h/2),(w*.12,d*.72,h*.76),primary,.018)
            for z in (.06*h,.94*h):
                b.box('LadderEndShoe',(x,0,z),(w*.13,d,h*.12),secondary,.012)
        n=3 if sid=='I16' else 4
        for i in range(n):
            z=h*(i+.5)/n
            b.box('LadderRung',(0,0,z),(w*.82,d*.72,min(.09,h*.09)),primary,.012)
        b.flag('segment_height_m',h)
        b.flag('existing_ladder_endpoints_only',True)
    elif sid=='I19':
        points=[(w*.5*math.cos(i*math.tau/16),h*.5+h*.5*math.sin(i*math.tau/16))for i in range(16)]
        _profile(b,'VaultDoorLeaf',points,d*.60,primary,y=d*.20)
        inner=[(x*.86,h/2+(z-h/2)*.86)for x,z in points]
        _annulus_y(b,'DoorLeafOuterRim',points,inner,d*.22,primary,y=-d*.16)
        for i in range(8):
            a=i*math.tau/8
            b.rod('DoorRadialStrap',(0,-d*.20,h*.5),(w*.44*math.cos(a),-d*.20,h*.5+h*.44*math.sin(a)),.045,primary,sides=4)
        b.cyl('DoorCenterBoss',(0,-d*.20,h*.5),min(w,h)*.12,d*.20,secondary,'Y',8)
        b.flag('moving_leaf_only_no_static_surround',True)
        b.flag('source_opening_span_m',2.5)
        b.flag('requires_runtime_hinge_adapter',True)
        b.flag('runtime_binding','Query existing door hinge/sweep; never derive its pivot from this bottom-center artist mesh')
    elif sid=='I20':
        _plinth(b,w,d,h,primary)
        b.flag('existing_pack_only_no_duplicate',True)
