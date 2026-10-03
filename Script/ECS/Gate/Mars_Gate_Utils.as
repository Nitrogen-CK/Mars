namespace utils_gate
{
    FCk_Handle_Gate Add(FCk_Handle_Transform& InOwner, FMars_Gate_Spec InParams)
    {
        const auto StartOffset = InParams.StartOpen ? InParams.OpenOffset : FVector::ZeroVector;
        auto MovingNode = utils_scene_node::Create(InOwner, FTransform(FRotator::ZeroRotator, StartOffset, FVector::OneVector));

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = InParams.OpenOffset;
        MoverSpec.Duration = InParams.MoveDuration;
        MoverSpec.Easing = InParams.Easing;
        MoverSpec.StartAtEnd = InParams.StartOpen;
        utils_mover::Add(MovingNode, MoverSpec);

        auto State = FMars_Fragment_Gate();
        State.IsOpen = InParams.StartOpen;
        State.MovingNode = MovingNode;
        if (InParams.Threshold.IsSet())
        { State.Threshold = utils_trigger::Add(InOwner, InParams.Threshold.GetValue()); }

        InOwner.Add_Fragment(FMars_Feature_Gate());
        InOwner.Add_Fragment(State);
        InOwner.Add_Fragment(FMars_Tag_Gate_NeedsSetup());
        return InOwner.As_Gate();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin bool Get_IsOpen(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).IsOpen;
}

mixin FCk_Handle_SceneNode Get_MovingNode(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).MovingNode;
}

mixin FCk_Handle_Trigger Get_Threshold(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).Threshold;
}

mixin bool Get_IsCloseDeferred(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).IsCloseDeferred;
}

// False for a gate without a threshold.
mixin bool Get_IsThresholdOccupied(const FCk_Handle_Gate& Self)
{
    const auto Threshold = Self.Get_Threshold();
    return ck::IsValid(Threshold) && Threshold.Get_EntityCount() > 0;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetOpen(FCk_Handle_Gate& Self, bool InOpen)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Gate_Requests);
    Requests.SetOpenRequests.Add(FMars_Request_Gate_SetOpen(InOpen));
}

mixin void Request_RetryClose(FCk_Handle_Gate& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Gate_Requests);
    Requests.RetryCloseRequests.Add(FMars_Request_Gate_RetryClose());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnOpenChanged(FCk_Handle_Gate& Self, FMars_Delegate_Gate_OnOpenChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Gate_Signals);
    Fragment.OnOpenChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnOpenChanged(FCk_Handle_Gate& Self, FMars_Delegate_Gate_OnOpenChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Gate_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Gate_Signals).OnOpenChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
