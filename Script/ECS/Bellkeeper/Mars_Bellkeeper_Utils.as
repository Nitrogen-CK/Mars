namespace utils_bellkeeper
{
    // Expects the entity to also carry a MechanismSink whose rising edges are commits and, optionally, a MechanismSource
    // asserted once solved; the setup processor links them. Build the dials first: Validate() reads where they point.
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Bellkeeper Add(FCk_Handle& InHandle, FMars_Bellkeeper_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Bellkeeper] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Bellkeeper(); }

        auto Params = FMars_Fragment_Bellkeeper_Params();
        Params.Dials = InSpec.Dials;
        Params.Answer = InSpec.Answer;
        Params.Rewards = InSpec.Rewards;
        Params.VentSource = InSpec.VentSource;
        Params.VentPulseSeconds = InSpec.VentPulseSeconds;

        InHandle.Add_Fragment(FMars_Feature_Bellkeeper());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Bellkeeper());
        InHandle.Add_Fragment(FMars_Tag_Bellkeeper_NeedsSetup());
        return InHandle.As_Bellkeeper();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin int32 Get_FailedCommits(const FCk_Handle_Bellkeeper& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bellkeeper).FailedCommits;
}

// The rewards a correct commit would still pay out: every one but those lost, and never fewer than one.
mixin int32 Get_RemainingRewards(const FCk_Handle_Bellkeeper& Self)
{
    const auto RewardCount = Self.Get_Fragment(FMars_Fragment_Bellkeeper_Params).Rewards.Num();
    return RewardCount - Math::Min(Self.Get_FailedCommits(), RewardCount - 1);
}

mixin bool Get_IsSolved(const FCk_Handle_Bellkeeper& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bellkeeper).Solved;
}

mixin bool Get_IsVenting(const FCk_Handle_Bellkeeper& Self)
{
    return ck::IsValid(Self.Get_Fragment(FMars_Fragment_Bellkeeper).VentTimer);
}

mixin TArray<FCk_Handle> Get_RewardHandles(const FCk_Handle_Bellkeeper& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bellkeeper).RewardHandles;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Commit(FCk_Handle_Bellkeeper& Self, const FMars_Request_Bellkeeper_Commit& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Requests);
    Requests.CommitRequests.Add(InRequest);
}

mixin void Request_EndVent(FCk_Handle_Bellkeeper& Self, const FMars_Request_Bellkeeper_EndVent& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Requests);
    Requests.EndVentRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnCommitFailed(FCk_Handle_Bellkeeper& Self, FMars_Delegate_Bellkeeper_OnCommitFailed InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Signals);
    Fragment.OnCommitFailed.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnCommitFailed(FCk_Handle_Bellkeeper& Self, FMars_Delegate_Bellkeeper_OnCommitFailed InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bellkeeper_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnCommitFailed.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnSolved(FCk_Handle_Bellkeeper& Self, FMars_Delegate_Bellkeeper_OnSolved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Signals);
    Fragment.OnSolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnSolved(FCk_Handle_Bellkeeper& Self, FMars_Delegate_Bellkeeper_OnSolved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bellkeeper_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnSolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
