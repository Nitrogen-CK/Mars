"""Exact edge-connected horizontal sections of a triangulated manifold mesh.

Choose a plane away from vertices. Shared vertex-edge IDs provide adjacency;
no coordinate welding or radius guess is used to recover aperture loops.
"""
import math

def area(poly):return .5*sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))
def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])

def section_loops(points,triangles,z):
    assert all(abs(p[2]-z)>1e-6 for p in points),'Choose a section plane away from source vertices'
    nodes={};adj={}
    for tri in triangles:
        cut=[]
        for i,j in zip(tri,tri[1:]+tri[:1]):
            a,b=points[i],points[j]
            if (a[2]<z)==(b[2]<z):continue
            key=tuple(sorted((i,j)));a,b=points[key[0]],points[key[1]];t=(z-a[2])/(b[2]-a[2]);p=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t)
            if key in nodes:assert nodes[key]==p
            else:nodes[key]=p;adj[key]=set()
            cut.append(key)
        if cut:
            assert len(cut)==2;adj[cut[0]].add(cut[1]);adj[cut[1]].add(cut[0])
    assert adj and all(len(v)==2 for v in adj.values()),'Section must form closed manifold loops'
    remaining=set(adj);loops=[]
    while remaining:
        start=min(remaining);previous=None;current=start;keys=[]
        while True:
            assert current not in keys;keys.append(current);remaining.remove(current)
            options=sorted(adj[current]-({previous} if previous is not None else set()));nxt=options[0]
            if nxt==start:break
            previous,current=current,nxt
        loop=[nodes[k] for k in keys]
        if area(loop)<0:loop.reverse()
        assert area(loop)>0;loops.append(loop)
    return sorted(loops,key=area)

def convex_hull(points):
    points=sorted(set(map(tuple,points)));assert len(points)>=3
    def half(seq):
        out=[]
        for p in seq:
            while len(out)>1 and cross(out[-2],out[-1],p)<=1e-8:out.pop()
            out.append(p)
        return out
    result=half(points)[:-1]+half(list(reversed(points)))[:-1];assert area(result)>0;return result

def minimum_inside_margin(points,convex_poly):
    return min(cross(a,b,p)/math.dist(a,b) for p in points for a,b in zip(convex_poly,convex_poly[1:]+convex_poly[:1]))

def fitted_plug(points,triangles,bottom,top,scale=1.04):
    sections={}
    for z in (bottom,top):
        loops=section_loops(points,triangles,z);assert len(loops)==2;sections[z]=dict(inner=loops[0],outer=loops[1])
    assert not [p[2] for p in points if bottom<p[2]<top],'Audit intermediate profile breaks separately'
    inner=convex_hull(sections[bottom]['inner']);outline=[(x*scale,y*scale) for x,y in inner]
    proof=[]
    for z,s in sections.items():
        inner_margin=minimum_inside_margin(s['inner'],outline);outer_margin=minimum_inside_margin(outline,convex_hull(s['outer']))
        assert inner_margin>.2 and outer_margin>.2,(z,inner_margin,outer_margin)
        proof.append(dict(z_cm=z,inner=s['inner'],outer=s['outer'],minimum_inner_coverage_margin_cm=inner_margin,minimum_outer_wall_clearance_cm=outer_margin))
    return outline,proof
