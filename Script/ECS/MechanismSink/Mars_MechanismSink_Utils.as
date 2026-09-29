namespace utils_mechanism_sink
{
    FCk_Handle_MechanismSink Add(FCk_Handle& InHandle, FMars_MechanismSink_Spec InParams)
    {
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
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin TArray<FGameplayTag> Get_InputChannels(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink_Params).InputChannels;
}

mixin EMars_MechanismSink_Rule Get_Rule(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink_Params).Rule;
}

mixin bool Get_IsLatch(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink_Params).Latch;
}

mixin bool Get_IsPowered(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink).IsPowered;
}

mixin TArray<FMars_MechanismSink_ChannelInput> Get_Inputs(const FCk_Handle_MechanismSink& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSink).Inputs;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

// Only the mechanism driver calls this; it pushes every channel on every recompute, so unchanged inputs are dropped here.
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
    for (const auto& Input : State.Inputs)
    {
        if (Input.Channel == InRequest.Channel
            && Input.AssertedCount == InRequest.AssertedCount
            && Input.TotalCount == InRequest.TotalCount)
        { return; }
    }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Requests);
    Requests.SetChannelInputRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPoweredChanged(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnPoweredChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSink_Signals);
    Fragment.OnPoweredChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPoweredChanged(FCk_Handle_MechanismSink& Self, FMars_Delegate_MechanismSink_OnPoweredChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_MechanismSink_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_MechanismSink_Signals).OnPoweredChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
