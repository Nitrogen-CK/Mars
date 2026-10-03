namespace utils_gate
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Gate Add(FCk_Handle_Transform& InOwner, FMars_Gate_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Gate] [{InOwner.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Gate(); }

        const auto StartOffset = InParams.StartOpen ? InParams.OpenOffset : FVector::ZeroVector;
        auto MovingNode = utils_scene_node::Create(InOwner, FTransform(FRotator::ZeroRotator, StartOffset, FVector::OneVector));

        auto MoverSpec = FMars_Mover_Spec();
        MoverSpec.EndLocation = InParams.OpenOffset;
        MoverSpec.Duration = InParams.MoveDuration;
        MoverSpec.Easing = InParams.Easing;
        MoverSpec.StartPose = InParams.StartOpen ? EMars_Mover_Pose::End : EMars_Mover_Pose::Start;
        utils_mover::Add(MovingNode, MoverSpec);

        auto Gate = FMars_Fragment_Gate();
        Gate.State = InParams.StartOpen ? EMars_Gate_State::Open : EMars_Gate_State::Closed;
        Gate.MovingNode = MovingNode;
        if (InParams.Threshold.IsSet())
        { Gate.Threshold = utils_trigger::Add(InOwner, InParams.Threshold.GetValue()); }

        InOwner.Add_Fragment(FMars_Feature_Gate());
        InOwner.Add_Fragment(Gate);
        InOwner.Add_Fragment(FMars_Tag_Gate_NeedsSetup());
        return InOwner.As_Gate();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_Gate_State Get_State(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).State;
}

// True while a close is deferred too: the gate is still open then.
mixin bool Get_IsOpen(const FCk_Handle_Gate& Self)
{
    return Self.Get_State() != EMars_Gate_State::Closed;
}

mixin bool Get_IsCloseDeferred(const FCk_Handle_Gate& Self)
{
    return Self.Get_State() == EMars_Gate_State::CloseDeferred;
}

mixin FCk_Handle_SceneNode Get_MovingNode(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).MovingNode;
}

mixin FCk_Handle_Trigger Get_Threshold(const FCk_Handle_Gate& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Gate).Threshold;
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

mixin void Request_SetPosition(FCk_Handle_Gate& Self, const FMars_Request_Gate_SetPosition& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Gate_Requests);
    Requests.SetPositionRequests.Add(InRequest);
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
