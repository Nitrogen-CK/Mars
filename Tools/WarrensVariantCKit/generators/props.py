"""Procedural storage, kitchen, mill, and tabletop props for Warrens Variant C."""

import math


TAU = 2.0 * math.pi
OWNED_SOURCE_IDS = frozenset({
    "P02", "P03", "P04", "P06", "P07", "P09", "P10", "P11", "P12",
    "P11_Single", "P13", "P14", "P15", "P16", "P17", "P18", "P19",
    "P21", "P22", "P24",
})
OWNED = OWNED_SOURCE_IDS


def _vessel(b, name, rx, ry, h, material, profile, sides=10):
    """Build a thick-walled vessel with an open mouth and a closed interior floor.

    profile walks the section from outer base, up the outer wall, across the rim,
    down the inner wall, and back to the interior floor. Each item is (rx, ry, z).
    The final-to-first connection creates only the bottom annulus; neither mouth
    nor cavity is capped.
    """
    verts = []
    for px, py, z in profile:
        for i in range(sides):
            a = TAU * i / sides
            verts.append((px * math.cos(a), py * math.sin(a), z))
    faces = []
    rows = len(profile)
    for row in range(rows):
        nxt = (row + 1) % rows
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((row * sides + i, row * sides + j,
                          nxt * sides + j, nxt * sides + i))
    # Closed interior floor; mouth remains an actual opening.
    interior_start = (rows - 1) * sides
    faces.append(tuple(interior_start + i for i in range(sides)))
    # Close the underside across the outer base ring.
    faces.append(tuple(reversed(range(sides))))
    return b.mesh(name, verts, faces, material)


def _open_bowl(b, name, w, d, h, material, shallow=False):
    if shallow:
        prof = [(.28*w, .28*d, .03*h), (.44*w, .44*d, .28*h),
                (.50*w, .50*d, h), (.38*w, .38*d, h),
                (.31*w, .31*d, .34*h)]
    else:
        prof = [(.24*w, .24*d, .06*h), (.43*w, .43*d, .38*h),
                (.50*w, .50*d, h), (.39*w, .39*d, h),
                (.31*w, .31*d, .34*h)]
    return _vessel(b, name, w, d, h, material, prof, sides=10)


def _solid_lathe(b, name, profiles, material, sides=10, center=(0, 0)):
    """Closed faceted body of revolution, with flat bottom and top polygons."""
    verts = []
    cx, cy = center
    for radius, z in profiles:
        for i in range(sides):
            a = TAU * i / sides
            verts.append((cx + radius * math.cos(a), cy + radius * math.sin(a), z))
    faces = []
    rows = len(profiles)
    for row in range(rows - 1):
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((row*sides+i, row*sides+j,
                          (row+1)*sides+j, (row+1)*sides+i))
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple((rows-1)*sides+i for i in range(sides)))
    return b.mesh(name, verts, faces, material)


def _salt_lump(b, name, center, scale, material, sides=7, irregular=0.12):
    """Closed, flat-shaded low-poly salt lump with deterministic faceted profile."""
    cx, cy, cz = center
    sx, sy, sz = scale
    rng = b.rng
    rings = [(0.12, 0.00), (0.48, 0.16), (0.50, 0.58), (0.28, 0.88), (0.04, 1.0)]
    verts = []
    phase = rng.random() * TAU
    for ridx, (factor, zf) in enumerate(rings):
        for i in range(sides):
            a = TAU * i / sides + phase
            jitter = 1.0 + rng.uniform(-irregular, irregular)
            verts.append((cx + math.cos(a) * sx * factor * jitter,
                          cy + math.sin(a) * sy * factor * jitter,
                          cz + sz * zf * (1.0 + rng.uniform(-irregular*.25, irregular*.25))))
    faces = [tuple(reversed(range(sides)))]
    for row in range(len(rings)-1):
        for i in range(sides):
            j = (i+1) % sides
            faces.append((row*sides+i, row*sides+j,
                          (row+1)*sides+j, (row+1)*sides+i))
    faces.append(tuple((len(rings)-1)*sides+i for i in range(sides)))
    return b.mesh(name, verts, faces, material)


def _prep_bench(b, w, d, h):
    wood, iron = b.part['materials'][0], b.part['materials'][-1]
    top_t = h * .12
    b.box('BenchTop', (0, 0, h-top_t/2), (w, d, top_t), wood, bevel=.025)
    leg_w, leg_d = w*.09, d*.12
    for x in (-w*.39, w*.39):
        for y in (-d*.36, d*.36):
            b.box('SquareLeg', (x, y, (h-top_t)*.48), (leg_w, leg_d, h-top_t), wood, bevel=.012)
    # Lower stretchers brace both side frames without enclosing the underside.
    for y in (-d*.36, d*.36):
        b.box('SideStretcher', (0, y, h*.28), (w*.82, leg_d*.72, h*.08), wood)
    for x in (-w*.39, w*.39):
        b.box('EndStretcher', (x, 0, h*.28), (leg_w*.72, d*.70, h*.08), wood)
    for y in (-d*.43, d*.43):
        b.box('BenchIronTie', (0, y, h-top_t*.5), (w*.94, .012, .035), iron, bevel=.003)


def _crate_body(b, w, d, h):
    wood = b.part['materials'][0]
    iron = b.part['materials'][-1]
    t = min(w, d) * .085
    floor_t = h*.11
    b.box('CrateFloor', (0, 0, floor_t/2), (w, d, floor_t), wood, bevel=.008)
    # Four inward-facing walls leave a genuinely open top and hollow cavity.
    b.box('FrontWall', (0, -d/2+t/2, (h+floor_t)/2), (w, t, h-floor_t), wood, bevel=.008)
    b.box('BackWall', (0, d/2-t/2, (h+floor_t)/2), (w, t, h-floor_t), wood, bevel=.008)
    b.box('LeftWall', (-w/2+t/2, 0, (h+floor_t)/2), (t, d-2*t, h-floor_t), wood, bevel=.008)
    b.box('RightWall', (w/2-t/2, 0, (h+floor_t)/2), (t, d-2*t, h-floor_t), wood, bevel=.008)
    # Two simple binding straps; no latch or interaction geometry.
    for x in (-w*.34, w*.34):
        b.box('FrontIronBinding', (x, -d/2-.002, h*.52), (w*.055, .012, h*.92), iron, bevel=.002)
        b.box('SideIronBinding', (w/2+.002, 0, h*.52), (.012, d*.055, h*.92), iron, bevel=.002)


def _crate_lid(b, w, d, h):
    wood = b.part['materials'][0]
    # Separate slab asset as required by the source crate open/closed assembly.
    b.box('LidPlankCore', (0, 0, h*.50), (w, d, h*.65), wood, bevel=.008)
    for y in (-d*.31, d*.31):
        b.box('LidCrossBoard', (0, y, h*.50), (w*.92, d*.16, h), wood, bevel=.006)


def _jar(b, w, d, h):
    mat = b.part['materials'][0]
    profile = [(.30*w, .30*d, 0), (.42*w, .42*d, .08*h),
               (.50*w, .50*d, .48*h), (.40*w, .40*d, .78*h),
               (.25*w, .25*d, .90*h), (.26*w, .26*d, h),
               (.18*w, .18*d, h), (.19*w, .19*d, .82*h),
               (.30*w, .30*d, .12*h)]
    _vessel(b, 'OpenStorageJar', w, d, h, mat, profile, sides=10)
    # Loop handles remain small and functional-looking, not a face or collectible silhouette.
    loop_r = min(w, d)*.105
    for side in (-1, 1):
        b.torus('JarLoopHandle', (side*w*.37, 0, h*.59), loop_r, min(w,d)*.035,
                mat, axis='Y', major_segments=8, minor_segments=3)


def _closed_urn(b, w, d, h):
    mat = b.part['materials'][0]
    radius = min(w, d)*.5
    _solid_lathe(b, 'OssuaryUrnBody', [(radius*.55, 0), (radius*.8, h*.08),
        (radius, h*.48), (radius*.83, h*.72), (radius*.54, h*.84),
        (radius*.60, h*.91), (radius*.45, h*.96)], mat, sides=10)
    # Distinct, low, closed lid; plain ceramic silhouette with no face/markings.
    b.cyl('UrnLid', (0, 0, h*.96), radius*.45, h*.08, mat, sides=10)
    b.cyl('UrnLidKnob', (0, 0, h*1.025), radius*.13, h*.05, mat, sides=8)
    loop_r = radius*.16
    for side in (-1, 1):
        b.torus('UrnHandle', (side*radius*.72, 0, h*.68), loop_r, radius*.045,
                mat, axis='Y', major_segments=8, minor_segments=3)


def _reliquary_box(b, w, d, h):
    stone, wood = b.part['materials'][0], b.part['materials'][-1]
    b.box('ReliquaryBody', (0, 0, h*.40), (w, d, h*.72), stone, bevel=.025)
    b.box('InsetLid', (0, 0, h*.82), (w*.96, d*.96, h*.25), wood, bevel=.018)
    b.box('FrontBand', (0, -d*.505, h*.52), (w*.72, .025, h*.11), wood, bevel=.004)
    b.box('PlainCenterClasp', (0, -d*.525, h*.53), (w*.12, .02, h*.13), stone, bevel=.004)


def _drying_rod(b, w, d, h):
    wood, fiber = b.part['materials'][0], b.part['materials'][-1]
    b.cyl('Crossbar', (0, 0, h*.68), min(d, h)*.18, w, wood, axis='X', sides=8)
    for x in (-w*.44, w*.44):
        b.box('EndCollar', (x, 0, h*.68), (w*.045, d*.70, h*.38), fiber, bevel=.005)
        b.cyl('Peg', (x, 0, h*.50), min(d,h)*.12, h*.95, wood, sides=6)


def _drying_rack(b, w, d, h):
    wood, fiber = b.part['materials'][0], b.part['materials'][-1]
    # Two stable A-frames spaced across depth; top beam spans the width.
    foot_z = h*.035
    for y in (-d*.34, d*.34):
        for x, top_x in ((-w*.40, -w*.30), (w*.40, w*.30)):
            b.rod('AFrameLeg', (x, y, foot_z), (top_x, y, h*.93), min(d,w)*.035, wood, sides=6)
        b.box('AFrameFoot', (0, y, foot_z), (w*.88, d*.20, h*.07), wood, bevel=.01)
        b.box('AFrameTie', (0, y, h*.35), (w*.62, d*.10, h*.05), wood, bevel=.006)
    b.cyl('TopCrossbar', (0, 0, h*.94), min(d,h)*.055, w*.93, wood, axis='X', sides=8)
    # Two unobtrusive cross rails carry hanging goods while keeping the base open.
    for z in (h*.67, h*.82):
        b.cyl('HangingRail', (0, 0, z), min(d,h)*.025, w*.78, fiber, axis='X', sides=6)


def _tallow_pot(b, w, d, h):
    pottery, wax = b.part['materials']
    r = min(w, d)*.5
    _solid_lathe(b, 'TallowPotBody', [(r*.62, 0), (r*.82, h*.08),
        (r, h*.48), (r*.86, h*.69), (r*.68, h*.73)], pottery, sides=10)
    # Broad cap seals the pot mouth; droplets are thick, sculpted lobes, not thin UI cards.
    b.cyl('BroadWaxCap', (0, 0, h*.76), r*.69, h*.12, wax, sides=10)
    b.cone('WaxCapCrown', (0, 0, h*.84), r*.62, r*.34, h*.08, wax, sides=10)
    for i, angle in enumerate((.2, 1.4, 2.6, 3.8, 5.0)):
        rr = r*.64
        x, y = math.cos(angle)*rr, math.sin(angle)*rr
        drop_h = h*(.13 + (i%3)*.025)
        b.cone('WaxDrip', (x, y, h*.69-drop_h*.5), r*.10, r*.075,
               drop_h, wax, sides=6)


def _mug(b, w, d, h):
    ceramic = b.part['materials'][0]
    prof = [(.27*w, .30*d, 0), (.39*w, .40*d, .08*h),
            (.40*w, .41*d, h), (.30*w, .31*d, h),
            (.30*w, .31*d, .14*h)]
    _vessel(b, 'OpenMug', w, d, h, ceramic, prof, sides=10)
    # A true open loop handle in the XZ plane, joined visually to the cup side.
    loop_r = w*.19
    b.torus('OpenCenterMugHandle', (w*.29, 0, h*.52), loop_r, min(w,d)*.055,
            ceramic, axis='Y', major_segments=8, minor_segments=3)


def _folded_cloth(b, w, d, h):
    mat = b.part['materials'][0]
    # Layered, broad folds; closed lower slab ensures thickness and tabletop contact.
    b.box('FoldedClothBase', (0, 0, h*.25), (w, d, h*.50), mat, bevel=.012)
    b.box('FoldOverLayer', (w*.03, -d*.08, h*.68), (w*.87, d*.62, h*.34), mat, bevel=.012)
    # Low ridges suggest folded fabric without text, stripes, or random glyphs.
    for x in (-w*.31, w*.31):
        b.box('SoftFoldRidge', (x, 0, h*.83), (w*.08, d*.49, h*.30), mat, bevel=.016)


def _mortar_pestle(b, w, d, h):
    stone = b.part['materials'][0]
    rim_h = h*.61
    prof = [(.26*w, .26*d, 0), (.38*w, .38*d, h*.09),
            (.50*w, .50*d, rim_h), (.37*w, .37*d, rim_h),
            (.31*w, .31*d, h*.22)]
    _vessel(b, 'HollowMortar', w, d, rim_h, stone, prof, sides=10)
    # Pestle tilts over the bowl and stays inside the catalog envelope.
    a = (-w*.18, 0, h*.48); z = (w*.25, 0, h*.96)
    b.rod('PestleShaft', a, z, min(w,d)*.075, stone, sides=7)
    b.cyl('PestleRoundedEnd', a, min(w,d)*.13, min(w,d)*.16, stone, sides=7)
    b.cyl('PestleGrip', z, min(w,d)*.11, min(w,d)*.17, stone, sides=7)


def _hopper(b, w, d, h):
    wood, iron = b.part['materials'][0], b.part['materials'][-1]
    # Four hollow sloping panels converge on an open throat; no cap spans either mouth.
    top_x, top_y = w*.46, d*.46
    low_x, low_y = w*.13, d*.13
    z_top, z_low = h*.93, h*.28
    top = [(-top_x,-top_y,z_top),(top_x,-top_y,z_top),(top_x,top_y,z_top),(-top_x,top_y,z_top)]
    low = [(-low_x,-low_y,z_low),(low_x,-low_y,z_low),(low_x,low_y,z_low),(-low_x,low_y,z_low)]
    for i in range(4):
        j=(i+1)%4
        b.mesh('OpenFunnelPanel', [top[i],top[j],low[j],low[i]], [(0,1,2,3)], wood)
    # Thick top and throat rims frame both open apertures.
    for z,rx,ry,t in ((z_top,top_x,top_y,min(w,d)*.065),(z_low,low_x,low_y,min(w,d)*.045)):
        b.box('FunnelRimFront',(0,-ry,z),(rx*2,t,t),wood,bevel=.004)
        b.box('FunnelRimBack',(0,ry,z),(rx*2,t,t),wood,bevel=.004)
        b.box('FunnelRimLeft',(-rx,0,z),(t,ry*2,t),wood,bevel=.004)
        b.box('FunnelRimRight',(rx,0,z),(t,ry*2,t),wood,bevel=.004)
    # Four stable legs and two cross braces support the funnel without a closed base.
    for x in (-w*.40,w*.40):
        for y in (-d*.40,d*.40):
            b.box('HopperLeg',(x,y,z_top*.50),(w*.075,d*.075,z_top),wood,bevel=.006)
    b.box('HopperBraceX',(0,0,h*.10),(w*.86,d*.07,h*.07),wood,bevel=.006)
    b.box('HopperIronBand',(0,0,h*.57),(w*.88,d*.035,h*.045),iron,bevel=.003)


def _shutter(b, w, d, h):
    wood, iron = b.part['materials'][0], b.part['materials'][-1]
    plank_count=5; plank_w=w*.94/plank_count
    for i in range(plank_count):
        x=-w*.47+plank_w*(i+.5)
        b.box('VerticalShutterPlank',(x,0,h*.5),(plank_w*.94,d*.90,h),wood,bevel=.006)
    for z in (h*.20,h*.80):
        b.box('IronBrace',(0,-d*.28,z),(w*.94,d*.13,h*.075),iron,bevel=.004)
        b.box('BackBrace',(0,d*.28,z),(w*.94,d*.13,h*.075),wood,bevel=.004)
    # Thin fixed hinge leaves only; source actor owns any hinge motion.
    for x in (-w*.43,w*.43):
        b.box('HingeLeaf',(x,-d*.36,h*.50),(w*.08,d*.08,h*.62),iron,bevel=.004)


def build(b, part):
    """Build one catalog prop. `b.size` and all coordinates are metres."""
    source_id = part.get('source_id')
    if source_id not in OWNED_SOURCE_IDS:
        raise ValueError(f"props generator does not own source ID {source_id!r}")
    w, d, h = b.size
    b.flag('source_id', source_id)
    b.flag('visual_only', True)
    b.flag('source_collision_authoritative', True)
    if source_id == 'P02':
        _prep_bench(b,w,d,h)
    elif source_id == 'P03':
        _crate_body(b,w,d,h); b.flag('open_top_hollow_crate',True)
    elif source_id == 'P04':
        _crate_lid(b,w,d,h); b.flag('separate_static_lid',True)
    elif source_id == 'P06':
        _jar(b,w,d,h); b.flag('open_mouth',True)
    elif source_id == 'P07':
        _open_bowl(b,'OpenServingBowl',w,d,h,part['materials'][0],shallow=True)
        b.flag('open_mouth_thick_rim',True)
    elif source_id == 'P09':
        _salt_lump(b,'FacetedSaltCrystal',(0,0,0),(w*.48,d*.48,h),part['materials'][0],sides=7,irregular=.08)
        b.flag('closed_faceted_lump',True)
    elif source_id == 'P10':
        b.flag('deterministic_lump_count',9)
        # Overlapping closed low-poly lumps form one broad, low salt heap.
        for i in range(9):
            cols=3; row=i//cols; col=i%cols
            x=(-.30+col*.30)*w + b.rng.uniform(-.025,.025)*w
            y=(-.22+row*.22)*d + b.rng.uniform(-.025,.025)*d
            base_z=h*.02
            sx=w*b.rng.uniform(.13,.20); sy=d*b.rng.uniform(.14,.23); sz=h*b.rng.uniform(.48,.86)
            # Keep the upper mound under the declared height even with jitter.
            sz=min(sz,h*.90)
            _salt_lump(b,'SaltHeapLump',(x,y,base_z),(sx,sy,sz),part['materials'][0],sides=6,irregular=.10)
        b.flag('closed_faceted_lumps',True)
    elif source_id == 'P11':
        bone=part['materials'][0]
        # Blunt stylized shafts with swollen ends, tied into a compact bundle.
        for i in range(5):
            y=(-.30+i*.15)*d; z=h*(.43 + (.08 if i%2 else -.04))
            length=w*(.68 + .05*(i%3)); x0=-length*.5
            b.cyl('BoneShaft',(0,y,z),min(d,h)*.105,length,bone,axis='X',sides=7)
            for x in (-length*.43,length*.43):
                b.cyl('BluntBoneKnob',(x,y,z),min(d,h)*.16,min(d,h)*.22,bone,axis='X',sides=7)
        for x in (-w*.20,w*.20):
            b.box('BundleTie',(x,0,h*.46),(w*.055,d*.94,h*.72),bone,bevel=.004)
        b.flag('single_bone_silhouette_components',True)
        b.flag('single_bone_reusable_asset','WVC082')
    elif source_id == 'P11_Single':
        bone = part['materials'][0]
        # Center-pivot chime bone: a blunt shaft with a paired, rounded end profile.
        # The bulb axes and shaft all run along local X; no chain or rail is baked in.
        end_len = w*.18
        end_center = w*.41
        shaft_len = w*.64
        radius = min(d,h)*.20
        bulb_radius = min(d,h)*.48
        b.cyl('SingleBoneShaft',(0,0,0),radius,shaft_len,bone,axis='X',sides=7)
        for side in (-1,1):
            b.cone('BluntBoneShoulder',(side*w*.34,0,0),radius,bulb_radius,end_len*.70,
                   bone,axis='X',sides=7)
            b.cyl('BluntBoneEnd',(side*end_center,0,0),bulb_radius,end_len,bone,axis='X',sides=7)
        b.flag('bone_axis','X')
        b.flag('paired_blunt_bulb_ends',True)
        b.flag('no_chain_or_rail',True)
    elif source_id == 'P12':
        _closed_urn(b,w,d,h); b.flag('closed_ordinary_ossuary_urn',True)
    elif source_id == 'P13':
        _reliquary_box(b,w,d,h); b.flag('closed_static_box_no_interaction',True)
    elif source_id == 'P14':
        _drying_rod(b,w,d,h); b.flag('horizontal_crossbar_axis','X')
    elif source_id == 'P15':
        _drying_rack(b,w,d,h); b.flag('stable_a_frame_base',True)
    elif source_id == 'P16':
        _tallow_pot(b,w,d,h); b.flag('broad_wax_cap_and_drips',True)
    elif source_id == 'P17':
        _mug(b,w,d,h); b.flag('open_mouth',True); b.flag('open_loop_handle',True)
    elif source_id == 'P18':
        _open_bowl(b,'ShallowServingPlatter',w,d,h,part['materials'][0],shallow=True)
        b.flag('open_shallow_dish',True)
    elif source_id == 'P19':
        _folded_cloth(b,w,d,h); b.flag('quiet_folded_cloth',True)
    elif source_id == 'P21':
        _mortar_pestle(b,w,d,h); b.flag('hollow_mortar_open_mouth',True)
    elif source_id == 'P22':
        _hopper(b,w,d,h); b.flag('open_funnel_top',True); b.flag('open_throat',True)
    elif source_id == 'P24':
        _shutter(b,w,d,h); b.flag('static_shutter_skin_source_hinge_owns_motion',True)
    else:
        raise ValueError(f"No prop implementation for source ID {source_id}")
