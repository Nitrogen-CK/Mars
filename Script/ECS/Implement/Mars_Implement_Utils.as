namespace utils_implement
{
    // Composes the implement on InHandle (any entity; the feature does not need a station). The spec's Nodes are built by
    // the caller: the feature writes Nodes.Node's offset every frame relative to the offset it has now. It starts Idle.
    // A rejected spec or a missing node ensures and returns an invalid handle.
    FCk_Handle_Implement Add(FCk_Handle& InHandle, FMars_Implement_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Implement] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Implement(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.Node), f"[Implement] [{InHandle.ToString()}] needs a node"))
        { return FCk_Handle_Implement(); }

        auto Params = FMars_Fragment_Implement_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Implement();
        State.RestOffset = utils_scene_node::Get_Offset(InSpec.Nodes.Node);

        InHandle.Add_Fragment(FMars_Feature_Implement());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        return InHandle.As_Implement();
    }

    // ONE offset write: the tilt composed onto the rest rotation (rest x tilt, about the rest frame's axes), the orbit
    // offset in the rest frame's XY plane and the lift along the rest frame's up. An invalid node is an implement being
    // torn down.
    void Apply_Pose(FCk_Handle_SceneNode InNode, const FMars_Fragment_Implement& InState, FVector InOrbitOffset)
    {
        if (ck::Is_NOT_Valid(InNode))
        { return; }

        const auto& Rest = InState.RestOffset;
        const auto Rotation = FQuat(Rest.Rotator()) * FQuat(FRotator(InState.Pitch, 0.0f, InState.Roll));
        const auto Location = Rest.GetLocation() + InOrbitOffset + FVector(0.0, 0.0, InState.Lift);
        const auto Offset = FTransform(Rotation, Location, Rest.GetScale3D());
        utils_scene_node::Request_UpdateOffset(InNode, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }

    // The orbit's XY offset in the rest frame: (cos, sin, 0) of the phase times the radius the eased alpha shows.
    FVector Make_OrbitOffset(const FMars_Implement_OrbitSpec& InOrbit, const FMars_Fragment_Implement& InState)
    {
        const auto Radius = float64(InOrbit.Radius * InState.OrbitAlpha);
        return FVector(Math::Cos(InState.OrbitPhase) * Radius, Math::Sin(InState.OrbitPhase) * Radius, 0.0);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Implement_Spec Get_Spec(const FCk_Handle_Implement& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Implement_Params).Spec;
}

mixin EMars_Implement_Drive Get_Drive(const FCk_Handle_Implement& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Implement).Drive;
}

mixin bool Get_IsDriven(const FCk_Handle_Implement& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Implement).Drive == EMars_Implement_Drive::Driven;
}

// FRotator(Pitch, 0, Roll), degrees, on top of the rest rotation: what the node shows.
mixin FRotator Get_Tilt(const FCk_Handle_Implement& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Implement);
    return FRotator(State.Pitch, 0.0f, State.Roll);
}

// FRotator(TargetPitch, 0, TargetRoll): where the look is steering the tilt.
mixin FRotator Get_TargetTilt(const FCk_Handle_Implement& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Implement);
    return FRotator(State.TargetPitch, 0.0f, State.TargetRoll);
}

mixin float32 Get_Lift(const FCk_Handle_Implement& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Implement).Lift;
}

mixin float32 Get_LiftVelocity(const FCk_Handle_Implement& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Implement).LiftVelocity;
}

// The orbit's current XY offset from the rest location (zero without an orbit, or once it eased out).
mixin FVector Get_OrbitOffset(const FCk_Handle_Implement& Self)
{
    return utils_implement::Make_OrbitOffset(Self.Get_Spec().Orbit, Self.Get_Fragment(FMars_Fragment_Implement));
}

mixin FTransform Get_RestOffset(const FCk_Handle_Implement& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Implement).RestOffset;
}

mixin FCk_Handle_SceneNode Get_Node(const FCk_Handle_Implement& Self)
{
    return Self.Get_Spec().Nodes.Node;
}

// The node's world transform as of the last transform update.
mixin FTransform Get_NodeWorld(const FCk_Handle_Implement& Self)
{
    return utils_transform::Get_EntityCurrentTransform(Self.Get_Node().As_Transform());
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Look(FCk_Handle_Implement& Self, const FMars_Request_Implement_Look& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Implement_Requests);
    Requests.LookRequests.Add(InRequest);
}

mixin void Request_SetDrive(FCk_Handle_Implement& Self, const FMars_Request_Implement_SetDrive& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Implement_Requests);
    Requests.SetDriveRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Implement& Self, const FMars_Request_Implement_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Implement_Requests);
    Requests.ResetRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnDriveChanged(FCk_Handle_Implement& Self, FMars_Delegate_Implement_OnDriveChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Implement_Signals);
    Fragment.OnDriveChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnDriveChanged(FCk_Handle_Implement& Self, FMars_Delegate_Implement_OnDriveChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Implement_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Implement_Signals).OnDriveChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnLiftKicked(FCk_Handle_Implement& Self, FMars_Delegate_Implement_OnLiftKicked InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Implement_Signals);
    Fragment.OnLiftKicked.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnLiftKicked(FCk_Handle_Implement& Self, FMars_Delegate_Implement_OnLiftKicked InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Implement_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Implement_Signals).OnLiftKicked.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
