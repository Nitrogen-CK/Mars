"""Expedition authoring, scoped to the four user-created maps.

Run plan() with ordinary Python; apply_current(index) inside Unreal Python.
Coordinates and dimensions in the manifest are metres, converted at the boundary.
Repeated architecture is saved as native HISM instance components, grouped by district.
Rebuild only removes actors carrying our exact ownership tag in these four maps.
"""
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
DATA = Path(__file__).resolve().parent / 'data'
OUT = ROOT / 'docs/campaigns/2026-10-15-expedition-maps'
MAPS = ['BrokenCistern', 'PilgrimsHollow', 'SevereredAqueduct', 'SunkenKitchens']
THEMES = ['Bellfold', 'Rootstep', 'Spillring', 'Bellfold']
CEILING_AMBIENT = .75
CEILING_EXPOSURE = -1.0
CEILING_LAMP_INTENSITY = 20000
# Empty construction trenches are not exploration destinations. Ground meets the lowest playable terrace;
# elevated connections have open undercrofts, so no blanket recovery-ladder invitation is needed.
BASE_FLOORS = [-.08, -.08, -4.08, -4.08]
RECOVERY = [[], [], [], []]
# Side pockets keep gated reward rooms and their upper gallery out of the primary stair approaches.
POCKETS = {
    (0,'Mourner'):dict(node='W',centre=(13,82,0),size=(18,18),origin=(13,77,0),mouth=(19,82)),
    (1,'Bell'):dict(node='M',centre=(75,103,4),size=(22,22),origin=(73,99,4),mouth=(85,103)),
    (2,'Bell'):dict(node='UW',centre=(66,124,8),size=(22,22),origin=(64,120,8),mouth=(66,111)),
}
OWN = 'Mars.Expedition.Authoring.20261016'
CRYPT = '/Game/Mars/Environment/Meshes/Crypt/'
CAMP = '/Game/Mars/Environment/Meshes/Camp/'
BOX = '/Game/Mars/Environment/Meshes/Boxes/'
MAT = '/Game/Mars/Environment/Materials/Instances/'


def mesh(name):
    if name.startswith(('StoneBlock','Plinth','Sarcophagus','Tomb')): name='Box'+name
    prefix = CAMP if name.startswith('Camp') else BOX if name.startswith(('Box', 'StoneBlock', 'Plinth', 'Sarcophagus', 'Tomb')) else CRYPT
    return prefix + name + '_Mars_SM'


def rotate(x, y, yaw):
    a = math.radians(yaw)
    return x*math.cos(a)-y*math.sin(a), x*math.sin(a)+y*math.cos(a)


class Layout:
    def __init__(self, concept, index):
        self.data, self.index = concept, index
        self.nodes = {n['id']: n for n in concept['nodes']}
        self.items, self.entities, self.starts, self.routes = [], [], [], []
        self.region = 'Ground'
        self.theme = THEMES[index]

    def add(self, name, at, scale=(1,1,1), yaw=0, collision=True, base=False):
        self.items.append(dict(mesh=mesh(name), at=list(at), scale=list(scale), yaw=yaw,
                               collision=collision, region=self.region, theme=self.theme if not base else 'Original'))
        if name=='CampBannerFork':
            # The cloth mesh begins 50 cm above its origin and contains no pole.
            self.fitted('CryptPierH3m5',(at[0],at[1],at[2]+1.3),(0.24,0.24,2.6))

    def fitted(self, name, centre, dims, yaw=0, base=False, collision=True):
        b = BOUNDS[mesh(name)]
        size = [(b['max'][i]-b['min'][i])/100 for i in range(3)]
        scale = [dims[i]/size[i] for i in range(3)]
        local = [(b['max'][i]+b['min'][i])/200*scale[i] for i in range(3)]
        dx,dy=rotate(local[0],local[1],yaw)
        self.add(name,(centre[0]-dx,centre[1]-dy,centre[2]-local[2]),scale,yaw,collision,base)

    def floor(self, x,y,z,w,d,yaw=0, supports=True):
        # Authored texel density: tiles remain close to 4 m rather than one stretched slab.
        nx,ny=max(1,math.ceil(w/4)),max(1,math.ceil(d/4))
        for i in range(nx):
            for j in range(ny):
                ox,oy=rotate((i+.5)*w/nx-w/2,(j+.5)*d/ny-d/2,yaw)
                self.fitted('CryptFloor4x4',(x+ox,y+oy,z-.2),(w/nx+.012,d/ny+.012,.4),yaw)
        if supports:
            # Buried foundation mass; top stays below the paving to avoid coplanar faces.
            self.fitted('StoneBlock2m',(x,y,(z-8.4)/2),(w-.1,d-.1,z+7.6),yaw)

    def pitched_panel(self, centre, dims, pitch):
        """Fit the roof mesh in its own frame, then rotate its actual bounds centre about the requested centre."""
        name='CryptRoof4x4'; b=BOUNDS[mesh(name)]
        scale=[dims[i]/((b['max'][i]-b['min'][i])/100) for i in range(3)]
        c=[(b['min'][i]+b['max'][i])/200*scale[i] for i in range(3)]
        angle=math.radians(pitch)
        offset=(math.cos(angle)*c[0]-math.sin(angle)*c[2],c[1],math.sin(angle)*c[0]+math.cos(angle)*c[2])
        self.add(name,tuple(centre[i]-offset[i] for i in range(3)),scale)
        self.items[-1]['pitch']=pitch

    def entity(self, name, at, yaw=0, note='', pitch=0):
        self.entities.append(dict(cls='Mars_'+name+'_EntityScript',at=list(at),yaw=yaw,pitch=pitch,region=self.region,note=note))

    def lantern(self,x,y,z,yaw=0,light=True):
        self.add('CampLantern',(x,y,z),(1.3,1.3,1.3),yaw,False,True)
        if light:
            self.items.append(dict(light=True,at=[x,y,z+.36],region=self.region,intensity=1300,radius=6.5))

    def boundary_open(self, point, node):
        for (index,kind),p in POCKETS.items():
            if index==self.index and p['node']==node['id'] and math.hypot(point[0]-p['mouth'][0],point[1]-p['mouth'][1])<5:
                return True
        for node_id,side in RECOVERY[self.index]:
            if node['id']!=node_id: continue
            x,y,z=node['at']; w,d=node['size']
            px,py=[(x-w/2,y),(x+w/2,y),(x,y-d/2),(x,y+d/2)][side]
            if math.hypot(point[0]-px,point[1]-py)<3.0: return True
        # Leave an oversize, continuous aperture wherever a route enters this district.
        for e in self.data['edges']:
            if node['id'] not in (e['a'],e['b']): continue
            seq=[self.nodes[e['a']]['at']]+[v for v in e['via']]+[self.nodes[e['b']]['at']]
            q=seq[1] if node['id']==e['a'] else seq[-2]
            a=node['at']; dx,dy=q[0]-a[0],q[1]-a[1]; ln=math.hypot(dx,dy)
            if ln<.1: continue
            t=((point[0]-a[0])*dx+(point[1]-a[1])*dy)/ln**2
            cross=abs((point[0]-a[0])*dy-(point[1]-a[1])*dx)/ln
            if t>0 and cross<e['width']/2+3: return True
        return False

    def district(self,n):
        self.region=n['id']+'_'+n['name'].replace(' ','_')
        x,y,z=n['at']; w,d=n['size']; kind=n['kind']
        self.floor(x,y,z,w,d)
        if kind=='spawn':
            # Four starts share one entrance tag. Facing is toward the first district.
            target=self.nodes[n['note']]['at']; yaw=math.degrees(math.atan2(target[1]-y,target[0]-x))
            for slot,(ox,oy) in enumerate([(-1.2,-1.2),(-1.2,1.2),(1.2,-1.2),(1.2,1.2)]):
                self.starts.append(dict(group=n['id'],slot=slot,at=[x+ox,y+oy,z+.9],yaw=yaw))
            ux,uy=rotate(1,0,yaw)
            self.fitted('CryptExtractionArch',(x-ux*3,y-uy*3,z+1.55),(3.8,.8,3.5),yaw+90)
            self.add('CampBannerFork',(x-2.7,y-2.7,z),base=True)
            self.lantern(x+2.7,y-2.7,z)
            # An expedition entrance is a provision point: don't send a fresh player to harvest empty-handed.
            tx,ty=x-uy*2.7,y+ux*2.7
            self.add('BoxPlinthPickup',(tx,ty,z),yaw=yaw,base=True)
            self.entity('Sandbox_Cleaver',(tx,ty,z+.95),yaw,note='Entrance harvesting tool')
            self.entity('WorldItem_Backpack',(x+uy*2.7,y-ux*2.7,z+.3),yaw,note='Entrance cargo pack')
            return
        # Perimeter bays frame broad courts; route mouths remain open. Tall solid bays alternate with railings.
        for side,ln in enumerate([w,d,w,d]):
            count=max(1,round(ln/4)); unit=ln/count
            for j in range(count):
                t=-ln/2+(j+.5)*unit
                px,py,yaw = [(x+t,y-d/2,0),(x+w/2,y+t,90),(x-t,y+d/2,180),(x-w/2,y-t,270)][side]
                if self.boundary_open((px,py),n): continue
                # The open inner edges are low and see-through; end bays have mass and vertical rhythm.
                tall=(j+side+self.index)%4==0 and kind not in ('hunt','kitchen')
                if tall:
                    self.fitted('CryptWallNiche2m',(px,py,z+1.55),(unit,.7,3.5),yaw)
                else:
                    self.fitted('CryptBalustrade4m',(px,py,z+.6),(unit,.45,1.2),yaw)
                if j%2==0:
                    self.add('CryptPierH7m5' if tall else 'CryptPierH3m5',(px,py,z),(1,1,1),yaw)
                    if not tall: self.lantern(px,py,z+3.5)
        # Local silhouettes. Arcaded side galleries read as buildings around a place, with usable open middles.
        if kind!='hunt':
            for sign in [-1,1]:
                px,py=x+sign*(w/2-3),y-d/2+2.5
                if self.boundary_open((px,py),n): continue
                for bay in range(2):
                    self.add('CryptArcadeBay4m',(px-4+4*bay,py,z))
                self.add('CryptRoof4x4',(px-4,py,z))
                self.add('CryptRoof4x4',(px,py,z))
        # Purposeful corner vignettes, outside the broad centre travel strips.
        corners=[(-1,-1),(1,1)] if kind in ('hunt','forage') else []
        for k,(sx,sy) in enumerate(corners):
            px,py=x+sx*(w/2-3),y+sy*(d/2-3)
            if self.boundary_open((px,py),n): continue
            self.add('BoxCrateStack2',(px,py,z),yaw=17+k*81,base=True)
            self.add('CampBarrel',(px+sx*1.4,py,z),yaw=k*41,base=True)
            self.add('CampCandleCluster',(px,py+sy*1.3,z),collision=False,base=True)
        if kind=='kitchen': self.kitchen(n)
        if kind=='forage': self.forage(n)
        if kind=='hunt': self.hunt(n)

    def kitchen(self,n):
        x,y,z=n['at']
        # Two facing work lines, 6 m apart. Operators use the protected 4 m central aisle.
        for i,station in enumerate(['Cutting','Searing','Fry','Batter','Tumbler','Mortar']):
            row=i//3; py=y-4+(i%3)*4
            self.entity(station+'Station',(x+(-3 if row==0 else 3),py,z),180 if row==0 else 0)
        self.add('CampRugRunner',(x,y,z+.03),(1.4,2.3,1),base=True,collision=False)
        # The hearth belongs beside the work lines; it must never cap the central arrival aisle.
        self.add('CampCauldron',(x+10,y+6,z),base=True)
        self.add('CampFirepit',(x+10,y+6,z),base=True)
        # Equipment flanks the arrival aisle, accessible before choosing either work line.
        for sx in [-1,1]: self.add('BoxPlinthPickup',(x+sx*3,y+8,z),base=True)
        for sx in [-1,1]:
            self.add('CampBannerFork',(x+sx*7,y-7,z),(1.4,1.4,1.4),base=True)
            self.lantern(x+sx*7,y-6,z)
        self.entity('Sandbox_Cleaver',(x-3,y+8,z+.95))
        self.entity('Platter',(x+3.5,y+8,z+.95))
        self.entity('Platter_Large',(x+2.5,y+8,z+.95))
        # Ingredients must be earned on the expedition; the kitchen provides equipment, not a free finished run.

    def forage(self,n):
        x,y,z=n['at']
        if n['id']=='R':
            self.entity('Expedition_Crawler',(x+6,y-4,z+.8),180,note='Visible guard of the first harvesting approach')
            self.entity('Expedition_NavField',(x+6,y-4,z))
            # Keep the district centreline clear from every arrival. Harvest beds occupy the west side wall.
            for i in range(3):
                self.entity('Expedition_MushroomBed',(x-9,y-4+i*4,z+.8))
                self.fitted('StoneBlock1m',(x-9,y-4+i*4,z+.4),(2.4,1.8,.8))
                self.fitted('CryptWallNiche2m',(x-10,y-4+i*4,z+1.55),(3.5,.7,3.5),90)
        elif n['id']=='F':
            # A small cracking station, with its actual blunt implement; not a test row of five unexplained nuts.
            self.add('BoxPlinthPickup',(x,y+4,z),base=True)
            self.entity('Expedition_Bellnut',(x-.4,y+4,z+.96))
            self.entity('Sandbox_Tenderizer',(x+.5,y+4,z+.96))
        else:
            # The spice censer hangs from a grounded gantry at its actual 2.5 m pivot height.
            self.entity('ForageCenser',(x,y+4,z))
            for sx in [-1,1]: self.fitted('CryptPierH3m5',(x+sx*1.7,y+4,z+1.3),(.5,.5,2.6))
            self.fitted('CryptWall4m',(x,y+4,z+2.65),(3.8,.5,.4))

    def hunt(self,n):
        x,y,z=n['at']
        self.entity('Expedition_Crawler',(x,y,z+.8),note='Authored local bounds; real spider rig')
        self.entity('Expedition_NavField',(x,y,z))
        # The guarded butcher table is the protein objective, rather than unrelated food scattered on paving.
        self.add('BoxPlinthPickup',(x+4,y+5,z),base=True)
        self.entity('FoodItem_MeatSlab',(x+4,y+5,z+1.0),note='Guarded butcher-table protein; no sever-to-food claim')
        for px in [-9,9]:
            self.fitted('CryptDais4x4H1m5',(x+px,y+7,z+.75),(4,4,1.5))
            self.add('CryptPierH7m5',(x+px,y+7,z+1.5))

    def connector(self,e):
        self.region='Travel_'+e['a']+'_'+e['b']
        points=[self.nodes[e['a']]['at']]+e['via']+[self.nodes[e['b']]['at']]
        for seg,(pa,pb) in enumerate(zip(points,points[1:])):
            a,b=list(pa),list(pb)
            if a[2]>b[2]: a,b=b,a
            dx,dy=b[0]-a[0],b[1]-a[1]; dist=math.hypot(dx,dy)
            if dist<.1: continue
            ux,uy=dx/dist,dy/dist; yaw=math.degrees(math.atan2(dy,dx)); width=e['width']
            # Distance to footprint boundary along centreline, not the corner radius.
            def radius(p):
                for n in self.nodes.values():
                    if list(n['at'])==p:
                        return min(n['size'][0]/2/abs(ux) if abs(ux)>.001 else 1e6,
                                   n['size'][1]/2/abs(uy) if abs(uy)>.001 else 1e6)
                return width/2
            ra,rb=radius(a),radius(b)
            rise=b[2]-a[2]; flights=round(rise/4); run=flights*7.2+max(0,flights-1)*2
            start=max(0,min(ra-1,dist-rb-1-run)); end=start+run
            def strip(t0,t1,z):
                t0=max(t0,ra-.04); t1=min(t1,dist-rb+.04)
                if t1-t0>.05:
                    mid=(t0+t1)/2
                    elevated=z-BASE_FLOORS[self.index]>=3
                    self.floor(a[0]+ux*mid,a[1]+uy*mid,z,t1-t0+.08,width,yaw,supports=not elevated)
                    if elevated:
                        for t_pier in range(math.ceil(t0/12),math.ceil(t1/12)):
                            t_pier=t_pier*12+3
                            if not t0<t_pier<t1: continue
                            for side in [-1,1]:
                                px=a[0]+ux*t_pier-side*uy*(width/2-.55)
                                py=a[1]+uy*t_pier+side*ux*(width/2-.55)
                                bottom=BASE_FLOORS[self.index]
                                if self.index==0 and 60<=px<=120 and 52<=py<=96:
                                    bottom=-2.0  # The bridge bears on the actual recessed basin floor.
                                self.fitted('CryptPierH7m5',(px,py,(z+bottom-.3)/2),(1,1,z-bottom-.3))
            if flights:
                strip(0,start,a[2]); t=start
                for f in range(flights):
                    cx,cy=a[0]+ux*t,a[1]+uy*t
                    # Local X across the stair, local -Y ascending. Pivot is the lower left edge.
                    ox,oy=rotate(-width/2,0,yaw+90)
                    self.add('CryptStairFlight',(cx+ox,cy+oy,a[2]+f*4),(width/3,1,1),yaw+90)
                    # Physical cheeks protect the exposed sides throughout each rise.
                    for side in [0,width]:
                        sx,sy=rotate(side-width/2,0,yaw+90)
                        self.add('CryptStairCheekLow',(cx+sx,cy+sy,a[2]+f*4),(1 if side==0 else -1,1,1),yaw+90)
                    t+=7.2
                    if f<flights-1: strip(t,t+2,a[2]+(f+1)*4); t+=2
                strip(end,dist,b[2])
            else: strip(0,dist,a[2])
            # Railings only in the exposed span; omit inside both destination districts.
            span0,span1=max(ra+.5,0),min(dist-rb-.5,dist)
            for t in range(math.ceil(span0/4),math.floor(span1/4)):
                t=t*4+2
                if flights and start-1<t<end+1: continue
                z=a[2] if t<start else b[2]
                for sign in [-1,1]:
                    px=a[0]+ux*t-sign*uy*width/2; py=a[1]+uy*t+sign*ux*width/2
                    self.fitted('CryptBalustrade4m',(px,py,z+.6),(4,.4,1.2),yaw)
                    if t%16==2:
                        self.add('CryptPierH3m5',(px,py,z))
                        self.lantern(px,py,z+3.5)
            self.routes.append(dict(a=a,b=b,width=width,start=start,end=end,flights=flights))
            for p in e['via']: self.floor(p[0],p[1],p[2],width+2,width+2)

    def puzzle(self, node_id, kind):
        n=self.nodes[node_id]; x,y,z=n['at']; self.region='Puzzle_'+kind
        # Reward room occupies the north edge of the broad court, with no path behind the gate.
        origin=(x,y+n['size'][1]/2-12,z)
        if (self.index,kind) in POCKETS:
            p=POCKETS[(self.index,kind)]; origin=p['origin']
            self.floor(*p['centre'],*p['size'])
            if self.index==2: self.floor(66,112,8,8,6)
        elif self.index==2 and kind=='Mourner': origin=(181,51,0)
        def loc(px,py,pz=0): return (origin[0]+px,origin[1]+py,origin[2]+pz)
        # Roofed 8 x 4 reliquary behind a 2 m scripted opening; gap matched to moving leaf.
        half=3 if kind=='Porter' else 4.8
        for sign in [-1,1]: self.fitted('CryptWall2m',loc(sign*(half+1)/2,8,1.55),(half-1,.65,3.5))
        for px in [-half,half]: self.fitted('CryptWall4m',loc(px,10,1.55),(4,.65,3.5),90)
        for px in [-half/2,half/2]: self.fitted('CryptWall4m',loc(px,12,1.55),(half,.65,3.5))
        roof_width=2*half+.7; panels=math.ceil(roof_width/4)
        for panel in range(panels):
            px=-roof_width/2+(panel+.5)*roof_width/panels
            self.fitted('CryptRoof4x4',loc(px,10,3.53),(roof_width/panels,4.7,.5))
        for side in [-2.5,2.5]:
            self.fitted('CryptPierH3m5',loc(side,7,.4),(.55,.55,.8))
            self.lantern(*loc(side,7,.8))
        if kind=='Mourner':
            self.entity('Gauntlet_Mourner_ChefPlate',loc(-1.8,4.2),90)
            self.entity('Gauntlet_Mourner_PackPlate',loc(1.8,4.2),90)
            self.entity('Gauntlet_Mourner_AlcoveGate',loc(0,8),90)
            self.entity('Gauntlet_Truffle',loc(0,10.5,.3))
            self.entity('FoodItem_Mushroom',loc(1.8,10.5,.3))
            self.entity('WorldItem_Backpack',loc(4,3,.2),note='Solo weight available locally')
        elif kind=='Bell':
            self.fitted('CryptWallNiche2m',loc(-4.3,2,1.55),(3,.6,3.5),90)
            self.fitted('CryptWallNiche2m',loc(5.3,6,5.55),(3,.6,3.5),90)
            self.entity('Gauntlet_Bell_CircleSeal',loc(-4,2,1.2),0,pitch=-90)
            # Upper seal reached by a real 4 m flight, with an observation landing above the lower seal.
            # The court return passes beneath this landing. The stair bears its front edge; rear piers carry the back.
            self.floor(origin[0]+5,origin[1]+6.7,z+4,5,5,supports=False)
            for px in [2.85,7.15]:
                self.fitted('CryptPierH3m5',loc(px,8.95,1.8),(.5,.5,3.6))
            self.add('CryptStairFlight',loc(6,-3),(1,1,1),180)
            self.entity('Gauntlet_Bell_TriangleSeal',loc(5,6,5.1),180,pitch=-90)
            self.entity('Gauntlet_Bell_Sequence',loc(-3.2,6.5),90)
            self.fitted('CryptWallFriezeOnion2m',loc(0,7.75,2.85),(2.8,.18,.6))
            # Same cylinder / cone / arrow silhouettes and reading direction as the existing Bellkeeper clue.
            for primitive,px,pz,scale,pitch,roll in [
                ('Cylinder',.7,2.85,(.5,.5,.04),0,90),
                ('Cube',.05,2.85,(.3,.04,.06),0,0),
                ('Cone',-.2,2.85,(.2,.04,.2),90,0),
                ('Cone',-.7,2.85,(.5,.04,.5),0,0),
            ]:
                self.items.append(dict(mesh='/Engine/BasicShapes/'+primitive,at=list(loc(px,7.6,pz)),
                    scale=list(scale),pitch=pitch,roll=roll,yaw=0,collision=False,region='Glyph_Bell_Clue',theme='Original'))
            self.entity('Gauntlet_Bell_ReliquaryGate',loc(0,8),90)
            self.entity('Gauntlet_Root',loc(0,10.5,.3))
            self.entity('FoodItem_Pickle',loc(1.5,10.5,.3))
        elif kind=='Porter':
            self.entity('Gauntlet_Porter_Slab',loc(0,4),90)
            self.entity('Gauntlet_Porter_Gate',loc(0,8),90)
            self.entity('Gauntlet_Porter_Lamps',loc(0,7.9,2.7),-90)
            self.entity('Gauntlet_Porter_Chain',loc(2,8.35,2.6),90)
            self.entity('Expedition_Porter_PackInside',loc(0,10.2))
            self.entity('WorldItem_Backpack',loc(3,2,.2))
            self.entity('FoodItem_Puffer',loc(0,10.5,.3))
        # Same shape language as the existing glyphs, readable before interaction.
        self.add('CampBannerFork',loc(-4,5),base=True)

    def timed_travel(self):
        node=self.nodes[['B','L','S','SE'][self.index]]
        x,y,z=node['at']; self.region='Travel_CenserWindow'
        item_start,entity_start=len(self.items),len(self.entities)
        # Left: direct timed lane. Right: permanently open protected bypass. Both rejoin beyond the shutter.
        for px in [-6,0,6]:
            for py in [3,7]: self.fitted('CryptWall4m',(x+px,y+py-4.5,z+1.55),(4,.65,3.5),90)
        for px,w in [(-5.15,1.7),(-1.15,2.3)]:
            self.fitted('CryptWall2m',(x+px,y+2,z+1.55),(w,.7,3.5))
        for px,py in [(1.6,-1),(4.7,1.5)]: self.add('BoxCrate1m2',(x+px,y+py,z),base=True)
        def ent(name,px,py,pz=0,yaw=0): self.entity('Gauntlet_Censer_'+name,(x+px,y+py-4.5,z+pz),yaw)
        # Chain brackets are on the faces of real posts, outside the movement lane.
        ent('Chain',-.36,1,2.6,180); ent('Chain',-1.5,8,2.6,90)
        self.fitted('CryptPierH3m5',(x,y-3.5,z+1.65),(.7,.7,3.3))
        self.fitted('CryptPierH3m5',(x-1.5,y+3.14,z+1.65),(.7,.7,3.3))
        # 250 cm arm + 50 cm clearance: the hazard's pivot is supported at 3 m, never hung in open sky.
        self.fitted('CryptWall4m',(x-3.3,y,z+3.15),(6,.55,.45))
        for sx in [-6.3,-.3]:
            bottom=-2.0 if self.index==0 and sx==-6.3 else z
            self.fitted('CryptPierH3m5',(x+sx,y,(bottom+z+3)/2),(.5,.5,z+3-bottom))
        ent('Lamps',-3.3,6.4,2.7,-90)
        ent('Shutter',-3.3,6.5,0,90)
        self.entity('Gauntlet_Censer',(x-3.3,y,z))
        self.lantern(x+3.5,y-4,z); self.lantern(x+3.5,y+4,z)
        if self.index==0:
            # Cistern's crossing runs east-west. Align both lanes with travel, not across the deck.
            for v in self.items[item_start:]+self.entities[entity_start:]:
                ox,oy=rotate(v['at'][0]-x,v['at'][1]-y,-90)
                v['at'][0],v['at'][1]=x+ox,y+oy
                if 'yaw' in v: v['yaw']-=90

    def enclosure(self):
        w,d=self.data['envelope']; self.region='Enclosing_Casemates'
        # Ground is reachable circulation, not an empty eight-metre basement under every plaza.
        base=BASE_FLOORS[self.index]
        for gx in range(-4,int(w)+5,4):
            for gy in range(-4,int(d)+5,4):
                if self.index==0 and 60<=gx<=120 and 52<=gy<=96: continue
                self.floor(gx,gy,base,4,4,supports=False)
        for side,ln in enumerate([w+8,d+8,w+8,d+8]):
            count=math.ceil(ln/4)
            for j in range(count):
                t=(j+.5)*ln/count-4
                px,py,yaw=[(t,-4,0),(w+4,t,90),(w-t,d+4,180),(-4,d-t,270)][side]
                # Successive casemate bays change height in long, deliberate groups.
                h=16+(4 if (j//5+side+self.index)%3==0 else 0)
                for level in range(6 if h==16 else 7):
                    self.fitted('CryptWall4m',(px,py,-6.25+level*3.5),(ln/count,.85,3.5),yaw)
                if j%3==0:
                    self.add('CryptPierH15m5',(px,py,0),(1.6,1.6,1),yaw)
                    self.add('CryptFinialPotlid',(px,py,15.5),(1.6,1.6,1.6),yaw)
                if j%6==0: self.lantern(px,py,8,yaw)
        # Tall, partial colonnades beyond the courts give parallax and frame the skyline without closing the sky.
        for n in self.nodes.values():
            if n['kind'] not in ('area','kitchen'): continue
            x,y,z=n['at']; rw,rd=n['size']
            # Every retained rib has two matching springing supports; route mouths take precedence.
            if n['id'] in ('P','M','N','K'):
                for sy in [-1,1]:
                    py=y+sy*(rd/2-2)
                    ends=[x-rw/2+2,x+rw/2-2]
                    if any(self.boundary_open((px,py),n) for px in ends): continue
                    self.fitted('CryptVaultRibOct24',(x,py,z+12.5),(rw-4,.6,4))
                    for px in ends:
                        self.fitted('CryptPierH11m5',(px,py,z+5.4),(1.5,1.5,10.8))
            else:
                for sx in [-1,1]:
                    px=x+sx*(rw/2-2); py=y+rd/2-2
                    if not self.boundary_open((px,py),n):
                        self.add('CryptPierH11m5',(px,py,z),(1.3,1.3,1))
        # No identical empty furniture vignettes in every plaza. Dressing is authored at functional destinations.

        # Recovery from the scenic base: one obvious ladder to each major elevation, at a protected outside face.
        for node_id,side in RECOVERY[self.index]:
            n=self.nodes[node_id]; x,y,z=n['at']; rw,rd=n['size']
            lx,ly,yaw=[(x-rw/2-.4,y,180),(x+rw/2+.4,y,0),(x,y-rd/2-.4,-90),(x,y+rd/2+.4,90)][side]
            for (index,kind),p in POCKETS.items():
                if index!=self.index or p['node']!=node_id: continue
                px,py,pz=p['centre']; pw,pd=p['size']
                if abs(lx-px)<pw/2 and abs(ly-py)<pd/2:
                    lx,ly=[(px-pw/2-.4,py),(px+pw/2+.4,py),(px,py-pd/2-.4),(px,py+pd/2+.4)][side]
            ux,uy=rotate(1,0,yaw)
            self.region='Recovery_'+node_id+'_'+str(side)
            self.entity('Expedition_RecoveryLadder',(lx,ly,-8),yaw,note='Scenic-base recovery to '+node_id)
            self.entities[-1]['props']={'RiseCm':(z+8)*100}
            # Upper landing projects through the railing and leaves a 2 m dismount runway.
            self.floor(lx-ux*.4,ly-uy*.4,z,2.5,3,yaw,supports=False)
            self.lantern(lx+ux,ly+uy,-7.8)

    def roofline(self):
        # Deliberate background building plots occupy the negative space around the authored routes.
        # Protect the complete route width, every plaza and every reserved void; these never replace playable surfaces.
        self.region='District_Roofline'
        w,d=self.data['envelope']
        def distance_to_rect(x,y,n):
            return math.hypot(max(0,abs(x-n['at'][0])-n['size'][0]/2),max(0,abs(y-n['at'][1])-n['size'][1]/2))
        def reserved(x,y):
            for (index,kind),p in POCKETS.items():
                if index!=self.index: continue
                if abs(x-p['centre'][0])<p['size'][0]/2+5 and abs(y-p['centre'][1])<p['size'][1]/2+5: return True
            if any(distance_to_rect(x,y,n)<7 for n in self.nodes.values()): return True
            for e in self.data['edges']:
                points=[self.nodes[e['a']]['at']]+e['via']+[self.nodes[e['b']]['at']]
                for a,b in zip(points,points[1:]):
                    dx,dy=b[0]-a[0],b[1]-a[1]; ln=dx*dx+dy*dy
                    t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/max(.001,ln)))
                    if math.hypot(x-a[0]-dx*t,y-a[1]-dy*t)<e['width']/2+6: return True
            if self.index==0 and 52<x<129 and 45<y<105: return True
            if self.index==2 and 80<x<160 and 69<y<111: return True
            if self.index==3 and 64<x<118 and 66<y<111: return True
            return False
        plots={}
        for ix in range(9,int(w)-6,8):
            for iy in range(9,int(d)-6,8):
                if reserved(ix,iy): continue
                closest=min(self.nodes.values(),key=lambda n:distance_to_rect(ix,iy,n))
                plots[(ix,iy)]=closest['at'][2]+4.5+(2 if (ix//24+iy//24)%3==0 else 0)
        for (ix,iy),top in plots.items():
                # Foundation hull and individual stone courses keep the silhouette grounded in the same kit.
                self.fitted('StoneBlock2m',(ix,iy,(top-8)/2),(7.95,7.95,top+8))
                for side in range(4):
                    px,py,yaw,nx,ny=[(ix,iy-4,0,ix,iy-8),(ix+4,iy,90,ix+8,iy),(ix,iy+4,180,ix,iy+8),(ix-4,iy,270,ix-8,iy)][side]
                    bottom=plots.get((nx,ny),-8)
                    if bottom>=top: continue
                    for level in range(math.ceil((top-bottom)/3.5)):
                        h=min(3.5,top-bottom-level*3.5)
                        for offset in [-2,2]:
                            ox,oy=rotate(offset,0,yaw)
                            self.fitted('CryptWall4m',(px+ox,py+oy,bottom+level*3.5+h/2),(4,.45,h),yaw)
                    self.fitted('CryptBalustrade4m',(px,py,top+.5),(8,.35,1),yaw)
                self.floor(ix,iy,top,8,8,supports=False)
                if (ix//8+iy//8)%4==0: self.add('CryptFinialPotlid',(ix,iy,top),(1.6,1.6,1.6))

    def monumental(self):
        # A deliberate skyline and distant anchor for each layout, rather than repeated room props.
        if self.index==0:
            self.region='Cistern_Spout'
            self.fitted('CryptPortal6m',(90,120,8),(18,2,8))
            # Seat the nozzle's actual lower bounds on the arch crown, clear of the route underneath.
            self.add('CryptSpoutLadle',(90,120,12.9),(3,3,3),90)
            # Basin floor is lower than all banks. It is scenic water, fenced by the bank parapets.
            self.region='Flooded_Basin'
            self.fitted('StoneBlock2m',(90,75,-2.2),(64,50,.4))
        elif self.index==1:
            self.region='Hollow_Belfry'
            self.fitted('CryptPortal6m',(119,158,16),(24,2.5,8))
            self.add('CryptFinialPotlid',(119,158,20),(3,3,3))
        elif self.index==2:
            self.region='Broken_Aqueduct'
            for px in [66,78,162,174]:
                self.add('CryptPierH15m5',(px,102,-7.5),(1.8,1.8,1))
            # Drains belong against the gallery wall, clear of stair arrivals and the Bell pocket's central mouth.
            for px in [60,78,162,180]:
                self.add('CryptSpoutLadle',(px,108,8),(2,2,2),-90 if px<120 else 90)
            for x in list(range(52,80,4))+list(range(160,188,4)):
                self.add('CryptArcadeBay4m',(x,108,8))
            self.region='Dry_Riverbed'
            self.floor(120,78,-4,90,36)
            for x in [88,98,142,152]:
                self.add('CryptFloorEdgeBroken4m',(x,85,-3.95),(1,1,1),x*7)
        else:
            self.region='Sunken_Choir'
            self.fitted('CryptPortal6m',(90,143,8),(24,2,8))

    def ceiling(self):
        # Three continuous masonry vaults enclose the entire reserve. Openings remain spatial, not holes to a skybox.
        w,d=self.data['envelope']; spring=max(n['at'][2] for n in self.nodes.values())+12
        rise=[6,7,6,5][self.index]; left=-6; bays=[3,4,3,2][self.index];span=(w+12)/bays
        base=BASE_FLOORS[self.index]
        def protected(x,y):
            for n in self.nodes.values():
                if abs(x-n['at'][0])<n['size'][0]/2+2 and abs(y-n['at'][1])<n['size'][1]/2+2:
                    return True
            for e in self.data['edges']:
                pts=[self.nodes[e['a']]['at']]+e['via']+[self.nodes[e['b']]['at']]
                for a,b in zip(pts,pts[1:]):
                    dx,dy=b[0]-a[0],b[1]-a[1]; length=dx*dx+dy*dy
                    t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/max(.001,length)))
                    if math.hypot(x-a[0]-dx*t,y-a[1]-dy*t)<e['width']/2+2.5: return True
            for (index,_),p in POCKETS.items():
                if index==self.index and abs(x-p['centre'][0])<p['size'][0]/2+2 and abs(y-p['centre'][1])<p['size'][1]/2+2:
                    return True
            return False
        # Thick perimeter backing carries the vault springing and seals the upper wall to its underside.
        self.region='Ceiling_Perimeter'
        for x,y,width,depth in [(w/2,-5,w+12,2),(w/2,d+5,w+12,2),(-5,d/2,2,d+12),(w+5,d/2,2,d+12)]:
            nx,ny=max(1,math.ceil(width/4)),max(1,math.ceil(depth/4))
            for ix in range(nx):
                for iy in range(ny):
                    for iz in range(math.ceil((spring-base)/3.5)):
                        bottom=base+iz*3.5; height=min(3.5,spring-base-iz*3.5)+.04
                        self.fitted('CryptWall4m',(x-width/2+(ix+.5)*width/nx,y-depth/2+(iy+.5)*depth/ny,bottom+height/2),
                                    (width/nx+.03,depth/ny+.03,height))
        for bay in range(bays):
            self.region='Ceiling_Vault_'+str(bay)
            x0=left+bay*span; nx=math.ceil(span/4); ny=math.ceil((d+12)/4)
            def height(x):
                t=2*(x-x0)/span-1
                return spring+rise*(1-t*t)
            for ix in range(nx):
                a=x0+ix*span/nx; b=x0+(ix+1)*span/nx; za,zb=height(a),height(b)
                pitch=math.degrees(math.atan2(zb-za,b-a))
                for iy in range(ny):
                    y=-6+(iy+.5)*(d+12)/ny
                    self.pitched_panel(((a+b)/2,y,(za+zb)/2+.3),(math.hypot(b-a,zb-za)+.06,(d+12)/ny+.06,.6),pitch)
                # Masonry tympana close both barrel ends; a flat spring-height wall leaves sky-shaped crescents.
                top=max(za,zb)+.65
                for end_y in [-5,d+5]:
                    self.fitted('CryptWall4m',((a+b)/2,end_y,(spring+top)/2),(b-a+.06,2,top-spring+.06))
            # Each visible transverse arch has two actual feet; no columns in districts, route mouths or puzzle pockets.
            for y in [-5]+list(range(14,int(d),20))+[d+5]:
                ends=[x0+.8,x0+span-.8]
                if 0<y<d and any(protected(x,y) for x in ends): continue
                self.fitted('CryptVaultRibOct24',((ends[0]+ends[1])/2,y,spring+rise/2-.05),(span-1.6,.9,rise+.2))
                for x in ends:
                    foot=-2.4 if self.index==0 and 58<x<122 and 50<y<100 else base
                    self.fitted('CryptPierH15m5',(x,y,(foot+spring)/2),(1.8,1.8,spring-foot+.2))
        # Readable arrival compression under the monumental roof: the existing gatehouses keep their low roofs.
        self.region='Ceiling_Fixtures'
        for n in self.nodes.values():
            if n['kind']=='spawn': continue
            x,y,z=n['at']
            bay=max(0,min(bays-1,int((x-left)/span)));t=2*(x-(left+bay*span))/span-1
            roof=spring+rise*(1-t*t)
            lamp_base=min(roof-3,z+7)
            self.add('CampLantern',(x,y,lamp_base),(3,3,3),collision=False,base=True)
            self.items[-1]['suspended']=True
            bounds=BOUNDS[mesh('CampLantern')]
            top=lamp_base+bounds['max'][2]/100*3
            gap=roof-top
            links=max(1,math.ceil(gap/.20))
            for k in range(links):
                self.add('CryptChainLink',(x,y,top+(k+.5)*gap/links),(2.5,2.5,2.5),yaw=90*(k%2),collision=False,base=True)
            self.items.append(dict(light=True,at=[x,y,lamp_base+.8],region=self.region,
                                   intensity=CEILING_LAMP_INTENSITY,radius=28,color=[.85,.78,.65,1]))

    def build(self):
        self.enclosure()
        for n in self.nodes.values(): self.district(n)
        for e in self.data['edges']: self.connector(e)
        # Each map has a different primary mechanism and an optional weight reliquary.
        self.puzzle(['W','J','E','NW'][self.index], 'Mourner')
        self.puzzle(['U','M','UW','U'][self.index], 'Bell' if self.index in [1,2] else 'Porter')
        self.timed_travel()
        self.monumental()
        self.roofline()
        self.ceiling()
        return dict(map=MAPS[self.index],envelope=self.data['envelope'],theme=self.theme,
                    items=self.items,entities=self.entities,starts=self.starts,routes=self.routes)


def plan():
    global BOUNDS
    BOUNDS={v['path']:v for v in json.loads((DATA/'art_bounds.json').read_text())}
    concepts=json.loads((DATA/'layouts.json').read_text())
    built=[Layout(c,i).build() for i,c in enumerate(concepts)]
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'construction.json').write_text(json.dumps(built,separators=(',',':')))
    print([(v['map'],len(v['items']),len(v['entities'])) for v in built])
    return built


def make_surface(u,name,color_value,roughness,metallic):
    path='/Game/Mars/Environment/Materials/Expeditions/'+name
    m=u.load_asset(path)
    if m:
        if not m.get_editor_property('used_with_instanced_static_meshes'):
            m.set_editor_property('used_with_instanced_static_meshes',True)
            u.MaterialEditingLibrary.recompile_material(m)
            u.EditorAssetLibrary.save_loaded_asset(m)
        return m
    m=u.AssetToolsHelpers.get_asset_tools().create_asset(name,path.rsplit('/',1)[0],u.Material,u.MaterialFactoryNew())
    m.set_editor_property('used_with_instanced_static_meshes',True)
    lib=u.MaterialEditingLibrary
    color=lib.create_material_expression(m,u.MaterialExpressionConstant3Vector,-500,0)
    color.set_editor_property('constant',u.LinearColor(*color_value))
    lib.connect_material_property(color,'',u.MaterialProperty.MP_BASE_COLOR)
    for value,prop,y in [(roughness,u.MaterialProperty.MP_ROUGHNESS,120),(metallic,u.MaterialProperty.MP_METALLIC,240)]:
        e=lib.create_material_expression(m,u.MaterialExpressionConstant,-300,y)
        e.set_editor_property('r',value); lib.connect_material_property(e,'',prop)
    lib.recompile_material(m)
    u.EditorAssetLibrary.save_loaded_asset(m)
    return m


def apply_current(index):
    import unreal as u
    manifest=json.loads((OUT/'construction.json').read_text())[index]
    ea=u.get_editor_subsystem(u.EditorActorSubsystem)
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    expected='/Game/Mars/Maps/'+manifest['map']+'_Mars_MAP'
    assert world.get_path_name().split('.')[0]==expected, world.get_path_name()
    # Exact ownership fence; never delete user actors, including light rigs.
    for a in ea.get_all_level_actors():
        if OWN in [str(t) for t in a.tags] or a.get_actor_label()=='Expedition_InstanceSpike':
            ea.destroy_actor(a)
    ss=u.get_engine_subsystem(u.SubobjectDataSubsystem)
    def actor(cls,label,at=(0,0,0),yaw=0):
        a=ea.spawn_actor_from_class(cls,at if isinstance(at,u.Vector) else u.Vector(*at),u.Rotator(pitch=0,yaw=yaw,roll=0))
        a.set_actor_label('Expedition_'+label); a.tags=[u.Name(OWN)]
        a.set_folder_path('Expedition/'+label.split('_')[0]); return a
    def worldpos(at):
        return u.Vector((at[0]-manifest['envelope'][0]/2)*100,(at[1]-manifest['envelope'][1]/2)*100,at[2]*100)
    groups={}; lights=[]
    for v in manifest['items']:
        if v.get('light'): lights.append(v); continue
        key=(v['region'],v['mesh'],v['theme'],v['collision'])
        groups.setdefault(key,[]).append(v)
    total=0
    for (region,path,theme,collision),values in groups.items():
        a=actor(u.Actor,region+'_'+path.split('/')[-1])
        h=ss.k2_gather_subobject_data_for_instance(a)[0]
        ch,reason=ss.add_new_subobject(u.AddNewSubobjectParams(parent_handle=h,new_class=u.HierarchicalInstancedStaticMeshComponent))
        c=u.SubobjectDataBlueprintFunctionLibrary.get_associated_object(u.SubobjectDataBlueprintFunctionLibrary.get_data(ch))
        assert c, str(reason)
        c.set_mobility(u.ComponentMobility.STATIC)
        m=u.load_asset(path); assert m,path
        c.set_static_mesh(m)
        c.set_collision_profile_name('BlockAll' if collision else 'NoCollision')
        if region=='Flooded_Basin': c.set_material(0,make_surface(u,'Expedition_Water_Mars_M',(.013,.08,.075,1),.23,.15))
        elif region.startswith('Glyph_'): c.set_material(0,make_surface(u,'Expedition_Glyph_Mars_M',(.7,.35,.08,1),.55,.5))
        elif theme!='Original':
            for slot in range(m.get_num_sections(0)):
                old=m.get_material(slot)
                if not old: continue
                oldname=old.get_name()
                for category in ['MiseAtlas','StoneFloor','StoneWall','PlainStone']:
                    if oldname.startswith(category+'_'):
                        material=u.load_asset(MAT+category+'_'+theme+'_Mars_MI')
                        if material: c.set_material(slot,material)
                        break
        for v in values:
            c.add_instance(u.Transform(location=worldpos(v['at']),rotation=u.Rotator(pitch=v.get('pitch',0),yaw=v['yaw'],roll=v.get('roll',0)),scale=u.Vector(*v['scale'])),world_space=True)
        total+=len(values)
    for i,v in enumerate(lights):
        a=actor(u.PointLight,'Light_'+str(i),worldpos(v['at']))
        c=a.point_light_component; c.set_mobility(u.ComponentMobility.MOVABLE if v['region']=='Ceiling_Fixtures' else u.ComponentMobility.STATIONARY)
        c.set_intensity(v['intensity']*.15); c.set_attenuation_radius(v['radius']*100)
        c.set_light_color(u.LinearColor(*v.get('color',[1,.55,.24,1]))); c.set_editor_property('cast_shadows',False)
    for v in manifest['starts']:
        a=actor(u.PlayerStart,'Entrance_'+v['group']+'_'+str(v['slot']),worldpos(v['at']),v['yaw'])
        a.set_editor_property('player_start_tag',u.Name('Expedition.Entrance.'+v['group']))
    for i,v in enumerate(manifest['entities']):
        cls=u.load_class(None,'/Script/Angelscript.'+v['cls'])
        if not cls: raise RuntimeError('Missing gameplay class '+v['cls'])
        a=ea.spawn_actor_from_object(cls,worldpos(v['at']),u.Rotator(pitch=v.get('pitch',0),yaw=v['yaw'],roll=0))
        assert a,v['cls']
        a.tags=[u.Name(OWN)]; a.set_actor_label('Expedition_'+v['region']+'_'+v['cls']+'_'+str(i))
        a.set_folder_path('Expedition/Gameplay/'+v['region'])
        for key,value in v.get('props',{}).items(): a.get_editor_property('_EntityScript').set_editor_property(key,value)
    # Scoped mode: existing gameplay remains the parent. No project-wide settings edits.
    mode=u.load_class(None,'/Script/Angelscript.Mars_Expedition_GameMode')
    assert mode,'Expedition game mode has not compiled'
    world.get_world_settings().set_editor_property('default_game_mode',mode)
    existing=ea.get_all_level_actors()
    if not any(isinstance(a,u.SkyLight) for a in existing):
        a=actor(u.SkyLight,'Sky',(0,0,5000))
        a.light_component.set_mobility(u.ComponentMobility.MOVABLE)
        a.light_component.set_intensity(.8)
        a.light_component.set_editor_property('cast_shadows',False)
        a.light_component.set_editor_property('lower_hemisphere_color',u.LinearColor(.16,.20,.26,1))
        a.light_component.set_editor_property('source_type',u.SkyLightSourceType.SLS_SPECIFIED_CUBEMAP)
        a.light_component.set_editor_property('cubemap',u.load_asset('/Engine/EngineResources/GrayDarkTextureCube'))
        a.light_component.set_editor_property('real_time_capture',False)
    if not any(isinstance(a,u.ExponentialHeightFog) for a in existing):
        a=actor(u.ExponentialHeightFog,'Mist',(0,0,-400))
        a.component.set_editor_property('fog_density',.012)
        a.component.set_editor_property('fog_height_falloff',.18)
    # Art-directed indirect fill for enclosed, unbaked prototype geometry. This lights surfaces; it draws no sky.
    a=actor(u.PostProcessVolume,'InteriorAmbient')
    a.set_editor_property('unbound',True);a.set_editor_property('priority',10)
    settings=a.get_editor_property('settings')
    settings.set_editor_property('ambient_cubemap',u.load_asset('/Engine/EngineResources/GrayLightTextureCube'))
    settings.set_editor_property('ambient_cubemap_intensity',CEILING_AMBIENT)
    settings.set_editor_property('override_ambient_cubemap_intensity',True)
    settings.set_editor_property('ambient_cubemap_tint',u.LinearColor(.7,.8,1,1))
    settings.set_editor_property('override_ambient_cubemap_tint',True)
    settings.set_editor_property('auto_exposure_bias',CEILING_EXPOSURE)
    settings.set_editor_property('override_auto_exposure_bias',True)
    a.set_editor_property('settings',settings)
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    record=dict(map=expected,instances=total,batches=len(groups),entities=len(manifest['entities']),starts=len(manifest['starts']),lights=len(lights))
    (OUT/(manifest['map']+'-built.json')).write_text(json.dumps(record,indent=2))
    print(json.dumps(record))


def apply_exposure_current(index):
    """Lighting-only adjustment, preserving the saved native construction and bake."""
    import unreal as u
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    assert world.get_path_name().split('.')[0]=='/Game/Mars/Maps/'+MAPS[index]+'_Mars_MAP'
    actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
    volumes=[a for a in actors if isinstance(a,u.PostProcessVolume) and OWN in [str(t) for t in a.tags]]
    assert len(volumes)==1,'Expected exactly one owned interior volume'
    settings=volumes[0].get_editor_property('settings')
    settings.set_editor_property('auto_exposure_bias',CEILING_EXPOSURE)
    settings.set_editor_property('override_auto_exposure_bias',True)
    volumes[0].set_editor_property('settings',settings)
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    print(MAPS[index]+' saved exposure '+str(CEILING_EXPOSURE))


def capture(name, location=(0,-15000,12000), rotation=(-38,90,0), fov=65, lighting=True):
    import unreal as u
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    ea=u.get_editor_subsystem(u.EditorActorSubsystem)
    a=ea.spawn_actor_from_class(u.SceneCapture2D,u.Vector(*location),
        u.Rotator(pitch=rotation[0],yaw=rotation[1],roll=rotation[2]),transient=True)
    a.set_actor_label('Expedition_TransientReviewCamera')
    try:
        c=a.capture_component2d
        c.set_editor_property('capture_every_frame',False)
        c.set_editor_property('capture_on_movement',False)
        c.set_editor_property('capture_source',u.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
        c.set_editor_property('fov_angle',fov)
        if not lighting:
            c.set_editor_property('show_flag_settings',[u.EngineShowFlagsSetting(show_flag_name='Lighting',enabled=False)])
        rt=u.RenderingLibrary.create_render_target2d(w,1600,1000,u.TextureRenderTargetFormat.RTF_RGBA8)
        c.texture_target=rt
        c.capture_scene()
        u.RenderingLibrary.export_render_target(w,rt,str(OUT),name+'.png')
    finally: ea.destroy_actor(a)


def audit_current(index):
    """Trace the saved native collision, not just the abstract route graph."""
    import unreal as u
    data=json.loads((OUT/'construction.json').read_text())[index]
    w=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    def pos(x,y,z): return u.Vector((x-data['envelope'][0]/2)*100,(y-data['envelope'][1]/2)*100,z*100)
    bad=[]; count=0; entrance_results=[]
    for route in data['routes']:
        a,b=route['a'],route['b']; dx,dy=b[0]-a[0],b[1]-a[1]; dist=math.hypot(dx,dy); ux,uy=dx/dist,dy/dist
        for k in range(math.ceil(dist)+1):
            t=min(k,dist)
            if route['flights']:
                travel=max(0,min(t-route['start'],route['end']-route['start']))
                flight=min(route['flights']-1,int(travel/9.2))
                z=a[2]+flight*4+max(0,min(4,(travel-flight*9.2)/7.2*4))
            else: z=a[2]
            ok=False
            for lateral in [0,-min(2.4,route['width']/2-1),min(2.4,route['width']/2-1)]:
                x,y=a[0]+ux*t-uy*lateral,a[1]+uy*t+ux*lateral
                hit=u.SystemLibrary.line_trace_single(w,pos(x,y,z+.6),pos(x,y,z-.6),u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[],u.DrawDebugTrace.NONE)
                if hit: ok=True; break
            count+=1
            if not ok: bad.append(dict(a=a,b=b,t=t,expected_z=z))
    for start in data['starts']:
        x,y,z=start['at']
        h=u.SystemLibrary.line_trace_single(w,pos(x,y,z),pos(x,y,z-1.5),u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[],u.DrawDebugTrace.NONE)
        blocked=u.SystemLibrary.capsule_trace_single(w,pos(x,y,z),pos(x,y,z+.001),39,75,u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[],u.DrawDebugTrace.NONE)
        entrance_results.append(dict(group=start['group'],slot=start['slot'],floor=bool(h),capsule_clear=not bool(blocked)))
    jolt=u.get_editor_subsystem(u.Ck_JoltCook_EditorSubsystem_UE).validate_current_world()
    operating=[]
    for e in data['entities']:
        if not e['cls'].endswith('Station_EntityScript'): continue
        x,y,z=e['at']; ox,oy=rotate(-1.5,0,e['yaw'])
        blocked=u.SystemLibrary.capsule_trace_single(w,pos(x+ox,y+oy,z+.85),pos(x+ox,y+oy,z+.851),39,75,u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[],u.DrawDebugTrace.NONE)
        operating.append(dict(station=e['cls'],capsule_clear=not bool(blocked)))
    result=dict(map=data['map'],route_samples=count,missing_floor=bad,entrances=entrance_results,operating_positions=operating,jolt_current=jolt)
    (OUT/(data['map']+'-collision.json')).write_text(json.dumps(result,indent=2))
    print(json.dumps(dict(map=data['map'],route_samples=count,missing=len(bad),entrances_ok=sum(x['floor'] and x['capsule_clear'] for x in entrance_results),station_positions_ok=sum(x['capsule_clear'] for x in operating),jolt_current=jolt)))


def probe_walk(index,stair=False):
    import unreal as u
    w=u.EditorLevelLibrary.get_game_world()
    pc=u.GameplayStatics.get_player_controller(w,0); pawn=pc.get_controlled_pawn()
    initial=pawn.get_actor_location()
    starts=u.GameplayStatics.get_all_actors_of_class(w,u.PlayerStart)
    start=min(starts,key=lambda a:(a.get_actor_location()-initial).length_squared())
    group=str(start.player_start_tag).split('.')[-1]
    concepts=json.loads((DATA/'layouts.json').read_text())
    data=concepts[index]; nodes={n['id']:n for n in data['nodes']}; n=nodes[nodes[group]['note']]
    x,y,z=n['at']; target=u.Vector((x-data['envelope'][0]/2)*100,(y-data['envelope'][1]/2)*100,z*100+75)
    report={'map':MAPS[index],'entrance':group,'target':n['id'],'elapsed':0,'distance_m':0}
    if stair:
        low,high=[('W','F'),('M','H'),('W','R'),('H','N')][index]
        manifest=json.loads((OUT/'construction.json').read_text())[index]
        r=next(r for r in manifest['routes'] if r['a']==nodes[low]['at'] and r['b']==nodes[high]['at'])
        a,b=r['a'],r['b']; dx,dy=b[0]-a[0],b[1]-a[1]; distance=math.hypot(dx,dy)
        def along(t,height): return u.Vector((a[0]+dx/distance*t-data['envelope'][0]/2)*100,(a[1]+dy/distance*t-data['envelope'][1]/2)*100,height*100+85)
        initial=along(max(0,r['start']-2),a[2]); target=along(min(distance,r['end']+2),b[2]); z=b[2]
        pawn.set_actor_location(initial,False,True)
        report.update(target=high,route=low+' → '+high,rise_m=b[2]-a[2])
    state={'elapsed':0,'handle':None}
    def tick(dt):
        if not u.SystemLibrary.is_valid(pawn):
            u.unregister_slate_post_tick_callback(state['handle']); return
        state['elapsed']+=dt
        loc=pawn.get_actor_location(); dx,dy=target.x-loc.x,target.y-loc.y; distance=math.hypot(dx,dy)
        if distance>180 and state['elapsed']<18:
            pawn.add_movement_input(u.Vector(dx/distance,dy/distance,0),1,False)
        else:
            report.update(elapsed=state['elapsed'],distance_m=math.hypot(loc.x-initial.x,loc.y-initial.y)/100,
                          remaining_m=distance/100,reached=distance<=180,final_z=loc.z,expected_floor_z=z*100)
            (OUT/(MAPS[index]+('-stair.json' if stair else '-walk.json'))).write_text(json.dumps(report,indent=2))
            print(('EXPEDITION_STAIR ' if stair else 'EXPEDITION_WALK ')+json.dumps(report))
            u.unregister_slate_post_tick_callback(state['handle'])
    state['handle']=u.register_slate_post_tick_callback(tick)


def prepare_mourner(index):
    """Temporary test fixture: a real dropped pack on its plate. Restored after PIE, never saved as map stock."""
    import unreal as u
    global _MOURNER_FIXTURE
    ea=u.get_editor_subsystem(u.EditorActorSubsystem)
    pack=next(a for a in ea.get_all_level_actors() if 'Expedition_Puzzle_Mourner_Mars_WorldItem_Backpack_' in a.get_actor_label())
    data=json.loads((OUT/'construction.json').read_text())[index]
    plate=next(e for e in data['entities'] if 'Mourner_PackPlate' in e['cls'])
    x,y,z=plate['at']; destination=u.Vector((x-data['envelope'][0]/2)*100,(y-data['envelope'][1]/2)*100,z*100+35)
    _MOURNER_FIXTURE=(pack,pack.get_actor_transform())
    pack.set_actor_location(destination,False,True)
    print('Mourner fixture prepared; restore_mourner() required after PIE')


def probe_mourner(index,phase):
    import unreal as u
    data=json.loads((OUT/'construction.json').read_text())[index]
    w=u.EditorLevelLibrary.get_game_world()
    pawn=u.GameplayStatics.get_player_controller(w,0).get_controlled_pawn()
    def pos(at): return u.Vector((at[0]-data['envelope'][0]/2)*100,(at[1]-data['envelope'][1]/2)*100,at[2]*100)
    if phase in ('press','leave'):
        plate=next(e for e in data['entities'] if 'Mourner_ChefPlate' in e['cls'])
        at=pos(plate['at']); at.z+=85
        if phase=='leave': at.y-=300
        pawn.set_actor_location(at,False,True)
        return
    gate=next(e for e in data['entities'] if 'Mourner_AlcoveGate' in e['cls'])
    at=pos(gate['at']); at.z+=85
    ux,uy=rotate(1,0,gate['yaw']); delta=u.Vector(ux*150,uy*150,0)
    hit=u.SystemLibrary.capsule_trace_single(w,at-delta,at+delta,39,75,u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[pawn],u.DrawDebugTrace.NONE)
    blocked=bool(hit); expected=phase=='closed'
    path=OUT/(MAPS[index]+'-mourner.json')
    record=json.loads(path.read_text()) if phase!='closed' and path.exists() else {'map':MAPS[index],'observations':[]}
    record['observations'].append(dict(phase=phase,blocked=blocked,expected_blocked=expected,passed=blocked==expected))
    record['passed']=all(r['passed'] for r in record['observations']) and len(record['observations'])==3
    path.write_text(json.dumps(record,indent=2))
    print('EXPEDITION_MOURNER '+json.dumps(record['observations'][-1]))


def restore_mourner():
    import unreal as u
    global _MOURNER_FIXTURE
    pack,transform=_MOURNER_FIXTURE
    pack.set_actor_transform(transform,False,True)
    _MOURNER_FIXTURE=None
    assert u.get_editor_subsystem(u.LevelEditorSubsystem).save_current_level()
    print('Mourner fixture restored and original map stock saved')


def probe_bell(index,phase):
    """Exercise real interaction intents at both authored seal stances, then sweep the reward doorway."""
    import unreal as u
    data=json.loads((OUT/'construction.json').read_text())[index]
    w=u.EditorLevelLibrary.get_game_world(); pc=u.GameplayStatics.get_player_controller(w,0); pawn=pc.get_controlled_pawn()
    def pos(at): return u.Vector((at[0]-data['envelope'][0]/2)*100,(at[1]-data['envelope'][1]/2)*100,at[2]*100)
    if phase in ('circle','triangle'):
        token='CircleSeal' if phase=='circle' else 'TriangleSeal'
        seal=next(e for e in data['entities'] if 'Gauntlet_Bell_'+token in e['cls'])
        at=pos(seal['at']); ux,uy=rotate(1,0,seal['yaw']); at.x+=ux*90; at.y+=uy*90
        at.z-=(120 if phase=='circle' else 110)-85
        pawn.set_actor_location(at,False,True)
        # The camera director drives ControlRotation every tick; seed its public boom API, not the overwritten output.
        pitch=0 if phase=='circle' else -6
        helper=u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'),outer=pc)
        queued=helper.call_method('Aim',args=(pawn,u.Rotator(pitch=pitch,yaw=seal['yaw']+180,roll=0)))
        assert queued,'Camera request was not queued'
        print('EXPEDITION_BELL_AIM '+phase+' queued')
        return
    if phase in ('aim_circle','aim_triangle'):
        token='CircleSeal' if phase=='aim_circle' else 'TriangleSeal'
        seal=next(e for e in data['entities'] if 'Gauntlet_Bell_'+token in e['cls'])
        target=pos(seal['at']); ux,uy=rotate(1,0,seal['yaw']); target+=u.Vector(ux*10,uy*10,0)
        eye=u.GameplayStatics.get_player_camera_manager(w,0).get_camera_location()
        helper=u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'),outer=pc)
        assert helper.call_method('Aim',args=(pawn,u.MathLibrary.find_look_at_rotation(eye,target)))
        return
    if phase in ('press','release'):
        if phase=='press':
            view=u.GameplayStatics.get_player_camera_manager(w,0).get_camera_rotation()
            print('EXPEDITION_BELL_VIEW '+str(view))
        helper=u.new_object(u.load_class(None,'/Script/Angelscript.Mars_ExpeditionAcceptance'),outer=pc)
        assert helper.call_method('Use',args=(pawn,phase=='press')),'Use intent was not queued'
        return
    gate=next(e for e in data['entities'] if 'Bell_ReliquaryGate' in e['cls'])
    at=pos(gate['at']); at.z+=85; ux,uy=rotate(1,0,gate['yaw']); delta=u.Vector(ux*150,uy*150,0)
    hit=u.SystemLibrary.capsule_trace_single(w,at-delta,at+delta,39,75,u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[pawn],u.DrawDebugTrace.NONE)
    path=OUT/(MAPS[index]+'-bell.json')
    record=json.loads(path.read_text()) if phase!='closed' and path.exists() else {'map':MAPS[index],'observations':[]}
    record['observations'].append(dict(phase=phase,blocked=bool(hit),passed=bool(hit)==(phase=='closed')))
    record['passed']=len(record['observations'])==3 and all(r['passed'] for r in record['observations'])
    path.write_text(json.dumps(record,indent=2)); print('EXPEDITION_BELL '+json.dumps(record['observations'][-1]))


def audit_supports_current(index):
    """Check actual collision under dressing and both feet of major arches, ignoring the tested instance batch."""
    import unreal as u
    data=json.loads((OUT/'construction.json').read_text())[index]
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    assert world.get_path_name().split('.')[0]=='/Game/Mars/Maps/'+MAPS[index]+'_Mars_MAP'
    actors=u.get_editor_subsystem(u.EditorActorSubsystem).get_all_level_actors()
    bounds={v['path']:v for v in json.loads((DATA/'art_bounds.json').read_text())}
    reports=[]
    for v in data['items']:
        path=v.get('mesh',''); name=path.split('/')[-1]
        ceiling_pier=v['region'].startswith('Ceiling_Vault') and name.startswith('CryptPier')
        if not name.startswith(('Camp','BoxCrate','BoxPlinth','CryptPortal6m','CryptVaultRib','CryptPier','CryptSpoutLadle','CryptFinialPotlid')): continue
        if path not in bounds: continue
        b=bounds[path]
        ignored=[a for a in actors if a.get_actor_label()=='Expedition_'+v['region']+'_'+name]
        transform=u.Transform(location=u.Vector((v['at'][0]-data['envelope'][0]/2)*100,
                    (v['at'][1]-data['envelope'][1]/2)*100,v['at'][2]*100),
                    rotation=u.Rotator(pitch=v.get('pitch',0),yaw=v['yaw'],roll=v.get('roll',0)),scale=u.Vector(*v['scale']))
        xs=[(b['min'][0]+b['max'][0])/2]
        if name.startswith('CryptPortal6m'):
            xs=[b['min'][0]+50,b['max'][0]-50]
        elif name.startswith('CryptVaultRib'):
            xs=[b['min'][0]+5,b['max'][0]-5]
        for px in xs:
            point=transform.transform_location(u.Vector(px,(b['min'][1]+b['max'][1])/2,b['min'][2]))
            hit=u.SystemLibrary.line_trace_single(world,point+u.Vector(0,0,65 if ceiling_pier else 5),point-u.Vector(0,0,20),
                    u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,ignored,u.DrawDebugTrace.NONE)
            supported=bool(hit)
            if v.get('suspended'):
                supported=bool(u.SystemLibrary.line_trace_single(world,point+u.Vector(0,0,150),point+u.Vector(0,0,2500),
                    u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,ignored,u.DrawDebugTrace.NONE))
            if not supported and name.startswith('CampLantern'):
                for dx,dy in [(35,0),(-35,0),(0,35),(0,-35)]:
                    if u.SystemLibrary.line_trace_single(world,point,point+u.Vector(dx,dy,0),
                        u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,ignored,u.DrawDebugTrace.NONE):
                        supported=True; break
            reports.append(dict(mesh=name,region=v['region'],at=v['at'],point=[point.x,point.y,point.z],supported=supported))
    result=dict(map=MAPS[index],checks=len(reports),unsupported=[r for r in reports if not r['supported']])
    (OUT/'playtest-r02').mkdir(exist_ok=True)
    (OUT/'playtest-r02'/(MAPS[index]+'-supports.json')).write_text(json.dumps(result,indent=2))
    print(json.dumps(result))


def audit_ceiling_current(index):
    """Native upward and oblique visibility queries from playable districts, entrances and route segments."""
    import unreal as u
    data=json.loads((DATA/'layouts.json').read_text())[index]
    manifest=json.loads((OUT/'construction.json').read_text())[index]
    world=u.get_editor_subsystem(u.UnrealEditorSubsystem).get_editor_world()
    assert world.get_path_name().split('.')[0]=='/Game/Mars/Maps/'+MAPS[index]+'_Mars_MAP'
    nodes={n['id']:n for n in data['nodes']}
    points=[n['at'] for n in nodes.values()]+[s['at'] for s in manifest['starts']]
    for e in data['edges']:
        route=[nodes[e['a']]['at']]+e['via']+[nodes[e['b']]['at']]
        for a,b in zip(route,route[1:]):
            length=math.hypot(b[0]-a[0],b[1]-a[1]);steps=max(1,math.ceil(length/8))
            for i in range(steps+1):
                t=i/steps
                points.append([a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,max(a[2],b[2])])
    missed=[];checks=0;vertical=[]
    for p in points:
        start=u.Vector((p[0]-data['envelope'][0]/2)*100,(p[1]-data['envelope'][1]/2)*100,(p[2]+2)*100)
        for direction in [(0,0,1),(.6,0,.8),(-.6,0,.8),(0,.6,.8),(0,-.6,.8)]:
            end=start+u.Vector(*direction)*15000
            hit=u.SystemLibrary.line_trace_single(world,start,end,u.TraceTypeQuery.TRACE_TYPE_QUERY1,False,[],u.DrawDebugTrace.NONE)
            checks+=1
            if not hit: missed.append(dict(at=p,direction=direction))
            elif direction==(0,0,1):
                import re
                impact=re.search(r'ImpactPoint=\(X=[^,]+,Y=[^,]+,Z=([^\)]+)',hit.export_text())
                assert impact,hit.export_text()
                vertical.append(round(float(impact.group(1))/100-p[2],2))
    result=dict(map=MAPS[index],checks=checks,missed=missed,covered=not missed,
                min_observed_overhead_m=min(vertical),max_observed_overhead_m=max(vertical))
    (OUT/'playtest-r02'/(MAPS[index]+'-ceiling.json')).write_text(json.dumps(result,indent=2))
    print(json.dumps(result))


if __name__=='__main__': plan()
