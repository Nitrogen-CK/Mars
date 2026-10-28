"""Find adjacent contact/profile rings through triangle edges and cyclic order."""
import math

def adjacent_contact_profile(points,triangles):
    levels=sorted({p[2] for p in points});low,high=levels[:2]
    rings=[{i for i,p in enumerate(points) if p[2]==z} for z in (low,high)]
    assert len(rings[0])==len(rings[1])==10
    band=[t for t in triangles if set(t)<=rings[0]|rings[1] and set(t)&rings[0] and set(t)&rings[1]]
    assert len(band)==20
    edges={tuple(sorted((t[i],t[(i+1)%3]))) for t in band for i in range(3)}
    def cycle(ids):
        neighbours={i:{b if a==i else a for a,b in edges if a in ids and b in ids and i in (a,b)} for i in ids}
        assert all(len(v)==2 for v in neighbours.values())
        order=[min(ids)];previous=None
        while len(order)<len(ids):
            options=neighbours[order[-1]]-{previous}
            nxt=min(options) if previous is None else next(iter(options))
            assert nxt not in order
            previous=order[-1];order.append(nxt)
        assert order[0] in neighbours[order[-1]]
        return order
    a,b=map(cycle,rings)
    centre=[[sum(points[i][k] for i in ids)/len(ids) for k in (0,1)] for ids in rings]
    candidates=[]
    for direction in (1,-1):
        for phase in range(len(b)):
            pairs=list(zip(a,[b[(phase+direction*i)%len(b)] for i in range(len(b))]))
            if not all(tuple(sorted(pair)) in edges for pair in pairs):continue
            x=[[points[i][k]-centre[0][k] for k in (0,1)] for i,j in pairs];y=[[points[j][k]-centre[1][k] for k in (0,1)] for i,j in pairs]
            # The authored next profile is elliptical (.46,.47) while the
            # bottom is circular (.31,.31), so one isotropic scale is false.
            scale=[sum(v[k]*w[k] for v,w in zip(x,y))/sum(v[k]*v[k] for v in x) for k in (0,1)]
            error=max(math.dist([scale[k]*v[k] for k in (0,1)],w) for v,w in zip(x,y))
            candidates.append((error,scale,pairs))
    candidates.sort();assert candidates and candidates[0][0]<.001 and min(candidates[0][1])>1, candidates
    if len(candidates)>1:assert candidates[1][0]>candidates[0][0]+.001
    error,scale,pairs=candidates[0]
    return dict(low_z_cm=low,adjacent_z_cm=high,lower_cycle=a,upper_cycle=b,pairs=pairs,axis_scales=scale,maximum_axis_scale_fit_error_cm=error,other_candidate_errors_cm=[v[0] for v in candidates[1:]],method='Ring edges from actual side-band triangles; cyclic one-to-one edge-connected correspondences, unique positive per-axis scale fit for the authored circular-to-elliptical profiles. No nearest-point/radius guess.')
