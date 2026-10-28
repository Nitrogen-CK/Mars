"""Attribute exact zero normal samples without treating them as usable normals."""
import json
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
DOC=ROOT/'docs/art/warrens-c-gameplay-review-20261024/lookdev/remaining-room-rollout-r01'
rooms=json.loads((DOC/'four_room_exports_r01.json').read_text())['rooms']
reports=[]
for room in rooms:
    for family in ('walls','floor','ceiling'):
        e=json.loads((DOC/room['folder']/('actual_fbx_'+family+'_corner_attributes_r01.json')).read_text())['triangles']
        n=json.loads((DOC/('native_corner_attributes_'+room['room']+'_'+family+'_r01.json')).read_text())['triangles']
        p=json.loads((DOC/('native_correspondence_'+room['room']+'_'+family+'_r02.json')).read_text())
        geometry=json.loads((DOC/room['folder']/('actual_fbx_'+family+'_geometry_r01.json')).read_text())['triangles']
        zeros=[]
        for row in p['matches']:
            for corner,index in enumerate(row['cyclic_corner_order']):
                a=n[row['native_triangle']]['normals'][corner];b=e[row['fbx_triangle']]['normals'][index]
                if sum(v*v for v in a)==0 or sum(v*v for v in b)==0:
                    points=geometry[row['fbx_triangle']]['positions'];x=[points[1][i]-points[0][i] for i in range(3)];y=[points[2][i]-points[0][i] for i in range(3)]
                    cross=[x[1]*y[2]-x[2]*y[1],x[2]*y[0]-x[0]*y[2],x[0]*y[1]-x[1]*y[0]]
                    zeros.append(dict(native_triangle=row['native_triangle'],fbx_triangle=row['fbx_triangle'],material=row['material'],corner=corner,native_normal=a,fbx_normal=b,area_square_cm=math.sqrt(sum(v*v for v in cross))/2,maximum_edge_cm=max(math.dist(points[i],points[(i+1)%3]) for i in range(3))))
        reports.append(dict(room=room['room'],family=family,zero_samples=zeros))
        print('ZERO_NORMAL_SAMPLES',room['room'],family,len(zeros),'MAX_AREA_CM2',max((v['area_square_cm'] for v in zeros),default=0),'MAX_EDGE_CM',max((v['maximum_edge_cm'] for v in zeros),default=0),zeros[:1])
(DOC/'zero_corner_normal_diagnostic_r01.json').write_text(json.dumps(reports,indent=2)+'\n')
