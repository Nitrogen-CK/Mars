namespace utils_mechanism_sink
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_MechanismSink Add(FCk_Handle& InHandle, FMars_MechanismSink_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[MechanismSink] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_MechanismSink(); }

        auto Params = FMars_Fragment_MechanismSink_Params();
        Params.InputChannels = InParams.InputChannels;
        Params.Rule = InParams.Rule;
        Params.Latch = InParams.Latch;

        auto State = FMars_Fragment_MechanismSink();
        for (const auto& Channel : InParams.InputChannels)
        {
            auto Input = FMars_MechanismSink_ChannelInput();
            Input.Channel = Channel;
            State.Inputs.Add(Input);
        }

        InHandle.Add_Fragment(FMars_Feature_MechanismSink());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        utils_entity_tag::Add(InHandle, n"TAG_MarsMechanismSink");
        return InHandle.As_MechanismSink();
    }

    // A placeable script's sink is optional: an empty InputChannels means unwired, and adds nothing (invalid handle).
    FCk_Handle_MechanismSink TryAdd(FCk_Handle& InHandle, FMars_MechanismSink_Spec InParams)
    {
        if (InParams.InputChannels.Num() == 0)
        { return FCk_Handle_MechanismSink(); }

        return Add(InHandle, InParams);
    }

    // Whether a consumer gated by InBehavior runs at InPower. Never called with Unevaluated: OnPoweredChanged never
    // broadcasts it.
    bool Get_ShouldRun(EMars_PoweredBehavior InBehavior, EMars_MechanismSink_Power InPower)
    {
        const auto IsPowered = InPower == EMars_MechanismSink_Power::Powered;
        return InBehavior == EMars_PoweredBehavior::RunWhilePowered ? IsPowered : (IsPowered == false);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin TArray<FGameplayTag> Get_InputChannels(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink_Params).InputChannels;
}

mixin bool Get_HasEvaluated(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink).Power != EMars_MechanismSink_Power::Unevaluated;
}

mixin bool Get_IsPowered(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink).Power == EMars_MechanismSink_Power::Powered;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Only the mechanism driver calls this; it pushes every channel on every recompute, so once the sink has evaluated an
// unchanged input is dropped here. Before that every push goes through: the first evaluation needs one in the drain, and
// an unsourced channel's (0, 0) push matches the initial input.
mixin void Request_SetChannelInput(FCk_Handle_MechanismSink& Self, const FMars_Request_MechanismSink_SetChannelInput& InRequest)
{
    if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Requests))
    {
        auto& Pending = Self.Get_Fragment(FMars_Fragment_MechanismSink_Requests);
        for (int32 Index = 0; Index < Pending.SetChannelInputRequests.Num(); ++Index)
        {
            if (Pending.SetChannelInputRequests[Index].Channel == InRequest.Channel)
            {
                Pending.SetChannelInputRequests[Index] = InRequest;
                return;
            }
        }
    }

    const auto& State = Self.Get_Fragment(FMars_Fragment_MechanismSink);
    if (State.Power != EMars_MechanismSink_Power::Unevaluated)
    {
        for (const auto& Input : State.Inputs)
        {
            if (Input.Channel == InRequest.Channel
                && Input.AssertedCount == InRequest.AssertedCount
                && Input.TotalCount == InRequest.TotalCount)
            { return; }
        }
    }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Requests);
    Requests.SetChannelInputRequests.Add(InRequest);
}

// Only the mechanism driver calls this, once per source flip; edges are delivered in enqueue order.
mixin void Request_NotifyInputEdge(FCk_Handle_MechanismSink& Self, const FMars_Request_MechanismSink_NotifyInputEdge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Requests);
    Requests.NotifyInputEdgeRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

// With FireIfPayloadInFlight (either flavour) a sink that has already evaluated calls InDelegate now with its current power,
// so a link set up after the first evaluation needs no replay of its own. An unevaluated sink waits for its first broadcast.
mixin void BindTo_OnPoweredChanged(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnPoweredChanged InDelegate,
                                   ECk_Signal_BindingPolicy InPolicy = ECk_Signal_BindingPolicy::IgnorePayloadInFlight)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Signals);
    Fragment.OnPoweredChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());

    if (InPolicy == ECk_Signal_BindingPolicy::IgnorePayloadInFlight)
    { return; }

    const auto Power = Self.Get_Fragment(FMars_Fragment_MechanismSink).Power;
    if (Power == EMars_MechanismSink_Power::Unevaluated)
    { return; }

    InDelegate.ExecuteIfBound(Self, Power);
}

mixin void UnbindFrom_OnPoweredChanged(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnPoweredChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnPoweredChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnInputEdge(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnInputEdge InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Signals);
    Fragment.OnInputEdge.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnInputEdge(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnInputEdge InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnInputEdge.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnInputRose(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnInputRose InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Signals);
    Fragment.OnInputRose.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnInputRose(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnInputRose InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnInputRose.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
