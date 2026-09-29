namespace utils_mechanism_source
{
    FCk_Handle_MechanismSource Add(FCk_Handle& InHandle, FMars_MechanismSource_Spec InParams)
    {
        auto Params = FMars_Fragment_MechanismSource_Params();
        Params.OutputChannel = InParams.OutputChannel;

        auto State = FMars_Fragment_MechanismSource();
        State.IsAsserted = InParams.StartAsserted;

        InHandle.Add_Fragment(FMars_Feature_MechanismSource());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        utils_entity_tag::Add(InHandle, n"TAG_MarsMechanismSource");
        return InHandle.As_MechanismSource();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FGameplayTag Get_OutputChannel(const FCk_Handle_MechanismSource& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSource_Params).OutputChannel;
}

mixin bool Get_IsAsserted(const FCk_Handle_MechanismSource& Self)
{
    return Self.Get_Fragment(FMars_Fragment_MechanismSource).IsAsserted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetAsserted(FCk_Handle_MechanismSource& Self, bool InAsserted)
{
    // A pending request must still be overwritten even when InAsserted matches the current state.
    if (Self.Has_Fragment(FMars_Fragment_MechanismSource_Requests) == false
        && Self.Get_Fragment(FMars_Fragment_MechanismSource).IsAsserted == InAsserted)
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSource_Requests);
    Requests.SetAsserted = FMars_Request_MechanismSource_SetAsserted(InAsserted);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnAssertedChanged(FCk_Handle_MechanismSource& Self, FMars_Delegate_MechanismSource_OnAssertedChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSource_Signals);
    Fragment.OnAssertedChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnAssertedChanged(FCk_Handle_MechanismSource& Self, FMars_Delegate_MechanismSource_OnAssertedChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_MechanismSource_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_MechanismSource_Signals).OnAssertedChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
