"""Chunky, static Chain Crossing dressing, CCS60 through CCS85 only."""

import math


TAU = 2.0 * math.pi


def _tube(b, name, points, radius, mat, sides=6, closed=False):
    """Small low-poly swept tube; transport a frame without Blender operators."""
    from mathutils import Vector
    pts = [Vector(p) for p in points]
    verts, faces = [], []
    for i, p in enumerate(pts):
        before = pts[(i - 1) % len(pts)] if closed or i else p
        after = pts[(i + 1) % len(pts)] if closed or i + 1 < len(pts) else p
        tangent = (after - before).normalized()
        ref = Vector((0, 0, 1)) if abs(tangent.z) < .9 else Vector((0, 1, 0))
        side = tangent.cross(ref).normalized()
        up = tangent.cross(side).normalized()
        for j in range(sides):
            a = TAU * j / sides
            verts.append(tuple(p + radius * (math.cos(a) * side + math.sin(a) * up)))
    for i in range(len(pts) if closed else len(pts) - 1):
        nxt = (i + 1) % len(pts)
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((i*sides+j, i*sides+k, nxt*sides+k, nxt*sides+j))
    if not closed:
        faces.extend([tuple(reversed(range(sides))), tuple((len(pts)-1)*sides+j for j in range(sides))])
    return b.mesh(name, verts, faces, mat)


def _rings(b, name, profiles, mat, sides=12, loc=(0, 0, 0), cap=True):
    """Lathe elliptical profiles; folded-back profile creates a hollow vessel."""
    cyclic = profiles[0] == profiles[-1]
    if cyclic:
        profiles = profiles[:-1]
    verts = [(loc[0]+rx*math.cos(TAU*i/sides), loc[1]+ry*math.sin(TAU*i/sides), loc[2]+z)
             for rx, ry, z in profiles for i in range(sides)]
    faces = []
    for row in range(len(profiles) if cyclic else len(profiles)-1):
        nxt = (row+1) % len(profiles)
        for i in range(sides):
            j = (i+1) % sides
            faces.append((row*sides+i, row*sides+j, nxt*sides+j, nxt*sides+i))
    if cap and not cyclic:
        faces.extend([tuple(reversed(range(sides))), tuple((len(profiles)-1)*sides+i for i in range(sides))])
    return b.mesh(name, verts, faces, mat)


def _band(b, name, rx, ry, z, height, thickness, mat, sides=12):
    return _rings(b, name, [(rx, ry, z), (rx, ry, z+height),
                           (rx-thickness, ry-thickness, z+height),
                           (rx-thickness, ry-thickness, z), (rx, ry, z)], mat, sides, cap=False)


def _vertical_plate(b, name, outline, depth, mat, y=0):
    n = len(outline)
    verts = [(x, y-depth/2, z) for x, z in outline] + [(x, y+depth/2, z) for x, z in outline]
    faces = [tuple(range(n)), tuple(reversed(range(n, n*2)))]
    faces += [(i, i+n, (i+1)%n+n, (i+1)%n) for i in range(n)]
    return b.mesh(name, verts, faces, mat)


def _wheel_chain(b, cx, y, cz, radius, mat):
    b.torus('WheelEmblemRim', (cx, y, cz), radius, radius*.11, mat, axis='Y', major_segments=12)
    b.cyl('WheelEmblemHub', (cx, y, cz), radius*.16, radius*.18, mat, axis='Y', sides=8)
    for i in range(6):
        a = TAU*i/6
        b.rod('WheelEmblemSpoke', (cx, y, cz), (cx+radius*.92*math.cos(a), y, cz+radius*.92*math.sin(a)), radius*.065, mat, sides=4)
    for i in range(4):
        obj = b.torus('HangingChainEmblem', (cx+radius*.8, y, cz-radius*.75-i*radius*.44),
                      radius*.20, radius*.055, mat, axis='Y', major_segments=8)
        # Flattened interlocking silhouettes stay legible against the plaque.
        obj.scale.x = .70
        obj.scale.z = 1.15


def _cloth(b, name, w, d, h, mat):
    # Two broad ridges across a sparse irregular grid, with actual edge thickness.
    verts = []
    for j in range(5):
        for i in range(5):
            x = (i/4-.5)*w
            y = (j/4-.5)*d
            if i in (0, 4):
                x += (.035*w if j%2 else -.02*w)
            if j in (0, 4):
                y += (.03*d if i%2 else -.02*d)
            z = h*(.13 + (.75 if i in (1, 3) and j not in (0, 4) else .06))
            verts.append((x, y, z))
    verts += [(x, y, z-h*.12) for x, y, z in verts]
    faces = []
    for j in range(4):
        for i in range(4):
            a = j*5+i
            faces.extend([(a, a+1, a+6), (a, a+6, a+5),
                          (a+25, a+31, a+26), (a+25, a+30, a+31)])
    boundary = list(range(5)) + [9, 14, 19, 24] + [23, 22, 21, 20] + [15, 10, 5]
    for i, a in enumerate(boundary):
        c = boundary[(i+1)%len(boundary)]
        faces.append((a, a+25, c+25, c))
    b.mesh(name, verts, faces, mat)


def build(b, part):
    ident = b.id
    if ident not in {f'CCS{i:02d}' for i in range(60, 86)}:
        raise ValueError(f'dressing does not own {ident}')
    w, d, h = b.size
    iron, wood, cloth = 'TX09', 'TX08', 'TX12'
    n = int(ident[3:])

    if n == 60:
        # Four open sides, rather than a dark box masquerading as a lantern.
        b.box('LanternFoot', (0, 0, h*.045), (w*.91, d*.91, h*.09), iron, .008)
        b.box('LanternBasePan', (0, 0, h*.115), (w, d, h*.075), iron, .006)
        for x in (-w*.43, w*.43):
            for y in (-d*.42, d*.42):
                b.box('CageCorner', (x, y, h*.43), (w*.075, d*.095, h*.58), iron, .003)
                b.box('CornerCollar', (x, y, h*.16), (w*.12, d*.15, h*.06), iron, .003)
        for z in (h*.17, h*.72):
            for x in (-w*.44, w*.44):
                b.box('SideFrame', (x, 0, z), (w*.09, d, h*.045), iron, .003)
            for y in (-d*.44, d*.44):
                b.box('DoorFrame', (0, y, z), (w, d*.12, h*.045), iron, .003)
        verts = [(-w*.53,-d*.53,h*.75), (w*.53,-d*.53,h*.75),
                 (w*.53,d*.53,h*.75), (-w*.53,d*.53,h*.75),
                 (-w*.10,-d*.10,h*.89), (w*.10,-d*.10,h*.89),
                 (w*.10,d*.10,h*.89), (-w*.10,d*.10,h*.89)]
        b.mesh('PitchedRoof', verts, [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7),(3,2,1,0)], iron)
        b.torus('HangingEye', (0,0,h*.945), h*.043, h*.012, iron, axis='Y')
        b.cyl('WickSocket', (0,0,h*.185), w*.08, h*.055, iron, sides=8)
        b.box('DoorLatch', (w*.36,-d*.54,h*.43), (w*.09,d*.10,h*.075), iron, .002)

    elif n == 61:
        # Open-top insert, independent of iron housing and flame.
        _rings(b, 'GlassInsert', [(w*.43,d*.43,0),(w*.5,d*.5,h),(w*.48,d*.48,h),
                                 (w*.41,d*.41,h*.025)], 'Glass', sides=6)

    elif n == 62:
        b.box('WallBackplate', (0,d*.42,h*.5), (w*.66,d*.13,h), iron, .009)
        b.box('BracketArm', (0,-d*.02,h*.74), (w*.45,d*.88,h*.14), iron, .006)
        b.rod('BracketBrace', (0,d*.34,h*.15), (0,-d*.27,h*.7), w*.085, iron, sides=4)
        pts = [(0,-d*.40,h*.72),(0,-d*.40,h*.36),(0,-d*.49,h*.26),
               (0,-d*.57,h*.33),(0,-d*.57,h*.44)]
        _tube(b, 'OpenJHook', pts, w*.095, iron)
        for z in (h*.17,h*.85):
            b.cyl('WallBolt', (0,d*.33,z), w*.10, d*.05, iron, axis='Y', sides=6)

    elif n == 63:
        b.box('SconceWallPlate', (0,d*.40,h*.5), (w*.42,d*.15,h), iron, .012)
        b.box('SconceArm', (0,0,h*.44), (w*.20,d*.84,h*.11), iron, .006)
        b.rod('UnderBrace', (0,d*.34,h*.18), (0,-d*.29,h*.43), w*.055, iron, sides=4)
        _rings(b, 'HollowFireDish', [(w*.18,d*.18,0),(w*.44,d*.36,h*.2),
                                    (w*.38,d*.30,h*.2),(w*.13,d*.13,h*.045)], iron, sides=10,
               loc=(0,-d*.25,h*.48))
        _band(b,'DishLip',w*.44,d*.36,h*.675,h*.025,w*.035,iron,10).location.y = -d*.25
        b.cyl('FlameSocket', (0,-d*.25,h*.55), w*.075,h*.06,iron,sides=8)

    elif n == 64:
        # Shaped vertical carrier; material owns future animation.
        outline = [(-w*.45,0),(w*.40,0),(w*.5,h*.24),(w*.30,h*.52),
                   (w*.22,h*.36),(w*.18,h*.73),(-w*.06,h),(-w*.15,h*.65),
                   (-w*.29,h*.40),(-w*.36,h*.60),(-w*.5,h*.21)]
        _vertical_plate(b, 'FlameSilhouetteCarrier', outline, d, 'FX_Flame')
        b.flag('card', True)

    elif n == 65:
        b.box('NicheStoneBack', (0,d*.36,h*.5), (w*.82,d*.23,h), 'TX01', .035)
        b.box('LanternRestLedge', (0,-d*.08,h*.48), (w,d*.84,h*.11), 'TX08', .015)
        for x in (-w*.30,w*.30):
            b.box('RestWallStrap', (x,d*.21,h*.31), (w*.10,d*.07,h*.53), iron, .003)
            b.box('RestUnderArm', (x,-d*.06,h*.405), (w*.10,d*.69,h*.07), iron,.003)
            b.rod('RestBrace', (x,d*.18,h*.08), (x,-d*.36,h*.40), w*.04,iron,sides=4)

    elif n == 66:
        # Twelve readable individual staves around a closed barrel.
        count = 12
        levels = [(0,.79),(.20,.94),(.52,1),(.83,.91),(1,.79)]
        for i in range(count):
            a0, a1 = TAU*(i+.018)/count, TAU*(i+.982)/count
            verts=[]
            for z,r in levels:
                verts += [(w*.5*r*math.cos(a),d*.5*r*math.sin(a),h*z) for a in (a0,a1)]
            faces=[(2*j,2*j+1,2*j+3,2*j+2) for j in range(len(levels)-1)]
            verts += [(x*.91,y*.91,z) for x,y,z in verts]
            for j in range(len(levels)-1):
                a=2*j
                faces.extend([(a+10,a+12,a+13,a+11),(a,a+2,a+12,a+10),
                              (a+1,a+11,a+13,a+3)])
            faces.extend([(0,10,11,1),(8,9,19,18)])
            b.mesh('BarrelStave',verts,faces,wood)
        for z,r in ((.17,.93),(.78,.95)):
            _band(b,'BroadIronHoop',w*.5*r,d*.5*r,h*z,h*.075,w*.035,iron)
        _rings(b,'RecessedClosedTop',[(w*.385,d*.385,h*.965),(w*.385,d*.385,h*.975)],wood)
        _rings(b,'BarrelBottom',[(w*.385,d*.385,0),(w*.385,d*.385,h*.03)],wood)
        for x in (-.22,0,.22):
            extent=math.sqrt(max(.01,.37**2-x*x))
            b.box('LidBoardSeam',(w*x,0,h*.977),(w*.009,d*extent*2,h*.003),'TX07',0)

    elif n == 67:
        # Body, visible interior, and offset reusable lid within one collection.
        b.box('CrateBottom',(0,0,h*.04),(w*.88,d*.88,h*.08),wood,.006)
        for j in range(4):
            z=h*(.14+j*.185)
            for y in (-d*.46,d*.46):
                b.box('FrontBackBoard',(0,y,z),(w,d*.075,h*.175),wood,.007)
            for x in (-w*.46,w*.46):
                b.box('SideBoard',(x,0,z),(w*.075,d*.84,h*.175),wood,.007)
        for x in (-w*.41,w*.41):
            for y in (-d*.48,d*.48):
                b.box('CornerUpright',(x,y,h*.4),(w*.11,d*.09,h*.8),wood,.008)
        for y in (-d*.535,d*.535):
            b.rod('CrateDiagonalBrace',(-w*.36,y,h*.14),(w*.36,y,h*.69),w*.045,wood,sides=4)
        # Raised slightly from the rim so construction and separate lid read in view.
        for j in range(4):
            b.box('ReusableLidBoard',(0,(j-1.5)*d*.235,h*.89),(w,d*.23,h*.085),wood,.006)
        for x in (-w*.38,w*.38):
            b.box('LidCrossBatten',(x,0,h*.955),(w*.12,d,h*.08),wood,.006)
        b.flag('variation','body_and_reusable_lid')

    elif n == 68:
        profiles=[(.31,.31,0),(.46,.47,.12),(.50,.5,.36),(.38,.39,.62),(.12,.12,.80),(.13,.13,.85),(.29,.28,.99)]
        verts=[]
        for j,(rx,ry,z) in enumerate(profiles):
            for i in range(10):
                angle=TAU*i/10
                fold=1+(.08 if i%3==0 else -.025)
                verts.append((w*rx*fold*math.cos(angle),d*ry*fold*math.sin(angle),h*z+(h*.02*(i%2) if j==6 else 0)))
        faces=[]
        for j in range(6):
            for i in range(10):
                k=(i+1)%10
                faces.extend([(j*10+i,j*10+k,(j+1)*10+k), (j*10+i,(j+1)*10+k,(j+1)*10+i)])
        faces.append(tuple(reversed(range(10))))
        b.mesh('FacetedTiedSack',verts,faces,cloth)
        for z in (.805,.838):
            b.torus('SackTie',(0,0,h*z),w*.13,w*.023,'TX14',major_segments=10)
        _tube(b,'TieLooseEnd',[(w*.1,0,h*.81),(w*.17,-d*.1,h*.74),(w*.12,-d*.16,h*.68)],w*.018,'TX14')

    elif n == 69:
        for x in (-w*.45,w*.45):
            for y in (-d*.35,d*.35):
                b.box('ShelfUpright',(x,y,h*.5),(w*.075,d*.2,h),wood,.015)
        for z in (.12,.49,.87):
            for j in range(3):
                b.box('ShelfBoard',(0,(j-1)*d*.31,h*z),(w,d*.30,h*.045),wood,.012)
            b.box('RearShelfRail',(0,d*.39,h*(z+.03)),(w,d*.11,h*.075),wood,.008)
            for x in (-w*.45,w*.45):
                b.box('ShelfEndSupport',(x,0,h*(z-.035)),(w*.09,d,h*.045),wood,.007)

    elif n == 70:
        for i,(x,y,r,z) in enumerate([(-.10,.05,.31,.40),(-.31,-.12,.19,.24),(.24,.09,.19,.24),(.27,-.20,.15,.16),(-.10,-.27,.11,.12)]):
            # Broad offset crowns, not pointed crystals.
            _rings(b,f'ChalkSaltChunk{i}',[(w*r*.76,d*r*.76,0),(w*r,d*r,h*z*.35),
                                         (w*r*.79,d*r*.79,h*z*.84),(w*r*.34,d*r*.34,h*z)],'TX05',sides=6,loc=(w*x,d*y,0))

    elif n == 71:
        turns, steps = 5, 18
        radius=min(w,d)*.030
        pts=[]
        for i in range(turns*steps+1):
            a=TAU*i/steps
            r=min(w,d)*(.425+.008*math.sin(a*3))
            pts.append((r*math.cos(a),r*math.sin(a),radius+(h-2*radius)*i/(turns*steps)))
        _tube(b,'FiveThickRopeTurns',pts,radius,'TX14',sides=6)
        _tube(b,'LooseRopeTail',[pts[-1],(w*.42,-d*.18,h*.8),(w*.28,-d*.43,h*.38)],radius,'TX14')

    elif n == 72:
        outline=[(-w*.5,-d*.47),(-w*.39,-d*.5),(w*.48,-d*.46),(w*.5,d*.35),
                 (w*.42,d*.47),(-w*.38,d*.5),(-w*.5,d*.35),(-w*.46,d*.13),(-w*.49,d*.05)]
        b.extrude('ChippedRepairPlank',outline,0,h,'TX07')
        # Two long shallow split grooves, broad enough to read at game scale.
        for x,yy in ((-.10,-.16),(.08,.22)):
            b.extrude('BroadWoodSplit',[(w*(x-.30),d*yy),(w*(x+.31),d*(yy+.01)),(w*(x+.13),d*(yy+.045))],h*.997,h*1.002,'TX08')

    elif n == 73:
        outline=[(-w*.45,-d*.5),(w*.45,-d*.5),(w*.5,-d*.40),(w*.5,d*.40),
                 (w*.45,d*.5),(-w*.45,d*.5),(-w*.5,d*.40),(-w*.5,-d*.40)]
        b.extrude('ChamferedRepairPlate',outline,0,h*.6,iron)
        for x in (-w*.38,w*.38):
            for y in (-d*.31,d*.31):
                b.cyl('LargeHexFastener',(x,y,h*.80),min(w,d)*.075,h*.40,iron,sides=6)

    elif n == 74:
        _cloth(b,'TwoFoldClothScrap',w,d,h,cloth)

    elif n == 75:
        bodyh=h*.65
        _rings(b,'EmptyBucket',[(w*.34,d*.36,0),(w*.44,d*.46,bodyh),
                              (w*.39,d*.41,bodyh),(w*.29,d*.31,h*.07)],wood,sides=12)
        for z,rx in ((h*.035,.36),(h*.44,.43)):
            _band(b,'BucketIronHoop',w*rx,d*(rx+.02),z,h*.075,w*.035,iron)
        pts=[(w*.46*math.cos(math.pi*i/8),0,bodyh+h*.31*math.sin(math.pi*i/8)) for i in range(9)]
        _tube(b,'RaisedBucketHandle',pts,w*.035,iron,sides=6)
        for x in (-w*.45,w*.45):
            b.cyl('HandlePivot',(x,0,bodyh),w*.06,w*.07,iron,axis='X',sides=6)

    elif n == 76:
        # Deep open spoon bowl, not a solid disk.
        bowl=_rings(b,'OpenLadleBowl',[(w*.20,d*.19,0),(w*.48,d*.48,h*.15),
                                    (w*.43,d*.43,h*.15),(w*.15,d*.14,h*.035)],wood,sides=8)
        bowl.rotation_euler.x=math.radians(55)
        bowl.location.z=h*.09
        b.rod('LongWoodenHandle',(0,d*.035,h*.17),(0,d*.15,h*.94),w*.072,wood,sides=4)
        b.box('LadleEndGrip',(0,d*.15,h*.945),(w*.21,d*.3,h*.11),wood,.008)

    elif n == 77:
        # Opaque coarse-woven storage with visible cavity, 6 bands and 12 stakes.
        _rings(b,'BasketInnerShell',[(w*.31,d*.31,0),(w*.46,d*.46,h*.73),
                                   (w*.41,d*.41,h*.73),(w*.26,d*.26,h*.07)],wood,sides=12)
        for j in range(6):
            t=j/5
            _band(b,'BroadHorizontalReed',w*(.32+.14*t),d*(.32+.14*t),h*(.04+.12*j),h*.055,w*.027,wood)
        for i in range(12):
            a=TAU*i/12
            _tube(b,'WideUprightReed',[(w*.32*math.cos(a),d*.32*math.sin(a),0),
                                      (w*.385*math.cos(a),d*.385*math.sin(a),h*.38),
                                      (w*.46*math.cos(a),d*.46*math.sin(a),h*.76)],w*.021,wood,sides=4)
        _band(b,'ThickBasketRim',w*.48,d*.48,h*.73,h*.075,w*.065,wood)
        for x in (-w*.39,w*.39):
            pts=[(x,-d*.14,h*.77),(x,-d*.11,h*.94),(x,d*.01,h),(x,d*.14,h*.91),(x,d*.15,h*.77)]
            _tube(b,'BasketLoopHandle',pts,w*.035,wood,sides=4)

    elif n == 78:
        b.box('NoticeWoodBacking',(0,d*.10,h*.5),(w,d*.7,h),wood,.009)
        b.box('BlankNoticeParchment',(0,-d*.32,h*.50),(w*.78,d*.10,h*.79),'TX16',.004)
        for z in (h*.075,h*.925):
            b.box('NoticeCrossRail',(0,-d*.23,z),(w,d*.48,h*.09),wood,.005)
        for x in (-w*.34,w*.34):
            for z in (h*.15,h*.85):
                b.cyl('PaperFastener',(x,-d*.44,z),w*.018,d*.08,iron,axis='Y',sides=6)
        b.flag('variation','blank_authored_notice_backing')

    elif n == 79:
        outline=[(-w*.5,0),(w*.5,0),(w*.5,h*.74),(w*.22,h),(-w*.22,h),(-w*.5,h*.74)]
        _vertical_plate(b,'PlainSluicePlaque',outline,d*.65,'TX16',y=d*.15)
        _wheel_chain(b,-w*.05,-d*.35,h*.63,w*.27,iron)
        for x in (-w*.47,w*.47):
            for z in (h*.13,h*.54):
                b.box('PlaqueClamp',(x,-d*.20,z),(w*.10,d*.8,h*.09),iron,.003)

    elif n == 80:
        _vertical_plate(b,'BlankRouteMarker',[(-w*.5,0),(w*.5,0),(w*.5,h*.83),
                                             (w*.3,h),(-w*.3,h),(-w*.5,h*.83)],d,'TX16')
        b.flag('variation','blank_route_backing_no_arrow')

    elif n == 81:
        # Bell-bank marker, distinct from the wheel-and-chain Sluice plaque.
        for side in (-1,1):
            x=side*w*.43
            b.box('ClothSuspensionTab',(x,0,h*.94),(w*.08,d*.6,h*.09),iron,.002)
        b.rod('BannerCrossbar',(-w*.53,0,h*.975),(w*.53,0,h*.975),d*.28,iron,sides=8)
        # Broad bends: five vertical strips with stepped front profile.
        xs=[-w*.46,-w*.24,0,w*.23,w*.47]
        ys=[0,-d*.40,0,d*.35,0]
        bottoms=[h*.03,h*.12,h*.01,h*.09,h*.04]
        verts=[]
        for i,x in enumerate(xs):
            verts += [(x,ys[i],bottoms[i]),(x,ys[i],h*.90)]
        faces=[]
        for i in range(4):
            faces.extend([(i*2,i*2+2,i*2+3),(i*2,i*2+3,i*2+1)])
        verts += [(x,y+d*.06,z) for x,y,z in verts]
        faces += [tuple(i+10 for i in reversed(face)) for face in list(faces)]
        boundary=[0,2,4,6,8,9,7,5,3,1]
        for i,a in enumerate(boundary):
            c=boundary[(i+1)%len(boundary)]
            faces.append((a,c,c+10,a+10))
        b.mesh('TornFoldedBankCloth',verts,faces,cloth)
        bell=[(-w*.23,h*.43),(w*.23,h*.43),(w*.17,h*.49),(w*.13,h*.64),
              (w*.07,h*.69),(w*.035,h*.71),(w*.03,h*.75),
              (-w*.03,h*.75),(-w*.035,h*.71),(-w*.07,h*.69),
              (-w*.13,h*.64),(-w*.17,h*.49)]
        _vertical_plate(b,'PlainBellBankEmblem',bell,d*.08,iron,y=-d*.52)
        b.cyl('BellEmblemClapper',(0,-d*.52,h*.415),w*.045,d*.08,iron,axis='Y',sides=8)

    elif n in (82,83):
        # Mask carriers themselves contain no wall block or raised crust.
        b.plane('SaltWearCarrier' if n==82 else 'DampWearCarrier',(0,0,h*.5),w,h,
                'Wear_Salt' if n==82 else 'Wear_Damp',vertical=True)
        b.flag('card',True)
        b.flag('variation','surface_mask_only')

    elif n == 84:
        # Six radial strands and three sparse scalloped cross threads in one corner.
        origin=(-w*.5,0,h)
        ends=[(w*.5,0,h),(w*.44,0,h*.79),(w*.29,0,h*.55),
              (w*.08,0,h*.34),(-w*.16,0,h*.13),(-w*.5,0,0)]
        for end in ends:
            _tube(b,'ChunkyWebRadial',[origin,end],min(w,h)*.009,'AT01',sides=4)
        for t in (.33,.62,.88):
            pts=[]
            for end in ends:
                pts.append(tuple(origin[i]+(end[i]-origin[i])*t for i in range(3)))
            _tube(b,'ScallopedWebCrossThread',pts,min(w,h)*.007,'AT01',sides=4)

    elif n == 85:
        # Four separated broad broken facets, avoiding tiny scatter noise.
        pieces=[([(-.5,-.46),(-.03,-.5),(-.09,-.04),(-.33,.10),(-.5,.01)],.82),
                ([(.01,-.49),(.49,-.44),(.47,-.02),(.13,.08),(-.04,-.02)],1),
                ([(-.49,.06),(-.31,.15),(-.08,.02),(.05,.26),(-.04,.49),(-.46,.44)],.64),
                ([(.02,.04),(.16,.13),(.5,.03),(.45,.47),(.02,.49),(.11,.27)],.86)]
        for i,(points,height) in enumerate(pieces):
            b.extrude(f'BrokenTileFacet{i}',[(x*w,y*d) for x,y in points],0,h*height,'TX01')
