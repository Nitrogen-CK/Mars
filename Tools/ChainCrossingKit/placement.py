"""Pure-data local diorama recipe, separate from source-fitted Unreal placements."""
import math

def build_diorama():
    p=[]
    def add(n,at,scale=(1,1,1),yaw=0,rotation=None):
        item=dict(id=f'CCS{n:02}',at=list(at),scale=list(scale),yaw=yaw)
        if rotation:item['rotation']=rotation
        p.append(item)
    # Continuous fixed deck: local X longitudinal; asset width X needs quarter-turn.
    for i in range(15):
        x=-14+i*2;add(1,(x,0,0),yaw=90)
        for y in [-1.55,1.55]:add(3,(x,y,-.6))
    for x in range(-15,16,3):
        for y in [-1.55,1.55]:add(9,(x,y,0));add(10,(x,y,1))
    for x in range(-15,15,3):
        for y in [-1.55,1.55]:add(11,(x+1.5,y,.15),(1.5,1,1))
    for x in [-15,15]:
        add(5,(x,0,-1.9));add(48,(x,0,-.65),(1,1,1),90)
    for x in [-17,17]:
        for y in [-2.5,2.5]:add(43,(x,y,-.45))
    add(33,(-12,0,0),yaw=90)
    for y in [-1.1,1.1]:add(34,(-12,y,0));add(36,(-12,y,0))
    add(35,(-12,0,2.2),yaw=90);add(37,(-12,0,4.4),yaw=90)
    # Sluice-side maintenance bay, linked instance construction.
    for x in [16,18,20]:
        for y in [0,2,4]:add(13,(x,y,0))
    for x in [16,18,20]:add(15,(x,5,0))
    add(17,(14.8,2,0),yaw=90)
    add(23,(18,3,0));add(21,(18,2.4,1.1));add(22,(18,2.65,1.1));add(24,(18,3.65,1.1))
    for x in [12,14,16,18]:
        add(29,(x,1.8,0))
        for i in range(8):add(27,(x-.85+i*.24,1.8,.13),(.65,.65,.65),rotation=[90 if i%2 else 0,0,0])
    for x in [16,20]:add(86,(x,4.75,1.2),(1.2,1,1),rotation=[0,90,0]);add(87,(x,4.7,1.4))
    add(86,(18,4.75,2.4),(2.3,1,1))
    add(60,(16,4.5,2.1));add(61,(16,4.48,2.15));add(64,(16,4.45,2.2))
    add(69,(20,4.4,0));add(66,(20,2.5,0));add(67,(16,3.5,0));add(71,(16,2.3,0));add(75,(19,3.5,0));add(78,(18,4.75,1.7));add(79,(20,4.72,1.5));add(88,(18,1.8,0))
    for x in range(-20,25,4):
        for y in [-7,-3,1,5,9]:add(51,(x,y,-.30))
    for x in [-16,16]:
        for y in [-3,0,3]:add(52,(x,y,-.29),yaw=90)
    return p
