namespace utils_mechanism_source
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_MechanismSource Add(FCk_Handle& InHandle, FMars_MechanismSource_Spec InParams)
    {
        const auto Validation = InParams.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[MechanismSource] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_MechanismSource(); }

        auto Params = FMars_Fragment_MechanismSource_Params();
        Params.OutputChannel = InParams.OutputChannel;

        auto State = FMars_Fragment_MechanismSource();
        State.Output = InParams.StartAsserted ? EMars_MechanismSource_Output::Asserted : EMars_MechanismSource_Output::Deasserted;

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
    return Self.Get_Fragment(FMars_Fragment_MechanismSource).Output == EMars_MechanismSource_Output::Asserted;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_SetOutput(FCk_Handle_MechanismSource& Self, const FMars_Request_MechanismSource_SetOutput& InRequest)
{
    // Dropped only when nothing is pending: with a request pending, one matching the current output must still override it.
    if (Self.Has_Fragment(FMars_Fragment_MechanismSource_Requests) == false
        && Self.Get_Fragment(FMars_Fragment_MechanismSource).Output == InRequest.Output)
    { return; }

    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_MechanismSource_Requests);
    Requests.SetOutputRequests.Add(InRequest);
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
