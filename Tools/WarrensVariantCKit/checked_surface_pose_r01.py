"""Accept only exact requested or reproduced binary64 movement translations."""


def set_pose(actor,requested,core):
    import unreal as u
    component=actor.static_mesh_component
    assert component==actor.root_component and component.get_attach_parent() is None
    assert component.mobility==u.ComponentMobility.MOVABLE and component.get_collision_enabled()==u.CollisionEnabled.NO_COLLISION
    assert not component.is_simulating_physics()
    before=core._pose(actor.get_actor_transform());wanted=core._pose(requested)
    computed=[start+(end-start) for start,end in zip(before['at'],wanted['at'])]
    actor.set_actor_transform(requested,False,True)
    actual=core._pose(actor.get_actor_transform())
    assert actual['q']==wanted['q'] and actual['scale']==wanted['scale']
    assert actual['at']==wanted['at'] or actual['at']==computed
    return dict(before=before,requested=wanted,computed_delta_translation=computed,actual=actual,boundary='No tolerance. Only exact requested coordinates or exact observed binary64 old+(target-old) movement result for an unattached Movable nonphysical root. Rotation and scale remain bit-exact. Actual pose is subsequently frozen and checked; source geometry and authored placement do not change.')
