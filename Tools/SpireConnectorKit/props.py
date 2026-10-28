"""Dimension-driven shared pantry, lighting and ironwork mesh recipes."""
import math
from geometry import Mesh

def prop(row):
    m=Mesh();key=row['id'];w,d,h=row['size_trh_cm'];box=m.box
    if key=='P01':
        box((0,0,10+(h-10)/2),(d-5,w,h-10));box((0,0,h-3),(d,w,6))
        for y in [-w/2+5,w/2-5]:
            for x in [-d/2+7,d/2-7]:box((x,y,5),(9,9,10))
        for y in [-w/4,w/4]:
            box((-d/2+2,y,(h+10)/2),(4,w/2-8,h-24),'M04')
            box((-d/2+1,y+(8 if y<0 else -8),h*.53),(2,5,12),'M05')
    elif key=='P02':
        for z in [5,50,100,150]:box((0,0,z-2.5),(d,w,5))
        for y in [-w/2+4,w/2-4]:box((0,y,h/2),(d,8,h))
        box((d/2-2,0,h/2),(4,w,h))
    elif key=='P03':
        m.lathe([(0,24),(5,27),(22,29),(42.5,30),(63,29),(80,27),(85,24)],'M04')
        for z,r in [(12,28),(73,28)]:m.torus((0,0,z),r,1.8,'M05',segments=12,tube_segments=4)
        box((0,0,83),(40,4,2),'M05')
    elif key=='P04':
        box((0,0,h-3.5),(d,w,7))
        for x in [-d/2+7,d/2-7]:
            for y in [-w/2+10,w/2-10]:box((x,y,20.5),(9,10,41))
        box((0,0,13),(7,w-15,8))
    elif key=='P05':
        m.lathe([(0,8),(3,10),(9,11),(23,11),(28,7),(32,7)],'M09',12)
        m.tube((0,0,32),(0,0,35),8,'M06',12)
    elif key=='P06':
        m.lathe([(0,12),(4,20),(18,22.5),(35,22),(50,15),(54,5),(60,7)],'M07',10);m.torus((0,0,54),5,.8,'M04')
    elif key=='P07':
        box((0,0,25),(d-4,w-4,48),'M00')
        for z in [5,17,29,41,48]:
            for x in [-d/2+2,d/2-2]:box((x,0,z),(4,w,5))
            for y in [-w/2+2,w/2-2]:box((0,y,z),(d,4,5))
        for y in [-w/2+3,w/2-3]:
            for x in [-d/2+3,d/2-3]:box((x,y,25),(6,6,50))
    elif key=='P08':
        box((0,0,4),(20,22,6),'M05');box((0,0,19),(14,16,24),'M09_Emissive')
        for x in [-9,9]:
            for y in [-10,10]:box((x,y,20),(2,2,30),'M05')
        m.tube((0,0,34),(0,0,40),12,'M05',8,r2=3)
        box((12,0,22),(4,8,36),'M05');m.torus((0,0,39),2.2,.8,'M05','Y',8,4)
    elif key=='P09':
        box((0,0,15),(8,w,h),'M06')
        box((-3.5,0,15),(1,w-6,h-6),'M05')
        box((-4,0,13),(.4,4,13),'M06')
        # Embossed up-arrow is wholly inside the size envelope.
        m.part([(-4,-10,19),(-4,10,19),(-4,0,27)],[(0,1,2)],'M06')
    elif key=='P10':
        box((d/2-3,0,34),(6,w,62),'M05')
        for y in [-45,0,45]:m.rod_curve([(10,y,58),(-10,y,58),(-12,y,47),(-8,y,43)],2,'M05')
    elif key=='P11':
        # Pan is vertical, face toward the aisle (-X).
        m.tube((-4,0,14),(4,0,14),14,'M05',12)
        box((0,0,34),(5,5,20),'M05');m.torus((0,0,41),2.2,.8,'M05','X',8,4)
    elif key=='P12':
        box((2,0,45),(6,50,90),'M03');box((-3,0,45),(2,40,80),'M09_Emissive')
        for z in [13,29,45,61,77]:box((-4,0,z),(2,40,8),'M05')
    elif key=='P13':
        m.torus((0,0,22.5),20.5,2,'M06','X',16,6)
        m.tube((-7.5,0,22.5),(7.5,0,22.5),6,'M05',8)
        for a in [0,90,180,270]:
            y,z=19*math.cos(math.radians(a)),22.5+19*math.sin(math.radians(a));m.tube((0,0,22.5),(0,y,z),1.6,'M06')
    elif key=='P14':
        for x,y,z,r in [(-4,-20,18,12),(5,3,24,11),(-3,24,14,8)]:
            m.tube((x,y,0),(x,y,z),r*.18,'M08',7)
            m.tube((x,y,z-3),(x,y,z+6),r,'M08',8,r2=r*.18)
    elif key=='P15':
        m.tube((0,0,5),(0,0,70),1.5,'M04',6)
        for z,y in [(12,-5),(32,5),(51,-4)]:
            m.tube((0,y,z-8),(0,y,z+8),7,'M07',8,r2=2)
    elif key=='P16':
        # Closed cloth slab, lower notch. T/R/H =55/5/85.
        yz=[(-27.5,85),(27.5,85),(27.5,0),(0,16),(-27.5,0)];vs=[(x,y,z) for x in [-2.5,2.5] for y,z in yz]
        m.part(vs,[(0,4,3,2,1),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)],'M07')
    elif key=='P17':
        box((0,0,5),(120,120,10))
        for q in [-54,54]:
            for t in [-54,54]:box((q,t,70),(12,12,140))
        for z in [25,65,105,134]:
            for q in [-57,57]:box((q,0,z),(6,120,6));box((0,q,z),(120,6,6))
        for q in [-48,-36,-24,-12,0,12,24,36,48]:
            for side in [-57,57]:box((side,q,70),(6,6,120));box((q,side,70),(6,6,120))
    elif key=='P18':
        box((0,0,22),(25,22,6),'M05');m.torus((0,0,9),7,2,'M05','Y',10,4)
    elif key=='P19':
        box((0,0,12),(15,35,24),'M05')
        for y in [-12,12]:m.tube((-7.5,y,12),(-4,y,12),3,'M06',6)
    elif key=='P20':
        box((4,0,h/2),(4,w,h),'M03')
        for y in [-36,36]:box((0,y,h/2),(12,8,h),'M05')
        for z in [4,91]:box((0,0,z),(12,w,8),'M05')
        for y in [-24,-12,0,12,24]:box((0,y,h/2),(6,3,h-8),'M05')
    else:raise ValueError(key)
    return m
