namespace utils_bellkeeper
{
    // Expects the entity to also carry a MechanismSink whose rising edges are commits and, optionally, a MechanismSource
    // asserted once solved; the setup processor links them. Build the dials first: Validate() reads where they point.
    // A spec that fails Validate() ensures and adds nothing; a copy without authority needs only Validate_Shown().
    FCk_Handle_Bellkeeper Add(FCk_Handle& InHandle, FMars_Bellkeeper_Spec InSpec)
    {
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        const auto Validation = HasAuthority ? InSpec.Validate() : InSpec.Validate_Shown();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Bellkeeper] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Bellkeeper(); }

        if (ck::IsValid(InSpec.VentCycle)
            && ck::EnsureIfNot(utils_entity_lifetime::Get_LifetimeOwner(InSpec.VentCycle) == InHandle,
                "[Bellkeeper] VentCycle must be a directly owned child of the lock"))
        { return FCk_Handle_Bellkeeper(); }

        auto Params = FMars_Fragment_Bellkeeper_Params();
        Params.Dials = InSpec.Dials;
        Params.Answer = InSpec.Answer;
        Params.Rewards = InSpec.Rewards;
        Params.VentSource = InSpec.VentSource;
        Params.VentPulseSeconds = InSpec.VentPulseSeconds;
        Params.VentCycle = InSpec.VentCycle;

        InHandle.Add_Fragment(FMars_Feature_Bellkeeper());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Bellkeeper());

        auto Mirror = FMars_Fragment_Bellkeeper_Mirror();
        Mirror.Last = Make_Ledger(FMars_Fragment_Bellkeeper(), InSpec.Dials);

        // A ledger already here can only have been put here by its replicated application: this copy was born into it,
        // has taken that state, and the mirror's first pass shows it as it stands.
        if (InHandle.Has_Fragment(FMars_Fragment_Bellkeeper_Net))
        { Mirror.InitialState = EMars_Net_InitialState::Taken; }
        else
        { InHandle.Add_Fragment(Mirror.Last, ECk_Replication::Replicates); }

        InHandle.Add_Fragment(Mirror);
        InHandle.Add_Fragment(FMars_Tag_Bellkeeper_NeedsSetup());
        return InHandle.As_Bellkeeper();
    }

    // Writes the lock's ledger from its state and its dials when they differ from what it carries. The one writer of
    // the ledger, called at the end of the authority's drain; without authority it does nothing.
    void Publish(FCk_Handle_Bellkeeper& InBellkeeper)
    {
        if (utils_net::Get_HasAuthority(InBellkeeper) == false)
        { return; }

        const auto Published = Make_Ledger(InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper), InBellkeeper.Get_Dials());
        auto& Ledger = InBellkeeper.Get_Fragment(FMars_Fragment_Bellkeeper_Net);
        if (Get_IsSameLedger(Ledger, Published))
        { return; }

        Ledger = Published;
        InBellkeeper.Request_MarkReplicationDirty(FMars_Fragment_Bellkeeper_Net);
    }

    // The ledger InState and InDials stand for. A lost dial reads 0 here; it already ensures where a commit judges it.
    FMars_Fragment_Bellkeeper_Net Make_Ledger(const FMars_Fragment_Bellkeeper& InState, const TArray<FCk_Handle_Dial>& InDials)
    {
        auto Ledger = FMars_Fragment_Bellkeeper_Net();
        Ledger.FailedCommits = InState.FailedCommits;
        Ledger.Lock = InState.Solved ? EMars_Bellkeeper_Lock::Solved : EMars_Bellkeeper_Lock::Sealed;
        for (const auto& Dial : InDials)
        { Ledger.DialIndices.Add(ck::IsValid(Dial) ? Dial.Get_Index() : 0); }

        return Ledger;
    }

    // Field by field and index by index.
    bool Get_IsSameLedger(const FMars_Fragment_Bellkeeper_Net& InA, const FMars_Fragment_Bellkeeper_Net& InB)
    {
        if (InA.FailedCommits != InB.FailedCommits || InA.Lock != InB.Lock || InA.DialIndices.Num() != InB.DialIndices.Num())
        { return false; }

        for (int32 Index = 0; Index < InA.DialIndices.Num(); ++Index)
        {
            if (InA.DialIndices[Index] != InB.DialIndices[Index])
            { return false; }
        }

        return true;
    }

    // The rewards a correct commit would still pay out after InFailedCommits failures: every one but those lost, and
    // never fewer than one.
    int32 Get_RemainingAfter(int32 InFailedCommits, int32 InRewardCount)
    {
        return InRewardCount - Math::Min(InFailedCommits, InRewardCount - 1);
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
    return utils_bellkeeper::Get_RemainingAfter(Self.Get_FailedCommits(), RewardCount);
}

mixin bool Get_IsSolved(const FCk_Handle_Bellkeeper& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bellkeeper).Solved;
}

mixin bool Get_IsVenting(const FCk_Handle_Bellkeeper& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Bellkeeper);
    // The authority's: a copy without authority never vents.
    // Includes a dedicated stop/start handshake in flight. This is intent, not proof of running Cycle/armed Hazard;
    // consumers needing that physical state must inspect the composed Cycle/Hazard. Legacy mode remains timer-based.
    return ck::IsValid(State.VentTimer) || State.VentTransition != EMars_Bellkeeper_VentTransition::Idle;
}

// The authority's: a copy without authority holds none.
mixin TArray<FCk_Handle> Get_RewardHandles(const FCk_Handle_Bellkeeper& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bellkeeper).RewardHandles;
}

// The dials this lock judges, in panel order.
mixin TArray<FCk_Handle_Dial> Get_Dials(const FCk_Handle_Bellkeeper& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Bellkeeper_Params).Dials;
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

mixin void Request_VentCycleChanged(FCk_Handle_Bellkeeper& Self, const FMars_Request_Bellkeeper_VentCycleChanged& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Requests);
    Requests.VentCycleChanges.Add(InRequest);
}

mixin void Request_DialMoved(FCk_Handle_Bellkeeper& Self, const FMars_Request_Bellkeeper_DialMoved& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Requests);
    Requests.DialMovedRequests.Add(InRequest);
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

mixin void BindTo_OnStateChanged(FCk_Handle_Bellkeeper& Self, FMars_Delegate_Bellkeeper_OnStateChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Bellkeeper_Signals);
    Fragment.OnStateChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStateChanged(FCk_Handle_Bellkeeper& Self, FMars_Delegate_Bellkeeper_OnStateChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Bellkeeper_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Bellkeeper_Signals).OnStateChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
