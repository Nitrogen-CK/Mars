"""Fit review cameras to saved source floors, including stacked gallery decks."""
import importlib.util,json,math
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def main():
    data=json.loads((ROOT/'Tools/LevelDesign/anchor_plans/data/warrens_v8c.json').read_text());base=json.loads((HERE/'Output/Reports/full_source_baseline.json').read_text())
    s=importlib.util.spec_from_file_location('camera_surface',HERE.parent/'PumpCisternKit/surface_fitting.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
    boxes=[b for bs in m.load_boxes({k:dict(baseline_path=HERE/'Output/Reports/full_source_baseline.json',pivot=v['pivot']) for k,v in base.items()}).values() for b in bs]
    fs=[b for b in boxes if b['label']=='Warrens_Greybox_floor' or b['label']=='Warrens_Greybox_gallery' and min(b['size'][:2])>.11 and b['size'][2]<=.5]
    solids=[b for b in boxes if b['label'] in ['Warrens_Greybox_wall','Warrens_Greybox_roof','Warrens_Greybox_floor','Warrens_Greybox_prop'] and all(abs(v)<.001 for v in b['rotation'])]
    ramps=[b for b in boxes if b['label']=='Warrens_Greybox_ramp']
    # Camera checks use the retained solid shapes, including rotated ramp boxes.
    geometry=[b for b in boxes if b['label'] in ['Warrens_Greybox_wall','Warrens_Greybox_roof','Warrens_Greybox_floor','Warrens_Greybox_ramp']]
    axes={id(b):[m.rotate(e,b['rotation']) for e in [[1,0,0],[0,1,0],[0,0,1]]] for b in geometry}
    xy_extent={id(b):[sum(abs(axes[id(b)][j][k])*b['size'][j]/2 for j in range(3)) for k in range(2)] for b in geometry}
    def local(b,p):return [sum((p[k]-b['at'][k])*v[k] for k in range(3)) for v in axes[id(b)]]
    def point_inside(b,p):return all(abs(v)<b['size'][k]/2-1e-5 for k,v in enumerate(local(b,p)))
    def segment_hits(a,c):
        hits=[]
        for b in geometry:
            aa,cc=local(b,a),local(b,c);enter,leave=0.,1.
            for k in range(3):
                d=cc[k]-aa[k];low=-b['size'][k]/2;high=-low
                if abs(d)<1e-9:
                    if not low+1e-6<aa[k]<high-1e-6:break
                else:
                    u,v=(low-aa[k])/d,(high-aa[k])/d
                    enter=max(enter,min(u,v));leave=min(leave,max(u,v))
                    if leave<=enter+1e-7:break
            else:
                # Merely touching the endpoint/target roof is not an obstruction.
                if leave>1e-5 and enter<1-1e-5:hits.append(dict(source=b['key'],fraction=enter))
        return sorted(hits,key=lambda q:q['fraction'])
    def body_clear(x,y,z,height):
        probes=[(x+dx,y+dy,z+dz) for dx,dy in [(0,0),(.35,0),(-.35,0),(0,.35),(0,-.35)] for dz in [.2,height*.55,height+.1]]
        near=[b for b in geometry if all(abs(p-b['at'][k])<=xy_extent[id(b)][k]+.35 for k,p in enumerate([x,y]))]
        return not any(point_inside(b,p) for b in near for p in probes)
    def ramp_floor(b,x,y):
        n=m.rotate([0,0,1],b['rotation']);p=[b['at'][k]+n[k]*b['size'][2]/2 for k in range(3)]
        if abs(n[2])<.01:return None
        z=p[2]-(n[0]*(x-p[0])+n[1]*(y-p[1]))/n[2];delta=[x-b['at'][0],y-b['at'][1],z-b['at'][2]]
        local=[sum(a*c for a,c in zip(delta,m.rotate(axis,b['rotation']))) for axis in [[1,0,0],[0,1,0]]]
        return dict(b,hi=[x,y,z]) if all(abs(local[k])<=b['size'][k]/2 for k in range(2)) else None
    def fit(at,eye_height=1.4,strict=False):
        choices=[]
        for radius in [0,.4,.8,1.2,2,3,4]:
            for i in range(1 if radius==0 else 16):
                x=at[0]+radius*math.cos(i*math.tau/16);y=at[1]+radius*math.sin(i*math.tau/16)
                floors=[f for f in fs if m.contains(f,x,y) and abs(f['hi'][2]-at[2])<1.3]
                floors.extend(f for b in ramps if (f:=ramp_floor(b,x,y)) and abs(f['hi'][2]-at[2])<1.3)
                for f in floors:
                    z=f['hi'][2];eye=z+eye_height
                    if any(m.contains(w,x+dx,y+dy,eye+dz) for w in solids for dx,dy,dz in [(0,0,0),(.35,0,0),(-.35,0,0),(0,.35,0),(0,-.35,0),(0,0,.1)]):continue
                    if strict and not body_clear(x,y,z,eye_height):continue
                    choices.append((radius+abs(z-at[2]),[x,y,eye],f['key']))
            if choices:break
        if not choices and eye_height==1.4:return fit(at,.9,strict)
        assert choices,at
        _,point,key=min(choices,key=lambda x:x[0]);return point,key,eye_height
    anchors={'hall':([13,49,0],[40,55.5,5]),'closet':([20.5,40,0],[18,40,1]),'court':([14,69,-1.5],[15,88,2]),'court-pit':([9,77,-1.5],[21,81,-.4]),'rimW':([31,50,0],[40,55.5,4]),'rimE':([48,50,0],[102,50,3]),'rimN':([43,55,0],[48.5,57,1.4]),'rimS':([40,44.5,0],[40,55.5,4]),'ossuary':([44,65,2.5],[52,76,3.7]),'bridgehead':([58,73,2.5],[74,74,3]),'ford-w':([54,48,-2.5],[74,49,-1]),'ford-e':([83,49,0],[91,50,1.2]),'reliquary':([94,77,2.5],[88,84,3.4]),'mill':([86,99,5],[95,104,6]),'catacomb':([-22,74,0],[-18,80,1]),'belfry':([94,57,0],[104,50,15]),'bell-loft':([103,61,2.5],[104,50,16]),'cellar':([103,23,-2.5],[100,16,-1.5]),'sluice':([122,11,-2.5],[122,20,-1.5]),'larder':([116,35,-2.5],[126,43,-1]),'pump':([61,29,-2.5],[54,22,1]),'cistern':([8.3,37,-2.5],[16,35,-1.5]),'lair':([40,50,-5],[48,54,-3.8]),'vault':([59.5,57.5,-5],[64,62,-3.8])}
    views=[]
    def add(name,at,target,kind,label,strict=False,route=None):
        eye,floor,eye_height=fit(at,strict=strict)
        row=dict(id=name,kind=kind,label=label,plan_eye=eye,target=target,source_floor=floor,requested_base=at,eye_height_m=eye_height)
        if strict:
            hits=segment_hits(eye,target)
            assert not hits,(name,hits[:1])
            row['source_camera_proof']=dict(authored_route=route,body_probes=15,body_radius_m=.35,body_clear=True,target_segment_clear=True,target_only_contact_excluded=True)
        views.append(row)
    for room in data['rooms']:
        at,target=anchors[room['id']];add('ROOM_'+room['id'],at,target,'room',room.get('label') or room['id'])
    for v in data['views']:add('VIEW_'+v['id'],v['from'],v['to'],'sightline',v['label'])
    # These targets follow actual link vertices/extra-ramp endpoints. Directly
    # aiming between district ports cuts doglegs or points vertically at a stair.
    seam_routes={
        'Court__Ossuary__ossuary':([30,86,0],[32,86,1],'c2 -> via(32,86) -> o1'),
        'Hub__Waterworks-W__pump':([50,40,-1.2],[52,38,-1.2],'wSE -> via(52,38) -> p1'),
        'Court__Waterworks-W__cistern':([5,56,-1.2],[4.5,55,-2.5],'c1 -> cw'),
        'Waterworks-W__Canal__chain':([81,25,-2.5],[66,26,-2.5],'extraRamps.chain-crossing west endpoint'),
        'Reliquary__Mill__mill':([104,101,3.8],[104,104,4.2],'extraRamps.mill-stair-b endpoint'),
        'Brineworks__Pit__undercroft':([80,25.0667,-5],[66,26,-5],'ut1 -> via(80,25.0667) -> via(66,26) -> ut2'),
        'Hub__Ossuary__ossuary':([42,60,1.2],[44,64,2.5],'wN -> o0'),
        'Catacomb__Pit__pit':([-8,50,-3],[-4,46,-5],'extraRamps.catacomb-dive-b endpoint'),
        'Belfry__Brineworks__larder':([112,52,-1.2],[112,46,-2.5],'be -> bl0'),
    }
    for v in json.loads((HERE/'zone_plan.json').read_text())['continuity_checkpoints']:
        transition=v.get('transition')
        a=v['source_port_a']['at'] if v.get('source_port_a') else transition['at']
        b=v['source_port_b']['at'] if v.get('source_port_b') else transition['at']
        at=transition['at'] if transition else a
        # Face along the actual connected endpoints; equal points get a modest
        # roomward target, without inventing a connector or moving any source.
        target=[b[0],b[1],b[2]+1.1]
        if math.dist(a[:2],b[:2])<.2:target[1]+=3
        if v['id'] in seam_routes:
            at,end,route=seam_routes[v['id']]
            target,_,_=fit(end,strict=True)
            add('SEAM_'+v['id'],at,target,'boundary',' / '.join(v['zones']),strict=True,route=route)
        else:add('SEAM_'+v['id'],at,target,'boundary',' / '.join(v['zones']))
    assert len(views)==55 and len({v['id'] for v in views})==55
    glyph=next(v for v in views if v['id']=='VIEW_rim-glyphs')
    assert glyph['plan_eye']==[48.,50.,1.4] and glyph['target']==[102,50,2]
    (HERE/'Output/review_views.json').write_text(json.dumps(views,indent=2));print('SOURCE_FITTED_REVIEW_CAMERAS',len(views))
if __name__=='__main__':main()
