"""Low-poly organics, supporting light fixtures and explicitly static FX carriers."""
import math

OWNED={'W11','L04','L08','L09','D01','D02','D03','D04','D07','D12','D14','D16','E01','E16','E17','E18','E21','E24','GraphicCarrier'}

def rings(b,name,levels,mat,sides=12,cap_ends=False):
    """Closed profile strip; rings can describe an open vessel with an inner return."""
    vs=[(rx*math.cos(i*math.tau/sides),ry*math.sin(i*math.tau/sides),z) for rx,ry,z in levels for i in range(sides)]
    fs=[]
    for j in range(len(levels)-1):
        for i in range(sides):
            k=(i+1)%sides;fs.append((j*sides+i,j*sides+k,(j+1)*sides+k,(j+1)*sides+i))
    if cap_ends:
        fs.extend([tuple(reversed(range(sides))),tuple((len(levels)-1)*sides+i for i in range(sides))])
    return b.mesh(name,vs,fs,mat)

def palette(b,name,uv):
    mat=b.material('AT01').copy();mat.name='CCK_AT01_'+name;mat['catalog_key']='AT01';mat['palette_uv']=uv
    return mat

def root(b,name,points,radii,mat,sides=7):
    # Broad rings make a solid closed faceted branch, with no noisy surface.
    verts=[]
    for p,r in zip(points,radii):
        verts.extend((p[0]+r*math.cos(i*math.tau/sides),p[1]+r*math.sin(i*math.tau/sides),p[2]) for i in range(sides))
    faces=[tuple(reversed(range(sides)))]
    for j in range(len(points)-1):
        for i in range(sides):
            k=(i+1)%sides;faces.append((j*sides+i,j*sides+k,(j+1)*sides+k,(j+1)*sides+i))
    faces.append(tuple((len(points)-1)*sides+i for i in range(sides)))
    return b.mesh(name,verts,faces,mat)

def leaf(b,name,a,c,width,mat):
    dx,dy,dz=[c[k]-a[k] for k in range(3)];length=math.sqrt(dx*dx+dy*dy+dz*dz)
    side=(-dy/length,dx/length,.12)
    mid=[a[k]+(c[k]-a[k])*.52 for k in range(3)]
    vs=[a,tuple(mid[k]+side[k]*width for k in range(3)),c,tuple(mid[k]-side[k]*width for k in range(3)),(mid[0],mid[1]-.025,mid[2]+.025)]
    return b.mesh(name,vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],mat)

def bell(b,w,d,h,mat):
    # Exterior shoulder to broad lip, then inner return to roof. No disk across mouth.
    rings(b,'HollowBell',[(w*.16,d*.16,h*.92),(w*.28,d*.28,h*.78),(w*.31,d*.31,h*.39),(w*.47,d*.47,h*.07),(w*.50,d*.50,0),
                         (w*.43,d*.43,0),(w*.39,d*.39,h*.09),(w*.25,d*.25,h*.4),(w*.22,d*.22,h*.74),(w*.10,d*.10,h*.83)],mat)
    b.cyl('BellCrown',(0,0,h*.90),w*.12,h*.12,mat,sides=10)
    b.cyl('BellShoulderClosure',(0,0,h*.84),w*.14,h*.04,mat,sides=10)
    b.torus('BellHangingEye',(0,0,h*.97),w*.08,w*.022,mat,axis='Y')
    b.flag('hollow_open_mouth',True)

def build(b,part):
    sid=part['source_id'];assert sid in OWNED,sid
    w,d,h=b.size;mat=part['materials'][0]
    if sid=='GraphicCarrier':
        b.plane('FrontEmblemSurface',(0,0,h*.5),w,h,'ART01',vertical=True);b.flag('card',True);b.flag('layer_above_opaque_backing',True)
    elif sid=='W11':
        b.plane('RecessedVatLiquid',(0,0,0),w,d,'FX_ShallowWater');b.flag('card',True);b.flag('surface_only',True)
    elif sid=='L04':
        b.box('BroadFoot',(0,0,h*.06),(w,d,h*.12),'TX09',.015)
        b.cyl('HolderStem',(0,0,h*.40),w*.09,h*.6,'TX09',sides=8)
        rings(b,'WaxDish',[(w*.10,d*.10,h*.62),(w*.46,d*.46,h*.80),(w*.40,d*.40,h*.80),(w*.09,d*.09,h*.68)],'TX09',10)
        for x in [-w*.22,0,w*.22]:b.cyl('UnlitWaxStub',(x,0,h*.84),w*.09,h*.26,'TX18',sides=8)
    elif sid=='L08':
        for i in range(3):
            a=i*math.tau/3;b.rod('BrazierLeg',(math.cos(a)*w*.33,math.sin(a)*d*.33,0),(math.cos(a)*w*.22,math.sin(a)*d*.22,h*.55),w*.045,'TX09',sides=6)
        rings(b,'OpenBrazierBowl',[(w*.15,d*.15,h*.35),(w*.5,d*.5,h*.85),(w*.45,d*.45,h*.85),(w*.12,d*.12,h*.42)],'TX09',10)
        for i in range(5):
            a=i*math.tau/5;b.cone('UnlitCoal',(math.cos(a)*w*.2,math.sin(a)*d*.2,h*.75),w*.14,w*.10,h*.2,'TX19',sides=5)
        b.flag('no_automatic_light',True)
    elif sid=='L09':
        for x in [-w*.43,w*.43]:b.box('LightAperturePier',(x,0,h*.5),(w*.14,d,h),'TX01',.025)
        for z in [h*.07,h*.93]:b.box('LightApertureLintel',(0,0,z),(w,d,h*.14),'TX01',.025)
        b.flag('open_aperture',True)
    elif sid in ('D01','D02'):
        root(b,'BentRootTrunk',[(0,0,0),(-w*.07,0,h*.28),(w*.05,d*.08,h*.62),(-w*.08,0,h)], [w*.12,w*.105,w*.07,w*.025],mat)
        for sign in [-1,1]:
            root(b,'BroadRootFork',[(0,0,h*.38),(sign*w*.2,-d*.1,h*.42),(sign*w*.39,d*.03,h*.59),(sign*w*.47,d*.14,h*.78)], [w*.075,w*.065,w*.04,w*.008],mat)
            root(b,'RootToe',[(0,0,h*.12),(sign*w*.22,d*.28,h*.055),(sign*w*.43,d*.38,0)], [w*.075,w*.04,w*.008],mat)
        b.flag('non_climbable_visual',True)
    elif sid=='D03':
        dark=palette(b,'HerbDark',(.0625,.125));light=palette(b,'HerbLight',(.1875,.125))
        for i in range(7):
            a=i*math.tau/7;x=math.cos(a)*w*.3;y=math.sin(a)*d*.3
            b.rod('HerbStem',(0,0,h*.95),(x,y,h*.12),w*.013,dark,sides=5)
            for j in [0,1]:
                z=h*(.38+j*.24);leaf(b,'BroadHerbLeaf',(x*.5,y*.5,z),(x+math.cos(a+.5)*w*.18,y+math.sin(a+.5)*d*.18,z-h*.26),w*.11,light if i%2 else dark)
        b.torus('BunchTie',(0,0,h*.84),w*.10,w*.025,'TX14',major_segments=10)
        b.flag('solid_low_overdraw_leaves',True)
    elif sid=='D04':
        cream=palette(b,'CeramicCream',(.9375,.375));brown=palette(b,'Truffle',(.3125,.125))
        for i,(x,y,s) in enumerate([(-.22,-.12,.72),(.20,.12,1),(0,-.25,.48)]):
            x*=w;y*=d;hh=h*s
            b.cone('BluntMushroomStem',(x,y,hh*.31),w*.055*s,w*.045*s,hh*.62,cream,sides=7)
            o=rings(b,'BroadMushroomCap',[(w*.06*s,d*.06*s,hh),(w*.20*s,d*.20*s,hh*.93),(w*.31*s,d*.31*s,hh*.67),(w*.26*s,d*.26*s,hh*.62)],cream,10,cap_ends=True);o.location.x=x;o.location.y=y
        b.flag('non_harvestable_dressing_shape',True)
    elif sid=='D07':
        b.rod('BrokenBoneShaft',(-w*.35,0,h*.4),(w*.4,0,h*.55),h*.22,mat,sides=7)
        for x in [-w*.32,w*.32]:b.cone('BluntBrokenEnd',(x,0,h*.5),h*.39,h*.25,h*.7,mat,axis='X',sides=7)
    elif sid in ('D12','E21'):
        b.plane('StaticAtmosphereCarrier',(0,0,h*.5),w,h,'FX_Dust',vertical=True);b.flag('card',True);b.flag('static_optional_carrier_only',True)
    elif sid=='D14':
        web=palette(b,'CobwebChalk',(.9375,.875))
        center=(-w*.46,0,h*.96)
        ends=[(w*.46,0,h*.94),(w*.40,0,h*.46),(w*.30,0,h*.08),(-w*.46,0,0)]
        for end in ends:b.rod('WebSpoke',center,end,.007,web,sides=4)
        for f in [.32,.64,.94]:
            pts=[tuple(center[k]+(p[k]-center[k])*f for k in range(3)) for p in ends]
            for a,c in zip(pts,pts[1:]):b.rod('WebArc',a,c,.005,web,sides=4)
    elif sid=='D16':
        b.box('ShelfDivider',(0,0,h*.5),(w,d,h),mat,.01)
        for x in [-w*.44,w*.44]:b.box('EndBrace',(x,0,h*.3),(w*.06,d*.86,h*.6),mat,.005)
    elif sid=='E01':
        vs=[(-w*.5,-d*.5,0),(w*.5,-d*.5,0),(w*.42,d*.5,0),(-w*.42,d*.5,0),
            (-w*.38,-d*.18,h*.45),(w*.37,-d*.23,h*.53),(w*.21,d*.46,h*.66),(-w*.29,d*.39,h*.62),
            (-w*.10,d*.05,h),(w*.14,d*.18,h*.88)]
        b.mesh('FacetedRockShoulder',vs,[(3,2,1,0),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,9,8),(5,6,9),(6,7,8,9),(7,4,8)],mat)
        b.flag('shell_back_contact',True)
    elif sid=='E16':
        vs=[(-w*.5,0,0),(w*.5,0,0),(w*.42,d*.5,h*.4),(w*.1,d*.25,h),(-w*.2,d*.2,h*.68),(-w*.5,d*.25,h*.25),
            (-w*.5,-d*.5,0),(w*.5,-d*.5,0),(w*.42,-d*.3,h*.4),(w*.1,-d*.2,h),(-w*.2,-d*.2,h*.68),(-w*.5,-d*.3,h*.25)]
        b.mesh('BroadBellLipChip',vs,[(0,1,2,3,4,5),(11,10,9,8,7,6)]+[(i,(i+1)%6,(i+1)%6+6,i+6) for i in range(6)],mat)
    elif sid=='E17':bell(b,w,d,h,mat)
    elif sid=='E18':
        b.box('BracketWallPlate',(0,d*.35,h*.5),(w*.24,d*.24,h),mat,.018)
        b.box('BellSupportArm',(w*.22,0,h*.83),(w*.72,d*.8,h*.13),mat,.018)
        b.rod('BellSupportDiagonal',(0,d*.3,h*.10),(w*.45,-d*.2,h*.76),w*.05,'TX09',sides=6)
        b.torus('BellHanger',(w*.44,-d*.24,h*.67),h*.07,h*.017,'TX09',axis='X')
        b.flag('source_sockets_m',{'wall_mount':[0,d*.47,h*.5],'bell_hanger':[w*.44,-d*.24,h*.67]})
    elif sid=='E24':
        b.box('TimberBody',(-w*.1,0,h*.5),(w*.8,d,h),mat,.015)
        for y,z,end in [(-d*.28,h*.22,w*.46),(0,h*.6,w*.5),(d*.28,h*.78,w*.34)]:
            b.extrude('BluntBrokenSplinter',[(w*.22,y-d*.16),(end,y),(w*.22,y+d*.16)],z-h*.14,z+h*.14,mat)
