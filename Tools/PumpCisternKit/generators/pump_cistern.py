"""Low-poly, visual-only Pump and Cistern prop generators.

All dimensions are metres, Z is up, and each asset is authored around the
catalog pivot.  The helpers deliberately use only the shared Builder surface.
"""
import math


def _tube_x(b, name, x0, x1, radius, wall, mat, sides=12):
    """Hollow faceted tube along X. Both mouths remain open."""
    verts = []
    for x in (x0, x1):
        for r in (radius, radius - wall):
            verts.extend((x, math.cos(i * math.tau / sides) * r,
                          math.sin(i * math.tau / sides) * r)
                         for i in range(sides))
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        faces.extend(((i, j, sides + j, sides + i),
                      (2 * sides + i, 3 * sides + i, 3 * sides + j, 2 * sides + j),
                      (i, 2 * sides + i, 2 * sides + j, j),
                      (sides + i, sides + j, 3 * sides + j, 3 * sides + i)))
    return b.mesh(name, verts, faces, mat)


def _pipe_elbow_xy(b, name, radius, wall, bend_radius, mat, segments=8, sides=10):
    """Hollow quarter-bend; radial/Z annuli and open sockets at both ends."""
    verts = []
    center = (bend_radius, bend_radius, 0.0)
    for step in range(segments + 1):
        theta = math.pi + math.pi * .5 * step / segments
        radial = (math.cos(theta), math.sin(theta), 0.0)
        for r in (radius, radius - wall):
            for i in range(sides):
                phi = math.tau * i / sides
                verts.append((center[0] + bend_radius * radial[0] + r * radial[0] * math.cos(phi),
                              center[1] + bend_radius * radial[1] + r * radial[1] * math.cos(phi),
                              r * math.sin(phi)))
    faces = []
    stride = sides * 2
    for step in range(segments):
        a, c = step * stride, (step + 1) * stride
        for i in range(sides):
            j = (i + 1) % sides
            faces.extend(((a + i, c + i, c + j, a + j),
                          (a + sides + i, a + sides + j,
                           c + sides + j, c + sides + i)))
    # Annular end faces only. The center remains open at both sockets.
    for base in (0, segments * stride):
        for i in range(sides):
            j = (i + 1) % sides
            face=(base + i, base + j, base + sides + j, base + sides + i)
            faces.append(face if base == 0 else tuple(reversed(face)))
    return b.mesh(name, verts, faces, mat)


def _ring(b, name, loc, outer, inner, depth, mat, axis='Z', sides=12):
    """Annular flange mesh with a genuine open center."""
    x, y, z = loc
    verts = []
    for along, radius in ((-depth / 2, outer), (-depth / 2, inner),
                          (depth / 2, outer), (depth / 2, inner)):
        for i in range(sides):
            a = math.tau * i / sides
            u, v = math.cos(a) * radius, math.sin(a) * radius
            if axis == 'X': verts.append((x + along, y + u, z + v))
            elif axis == 'Y': verts.append((x + u, y + along, z + v))
            else: verts.append((x + u, y + v, z + along))
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        faces.extend(((i, j, sides + j, sides + i),
                      (2 * sides + i, 3 * sides + i, 3 * sides + j, 2 * sides + j),
                      (i, 2 * sides + i, 2 * sides + j, j),
                      (sides + i, sides + j, 3 * sides + j, 3 * sides + i)))
    return b.mesh(name, verts, faces, mat)


def _elliptic_ring_z(b, name, loc, outer_xy, inner_xy, depth, mat, sides=12):
    """Hollow oval collar around Z for shallow root-to-stone transitions."""
    x, y, z = loc
    verts=[]
    for dz, radii in ((-depth/2,outer_xy),(-depth/2,inner_xy),
                      (depth/2,outer_xy),(depth/2,inner_xy)):
        for i in range(sides):
            a=math.tau*i/sides
            verts.append((x+math.cos(a)*radii[0],y+math.sin(a)*radii[1],z+dz))
    faces=[]
    for i in range(sides):
        j=(i+1)%sides
        faces.extend(((i,j,sides+j,sides+i),
                      (2*sides+i,3*sides+i,3*sides+j,2*sides+j),
                      (i,2*sides+i,2*sides+j,j),
                      (sides+i,sides+j,3*sides+j,3*sides+i)))
    return b.mesh(name,verts,faces,mat)


def _span(b, name, a, c, radius, mat, sides=8):
    return b.rod(name, a, c, radius, mat, sides=sides)


def _pebble(b, name, loc, scale, mat):
    x, y, z = loc
    return b.mesh(name,
        [(x + sx * scale[0], y + sy * scale[1], z + sz * scale[2])
         for sx, sy, sz in ((-1,-.6,0),(-.6,-1,0),(.6,-1,0),(1,-.4,0),
                            (1,.5,0),(.4,1,0),(-.7,1,0),(-1,.3,0),
                            (-.55,-.45,1),(.45,-.55,.75),(.55,.45,.9),(-.4,.5,.8))],
        [(0,1,8),(1,2,9,8),(2,3,9),(3,4,10,9),(4,5,10),(5,6,11,10),
         (6,7,11),(7,0,8,11),(8,9,10,11),(7,6,5,4,3,2,1,0)], mat)


def _tapered_root(b, name, points, material, sides=7):
    """Faceted bent root with a radius at each point and closed end caps."""
    tangents = []
    for i, (point, _) in enumerate(points):
        before = points[max(0, i - 1)][0]
        after = points[min(len(points) - 1, i + 1)][0]
        delta = tuple(after[k] - before[k] for k in range(3))
        length = math.sqrt(sum(v * v for v in delta)) or 1.0
        tangents.append(tuple(v / length for v in delta))
    vertices = []
    for (point, radius), tangent in zip(points, tangents):
        ref = (0.0, 1.0, 0.0) if abs(tangent[2]) > .9 else (0.0, 0.0, 1.0)
        u = (tangent[1] * ref[2] - tangent[2] * ref[1],
             tangent[2] * ref[0] - tangent[0] * ref[2],
             tangent[0] * ref[1] - tangent[1] * ref[0])
        ulen = math.sqrt(sum(v * v for v in u)) or 1.0
        u = tuple(v / ulen for v in u)
        v = (tangent[1] * u[2] - tangent[2] * u[1],
             tangent[2] * u[0] - tangent[0] * u[2],
             tangent[0] * u[1] - tangent[1] * u[0])
        for j in range(sides):
            angle = math.tau * j / sides
            vertices.append(tuple(point[k] + radius * (u[k] * math.cos(angle) + v[k] * math.sin(angle))
                                  for k in range(3)))
    faces = []
    for section in range(len(points) - 1):
        a, c = section * sides, (section + 1) * sides
        for j in range(sides):
            k = (j + 1) % sides
            faces.append((a + j, a + k, c + k, c + j))
    faces.append(tuple(reversed(range(sides))))
    end = (len(points) - 1) * sides
    faces.append(tuple(end + j for j in range(sides)))
    return b.mesh(name, vertices, faces, material)


def _arc_patch_x(b, name, x_half, inner_radius, outer_radius, start, end, mat, segments=6):
    """Curved shell patch around an X-axis pipe; leaves the bore open."""
    vertices = []
    for x in (-x_half, x_half):
        for radius in (inner_radius, outer_radius):
            for step in range(segments + 1):
                theta = start + (end - start) * step / segments
                vertices.append((x, math.sin(theta) * radius, math.cos(theta) * radius))
    ring = segments + 1
    faces = []
    for step in range(segments):
        a, c = step, step + 1
        faces.append((a, c, 2 * ring + c, 2 * ring + a))
        a, c = ring + step, ring + step + 1
        faces.append((a, 3 * ring + step, 3 * ring + step + 1, c))
    for edge in (0, segments):
        a = edge
        face=(a,2*ring+a,3*ring+a,ring+a)
        faces.append(face if edge == 0 else tuple(reversed(face)))
    return b.mesh(name, vertices, faces, mat)


def build(b, part):
    """Create exactly one catalog asset using the ChainCrossingKit Builder."""
    n = int(part['id'][3:])
    w, d, h = b.size
    iron, verdigris, stone, timber = 'TX09', 'TX11', 'TX04', 'TX08'
    for key, value in part.get('flags', {}).items():
        b.flag(key, value)
    b.flag('pivot', part['pivot'])
    if n == 1:  # PumpTowerBody: hollow body, base, shoulders and cap; no wheel.
        b.cyl('PumpFoot',(0,0,.12),.92,.24,iron,sides=12)
        b.cyl('PumpLowerCollar',(0,0,.30),.78,.16,verdigris,sides=12)
        b.cyl('PumpBody',(0,0,3.0),.64,4.60,verdigris,sides=12)
        b.cyl('PumpUpperCollar',(0,0,5.36),.76,.22,iron,sides=12)
        b.cone('PumpShoulder',(0,0,5.52),.72,.50,.24,verdigris,sides=12)
        b.cyl('PumpCap',(0,0,5.72),.54,.20,iron,sides=12)
        b.cyl('PumpCrown',(0,0,5.90),.20,.12,verdigris,sides=10)
        # Side socket is a hollow outlet, projecting along local X.
        _tube_x(b,'OpenPumpOutlet',.48,.86,.31,.08,verdigris)
        _ring(b,'OutletFlange',(.86,0,3.0),.39,.23,.11,iron,'X',12)
        # Raise the outlet tube to the same elevation as its flange.
        b.objects[-2].location.z = 3.0
        b.flag('hero_base_cylinder_cap',True);b.flag('flywheel_separate',True)
    elif n == 2:  # Wheel in XZ, axle along Y, matching its 90x24x90 envelope.
        _ring(b,'WheelRim',(0,0,0),.45,.34,.24,iron,'Y',16)
        _ring(b,'WheelHub',(0,0,0),.15,.06,.24,verdigris,'Y',12)
        for i in range(6):
            a=i*math.tau/6
            _span(b,'WheelSpoke',(math.cos(a)*.12,0,math.sin(a)*.12),
                  (math.cos(a)*.36,0,math.sin(a)*.36),.035,verdigris,6)
        b.flag('axis','Y');b.flag('wheel_plane','XZ');b.flag('spokes',6)
    elif n == 3:  # Piston rod, center pivot.
        b.cyl('PistonRod',(0,0,0),.075,1.30,iron,sides=8)
        b.cyl('RodEnd',(0,0,-.70),.11,.20,verdigris,sides=8)
        b.cyl('RodHead',(0,0,.70),.12,.20,iron,sides=8)
        b.flag('pivot','center')
        b.flag('separate_moving_part',True)
    elif n == 4:  # diagonal structural brace across XZ, bottom contact pivot.
        b.box('LowerShoe',(.30,0,.10),(.20,.26,.20),iron,.015)
        b.box('UpperShoe',(-.30,0,1.30),(.20,.26,.20),iron,.015)
        _span(b,'Brace',(.30,0,.12),(-.30,0,1.28),.075,verdigris,6)
        b.flag('axis','XZ')
    elif n == 5:
        _tube_x(b,'HollowStraightPipe',-1,1,.20,.055,verdigris,12)
        for x in (-.82,.82): _ring(b,'PipeEndFlange',(x,0,0),.27,.17,.10,iron,'X',12)
        b.flag('axis','X');b.flag('open_mouths',True)
    elif n == 6:
        bend=.20;offset=-.10
        elbow = _pipe_elbow_xy(b,'HollowQuarterElbow',.18,.05,bend,verdigris)
        elbow.location.x = offset
        elbow.location.y = offset
        # Socket centers are (0, .20) and (.20, 0), translated together.
        _ring(b,'InletFlange',(offset,offset+bend,0),.24,.15,.10,iron,'Y',12)
        _ring(b,'OutletFlange',(offset+bend,offset,0),.24,.15,.10,iron,'X',12)
        b.flag('axis','XY');b.flag('open_mouths',True)
        b.flag('socket_centers_m',[[offset,offset+bend,0],[offset+bend,offset,0]])
    elif n == 7:
        _ring(b,'HollowPipeCollar',(0,0,0),.25,.15,.18,iron,'X',12)
        for i in range(6):
            a=i*math.tau/6
            b.cyl('CollarBolt',(0,math.cos(a)*.22,math.sin(a)*.22),.035,.08,iron,'X',6)
        b.flag('axis','X');b.flag('open_mouths',True);b.flag('hollow_center',True)
    elif n == 8:
        b.box('WallMount',(0,.09,.32),(.30,.12,.50),iron,.02)
        b.box('PipeCradle',(0,-.02,.55),(.35,.32,.10),verdigris,.02)
        for x in (-.10,.10): b.cyl('AnchorBolt',(x,.16,.32),.035,.08,iron,'Y',6)
    elif n == 9:
        b.cyl('CapPlug',(0,0,0),.21,.12,iron,'X',12)
        b.cyl('CapRidge',(0,0,0),.25,.05,verdigris,'X',12)
        b.flag('axis','X');b.flag('closed_end',True)
    elif n == 10:
        # Straight rim: raised rounded stone edging, center-bottom pivot.
        b.box('RimBase',(0,0,.12),(w,d*.70,.24),stone,.05)
        b.box('RimCoping',(0,0,.40),(w,d,.28),'TX02',.06)
        b.flag('pivot','bottom center')
    elif n == 11:
        # L-shaped inner corner, two joined arms, open basin side.
        b.box('CornerLongArm',(-.15,0,.275),(.40,d,.55),stone,.05)
        b.box('CornerShortArm',(.15,.15,.275),(.40,.50,.55),stone,.05)
        b.flag('shape','L; open inside corner');b.flag('pivot','bottom center')
    elif n == 12:
        b.box('RimEndBase',(0,0,.12),(w,d*.70,.24),stone,.04)
        b.box('RimEndCoping',(0,0,.40),(w,d,.28),'TX02',.05)
        b.flag('end_cap',True);b.flag('pivot','bottom center')
    elif n == 13:
        # Gauge is a board with simple physical tick marks only, not an interface.
        b.box('GaugeBoard',(0,0,h/2),(w*.72,d*.35,h),timber,.025)
        for i in range(6):
            z=.18+i*.22
            b.box('GaugeTick',(-w*.08,-d*.19,z),(w*.30,d*.08,.025),iron,.003)
        b.flag('ticks_only_no_control',True)
    elif n == 14:
        # Bending trunk branches in XZ; taper closes at each root tip.
        _tapered_root(b,'RootTrunk',[
            ((0,0,.23),.23),((-.12,0,.65),.20),((-.06,0,1.25),.17),
            ((-.10,0,1.82),.14),((-.02,0,2.38),.08)],timber)
        _tapered_root(b,'RootForkLeft',[
            ((-.07,0,.82),.16),((-.35,-.02,1.05),.14),((-.68,-.02,1.12),.11),
            ((-.92,-.01,1.42),.075),((-.96,0,1.72),.018)],timber)
        _tapered_root(b,'RootForkRight',[
            ((-.04,0,1.0),.14),((.22,.02,1.18),.12),((.56,.02,1.15),.10),
            ((.82,.01,1.45),.07),((.94,0,1.85),.018)],timber)
        _tapered_root(b,'RootLowerSweep',[
            ((0,0,.18),.13),((.18,.02,.40),.11),((.32,.02,.58),.09),
            ((.68,.01,.62),.06),((.92,0,.82),.015)],timber)
        b.flag('non_climbable_visual',True)
    elif n == 15:
        _tapered_root(b,'RootTendril',[
            ((0,0,.09),.09),((.10,0,.55),.075),((-.06,.01,1.0),.06),
            ((.12,.02,1.48),.042),((.02,.02,1.85),.025),
            ((.10,.01,2.16),.008)],timber)
        b.flag('non_climbable_visual',True)
    elif n == 16:
        _elliptic_ring_z(b,'StoneSocket',(0,0,.16),(.47,.205),(.30,.13),.32,stone,10)
        for i in range(6):
            a=i*math.tau/6
            _tapered_root(b,'RootRadial',[
                ((math.cos(a)*.25,math.sin(a)*.12,.13),.055),
                ((math.cos(a)*.35,math.sin(a)*.16,.08),.040),
                ((math.cos(a)*.44,math.sin(a)*.18,.025),.008)],timber,6)
        b.flag('pivot','bottom center');b.flag('hollow_center',True)
        b.flag('elliptical_footprint',True)
    elif n == 17:
        for i in range(7):
            x=(b.rng.random()-.5)*.42;y=(b.rng.random()-.5)*.40
            sx=.12+b.rng.random()*.16;sy=.10+b.rng.random()*.14
            _pebble(b,'BedPebble',(x,y,-.15),(sx,sy,.15),stone)
        b.flag('pivot','top contact')
    elif n == 18:
        for x in (-.22,.22):
            _ring(b,'WrapBand',(x,0,0),.275,.21,.08,iron,'X',12)
        _arc_patch_x(b,'CurvedRepairPlate',.19,.255,.27,
                     math.radians(-52),math.radians(52),verdigris,6)
        for x in (-.12,0,.12):
            b.cyl('PatchRivet',(x,0,.265),.014,.015,iron,'Z',6)
        b.flag('two_annular_straps',True);b.flag('curved_patch',True);b.flag('open_bore',True)
    elif n == 19:
        b.box('RackBack',(0,.08,.78),(1.0,.08,1.3),timber,.02)
        b.box('RackShelf',(0,-.04,.24),(1.0,.15,.10),timber,.02)
        b.box('RackShelf',(0,-.04,.92),(1.0,.15,.10),timber,.02)
        for x in (-.43,.43): b.box('RackPost',(x,0,.70),(.09,.12,1.4),timber,.015)
        b.flag('no_hanging_over_interaction_plane',True)
    elif n == 20:
        # Concave U profile is open at the left; opposite end has a closed ring.
        jaw=[(-.275,-.06),(-.12,-.06),(-.12,.06),(-.275,.06),
             (-.275,.03),(-.18,.03),(-.18,-.03),(-.275,-.03)]
        b.extrude('OpenUJaws',jaw,-.075,.075,iron)
        b.box('SpannerHandle',(.035,0,0),(.33,.075,.12),iron,.025)
        _ring(b,'ClosedRingEnd',(.22,0,0),.055,.025,.15,iron,'Z',10)
    elif n == 21:
        # Hollow open bucket with polygonal outer/inner tapered walls.
        sides=10; verts=[]
        for z,r in ((0,.22),(.45,.20),(.04,.17),(.42,.15)):
            verts.extend((math.cos(i*math.tau/sides)*r,math.sin(i*math.tau/sides)*r,z) for i in range(sides))
        faces=[]
        for i in range(sides):
            j=(i+1)%sides
            faces.extend(((i,j,sides+j,sides+i),(2*sides+i,3*sides+i,3*sides+j,2*sides+j),
                          (i,2*sides+i,2*sides+j,j),(sides+i,sides+j,3*sides+j,3*sides+i)))
        faces.append(tuple(range(2*sides,3*sides)))  # closed interior floor, mouth stays open
        b.mesh('HollowBucketWalls',verts,faces,iron)
        _ring(b,'BucketRim',(0,0,.45),.22,.17,.045,verdigris,'Z',10)
        _span(b,'BucketHandleLeft',(-.18,0,.42),(-.18,0,.47),.018,iron,6)
        _span(b,'BucketHandleTop',(-.18,0,.47),(0,0,.48),.018,iron,6)
        _span(b,'BucketHandleTop',(0,0,.48),(.18,0,.47),.018,iron,6)
        _span(b,'BucketHandleRight',(.18,0,.47),(.18,0,.42),.018,iron,6)
        b.flag('hollow_open_top',True);b.flag('closed_inner_bottom',True)
    elif n == 22:
        b.box('TrayBase',(0,0,.025),(w,d,.05),iron,.01)
        for x in (-w/2+.04,w/2-.04): b.box('TraySide',(x,0,.045),(.04,d,.05),verdigris,.01)
        for y in (-d/2+.04,d/2-.04): b.box('TraySide',(0,y,.045),(w,.04,.05),verdigris,.01)
    elif n == 23:
        b.cone('CandleStub',(0,0,(h-.03)/2),.065,.052,h-.03, 'TX16',sides=8)
        for i, angle in enumerate((.0, math.tau/3, math.tau*2/3)):
            x,y=math.cos(angle)*.035,math.sin(angle)*.035
            b.cone('BroadWaxDrip',(x,y,.11),.020,.010,.09,'TX16',sides=6)
        b.cyl('UnlitWick',(0,0,h-.02),.012,.02,iron,sides=5)
        b.flag('unlit_static_prop',True)
    elif n == 24:
        # Plain, quiet cloth; no lettering, symbols, or generated glyphs.
        b.box('BannerTopBar',(0,0,h-.05),(w,.06,.06),timber,.01)
        front=[];back=[];segments=6
        for i in range(segments+1):
            u=i/segments; x=(u-.5)*w
            fold=math.sin(i*1.7)*.018
            bottom_z=.03+(i%2)*.018
            front.extend(((x,fold-.012,h-.10),(x*.94,fold-.012,bottom_z)))
            back.extend(((x,fold+.012,h-.10),(x*.94,fold+.012,bottom_z)))
        cloth_verts=front+back;cloth_faces=[];row=2*(segments+1)
        for i in range(segments):
            a=2*i; cloth_faces.extend(((a,a+2,a+3,a+1),
                                       (row+a+1,row+a+3,row+a+2,row+a)))
        for i in range(segments):
            a=2*i;cloth_faces.append((a,row+a,row+a+2,a+2))
            a+=1;cloth_faces.append((a,a+2,row+a+2,row+a))
        cloth_faces.extend(((0,1,row+1,row),(2*segments, row+2*segments,
                            row+2*segments+1,2*segments+1)))
        b.mesh('FoldedTwoSidedCloth',cloth_verts,cloth_faces,'TX12')
        b.flag('plain_muted_no_glyphs',True);b.flag('two_sided_geometry',True)
    else:
        raise ValueError(f'Unknown PumpCisternKit asset id: {part["id"]}')
