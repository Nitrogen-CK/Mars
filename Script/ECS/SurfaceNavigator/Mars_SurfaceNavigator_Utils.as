namespace utils_surface_navigator
{
    // Composes the navigator on the motion's own entity (State.Motion = InMotion). A rejected spec or an invalid motion
    // ensures and returns an invalid handle with nothing composed.
    FCk_Handle_SurfaceNavigator Add(FCk_Handle_SurfaceMotion& InMotion, FMars_SurfaceNavigator_Spec InSpec)
    {
        FCk_Handle Entity = InMotion;

        if (ck::EnsureIfNot(ck::IsValid(InMotion), f"[SurfaceNavigator] [{Entity.ToString()}] needs a valid surface motion"))
        { return FCk_Handle_SurfaceNavigator(); }

        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[SurfaceNavigator] [{Entity.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_SurfaceNavigator(); }

        auto Params = FMars_Fragment_SurfaceNavigator_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_SurfaceNavigator();
        State.Motion = InMotion;

        Entity.Add_Fragment(FMars_Feature_SurfaceNavigator());
        Entity.Add_Fragment(Params);
        Entity.Add_Fragment(State);
        return Entity.As_SurfaceNavigator();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_SurfaceNavigator_Spec Get_Spec(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator_Params).Spec;
}

mixin FCk_Handle_SurfaceMotion Get_Motion(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).Motion;
}

mixin EMars_SurfaceNavigator_Status Get_Status(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).Status;
}

// None unless Status is Failed.
mixin EMars_SurfaceNavigator_FailReason Get_FailReason(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).FailReason;
}

// How the last accepted move's waypoints were made.
mixin EMars_SurfaceNavigator_PathMode Get_PathMode(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).Route.PathMode;
}

// The last requested goal (kept after Arrived and Failed).
mixin FVector Get_Goal(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).Route.Goal;
}

// The current move's waypoints; empty after a Stop or a NoPath failure.
mixin TArray<FVector> Get_Waypoints(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).Route.Waypoints;
}

mixin int32 Get_WaypointIndex(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Get_Fragment(FMars_Fragment_SurfaceNavigator).Route.WaypointIndex;
}

// True until the request drain has run: the status and the goal still describe the move before the queued requests.
mixin bool Get_HasPendingRequests(const FCk_Handle_SurfaceNavigator& Self)
{
    return Self.Has_Fragment(FMars_Fragment_SurfaceNavigator_Requests);
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Cancels every MoveTo queued before it: the Stop wins over a move requested earlier in the same frame.
mixin void Request_Stop(FCk_Handle_SurfaceNavigator& Self, const FMars_Request_SurfaceNavigator_Stop& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_SurfaceNavigator_Requests);
    Requests.MoveToRequests.Empty();
    Requests.StopRequests.Add(InRequest);
}

mixin void Request_MoveTo(FCk_Handle_SurfaceNavigator& Self, const FMars_Request_SurfaceNavigator_MoveTo& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_SurfaceNavigator_Requests);
    Requests.MoveToRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnArrived(FCk_Handle_SurfaceNavigator& Self, FMars_Delegate_SurfaceNavigator_OnArrived InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_SurfaceNavigator_Signals);
    Fragment.OnArrived.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnArrived(FCk_Handle_SurfaceNavigator& Self, FMars_Delegate_SurfaceNavigator_OnArrived InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_SurfaceNavigator_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_SurfaceNavigator_Signals).OnArrived.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnFailed(FCk_Handle_SurfaceNavigator& Self, FMars_Delegate_SurfaceNavigator_OnFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_SurfaceNavigator_Signals);
    Fragment.OnFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnFailed(FCk_Handle_SurfaceNavigator& Self, FMars_Delegate_SurfaceNavigator_OnFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_SurfaceNavigator_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_SurfaceNavigator_Signals).OnFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
