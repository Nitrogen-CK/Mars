namespace utils_mover
{
    FCk_Handle_Mover Add(FCk_Handle_SceneNode& InNode, FMars_Mover_Spec InParams)
    {
        auto Params = FMars_Fragment_Mover_Params();
        Params.StartLocation = InParams.StartLocation;
        Params.StartRotation = InParams.StartRotation;
        Params.EndLocation = InParams.EndLocation;
        Params.EndRotation = InParams.EndRotation;
        Params.Duration = InParams.Duration;
        Params.Easing = InParams.Easing;

        auto State = FMars_Fragment_Mover();
        State.AtEnd = InParams.StartAtEnd;
        State.Alpha = InParams.StartAtEnd ? 1.0f : 0.0f;

        InNode.Add_Fragment(FMars_Feature_Mover());
        InNode.Add_Fragment(Params);
        InNode.Add_Fragment(State);

        Request_ApplyAlpha(InNode, Params, State.Alpha);
        return InNode.As_Mover();
    }

    // One combined offset request: separate location and rotation requests would each rebuild the offset from the
    // not-yet-updated current one, and the later would undo the earlier.
    void Request_ApplyAlpha(FCk_Handle_SceneNode& InNode, const FMars_Fragment_Mover_Params& InParams, float32 InAlpha)
    {
        const auto Location = InParams.StartLocation + (InParams.EndLocation - InParams.StartLocation) * InAlpha;
        const auto Rotation = FRotator(
            InParams.StartRotation.Pitch + (InParams.EndRotation.Pitch - InParams.StartRotation.Pitch) * InAlpha,
            InParams.StartRotation.Yaw + (InParams.EndRotation.Yaw - InParams.StartRotation.Yaw) * InAlpha,
            InParams.StartRotation.Roll + (InParams.EndRotation.Roll - InParams.StartRotation.Roll) * InAlpha);

        auto Offset = utils_scene_node::Get_Offset(InNode);
        Offset.SetLocation(Location);
        Offset.SetRotation(Rotation);
        utils_scene_node::Request_UpdateOffset(InNode, FCk_Request_SceneNode_UpdateRelativeTransform(Offset));
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_AtEnd(const FCk_Handle_Mover& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mover).AtEnd;
}

mixin float32 Get_Alpha(const FCk_Handle_Mover& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Mover).Alpha;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_MoveTo(FCk_Handle_Mover& Self, bool InAtEnd)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mover_Requests);
    Requests.MoveToRequest = FMars_Request_Mover_MoveTo(InAtEnd);
}

mixin void Request_Scrub(FCk_Handle_Mover& Self, const FMars_Request_Mover_Scrub& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mover_Requests);
    Requests.ScrubRequest = InRequest;
}

mixin void Request_Settle(FCk_Handle_Mover& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Mover_Requests);
    Requests.SettleRequest = FMars_Request_Mover_Settle();
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnTargetChanged(FCk_Handle_Mover& Self, FMars_Delegate_Mover_OnTargetChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Mover_Signals);
    Fragment.OnTargetChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnTargetChanged(FCk_Handle_Mover& Self, FMars_Delegate_Mover_OnTargetChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Mover_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Mover_Signals).OnTargetChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnArrived(FCk_Handle_Mover& Self, FMars_Delegate_Mover_OnArrived InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Mover_Signals);
    Fragment.OnArrived.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnArrived(FCk_Handle_Mover& Self, FMars_Delegate_Mover_OnArrived InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Mover_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Mover_Signals).OnArrived.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
