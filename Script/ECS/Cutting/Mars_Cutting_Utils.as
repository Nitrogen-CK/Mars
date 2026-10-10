namespace utils_cutting
{
    // Composes the cleaver on InHandle (the station entity; the feature does not need the Station feature). The spec's Nodes
    // are built by the caller: the hand slides Nodes.LateralNode along local Y. The chop is the kernel's clock alone: what
    // draws the cleaver follows its signals. A rejected spec or a missing node ensures and returns an invalid handle.
    FCk_Handle_Cutting Add(FCk_Handle& InHandle, FMars_Cutting_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Cutting] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Cutting(); }

        if (ck::EnsureIfNot(ck::IsValid(InSpec.Nodes.LateralNode), f"[Cutting] [{InHandle.ToString()}] needs a lateral node"))
        { return FCk_Handle_Cutting(); }

        auto Params = FMars_Fragment_Cutting_Params();
        Params.Spec = InSpec;

        InHandle.Add_Fragment(FMars_Feature_Cutting());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Cutting());
        return InHandle.As_Cutting();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Cutting_Spec Get_Spec(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting_Params).Spec;
}

mixin float32 Get_HandLateral(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting).HandLateral;
}

mixin EMars_Cutting_ChopPhase Get_ChopPhase(const FCk_Handle_Cutting& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Cutting).ChopPhase;
}

// From a chop's start until its recover ends: a press meanwhile is ignored.
mixin bool Get_IsChopping(const FCk_Handle_Cutting& Self)
{
    return Self.Get_ChopPhase() != EMars_Cutting_ChopPhase::Idle;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Nudge(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_Nudge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.NudgeRequests.Add(InRequest);
}

mixin void Request_Chop(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_Chop& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.ChopRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Cutting& Self, const FMars_Request_Cutting_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Requests);
    Requests.ResetRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnChopStarted(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopStarted InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Signals);
    Fragment.OnChopStarted.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnChopStarted(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopStarted InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopStarted.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnChopLanded(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopLanded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Cutting_Signals);
    Fragment.OnChopLanded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnChopLanded(FCk_Handle_Cutting& Self, FMars_Delegate_Cutting_OnChopLanded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Cutting_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Cutting_Signals).OnChopLanded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
