namespace utils_dicing
{
    // The band table: where the band sits after each useful chop, as a fraction of BoardHalfWidth. Deterministic so tests
    // can follow it; it wraps after the last entry.
    const int32 k_BandTableSize = 8;

    // Composes the minigame on InHandle (the station entity; the feature does not need the Station feature). InNodes are
    // built by the caller (the entity script): the hand slides InNodes.LateralNode along local Y, and InNodes.ChopMover
    // strikes from its start (raised) to its end (contact). A rejected spec or a missing node ensures and returns an
    // invalid handle.
    FCk_Handle_Dicing Add(FCk_Handle& InHandle, FMars_Dicing_Spec InSpec, FMars_Dicing_Nodes InNodes)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid, f"[Dicing] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Dicing(); }

        if (ck::EnsureIfNot(ck::IsValid(InNodes.LateralNode) && ck::IsValid(InNodes.ChopMover),
            f"[Dicing] [{InHandle.ToString()}] needs a lateral node and a chop Mover"))
        { return FCk_Handle_Dicing(); }

        auto Params = FMars_Fragment_Dicing_Params();
        Params.Spec = InSpec;

        auto State = FMars_Fragment_Dicing();
        State.BandIndex = 0;
        State.BandCenter = Get_BandCenterAt(InSpec, 0);
        State.LateralNode = InNodes.LateralNode;
        State.ChopMover = InNodes.ChopMover;

        InHandle.Add_Fragment(FMars_Feature_Dicing());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(State);
        InHandle.Add_Fragment(FMars_Tag_Dicing_NeedsSetup());
        auto Dicing = InHandle.As_Dicing();

        auto Link = FMars_Fragment_Dicing_ChopLink();
        Link.Dicing = Dicing;
        auto MoverEntity = FCk_Handle(InNodes.ChopMover);
        MoverEntity.Add_Fragment(Link);

        return Dicing;
    }

    float32 Get_BandFraction(int32 InIndex)
    {
        switch (InIndex % k_BandTableSize)
        {
            case 0: return -0.6f;
            case 1: return 0.6f;
            case 2: return -0.2f;
            case 3: return 0.4f;
            case 4: return -0.5f;
            case 5: return 0.1f;
            case 6: return 0.6f;
            case 7: return -0.4f;
        }

        return 0.0f;
    }

    // uu along the board for band table entry InIndex.
    float32 Get_BandCenterAt(const FMars_Dicing_Spec& InSpec, int32 InIndex)
    {
        return Get_BandFraction(InIndex) * InSpec.BoardHalfWidth;
    }

    // GreenPaste stays GreenPaste.
    EMars_Dicing_State Get_NextState(EMars_Dicing_State InState)
    {
        switch (InState)
        {
            case EMars_Dicing_State::WholeLeaves: return EMars_Dicing_State::CoarseChop;
            case EMars_Dicing_State::CoarseChop: return EMars_Dicing_State::FineFlecks;
            case EMars_Dicing_State::FineFlecks: return EMars_Dicing_State::GreenPaste;
            default: return EMars_Dicing_State::GreenPaste;
        }
    }

    FString Get_StateName(EMars_Dicing_State InState)
    {
        switch (InState)
        {
            case EMars_Dicing_State::WholeLeaves: return "Whole leaves";
            case EMars_Dicing_State::CoarseChop: return "Coarse chop";
            case EMars_Dicing_State::FineFlecks: return "Fine flecks";
            default: return "Green paste";
        }
    }

    // What the station's label reads: the texture, "stop here" once it is exactly the requested one, "over-processed"
    // past it.
    FText Get_StateLabel(EMars_Dicing_State InState, EMars_Dicing_State InRequested)
    {
        const auto Name = Get_StateName(InState);
        if (InState == InRequested)
        { return FText::FromString(f"{Name}: stop here"); }

        if (int32(InState) > int32(InRequested))
        { return FText::FromString(f"{Name}: over-processed"); }

        return FText::FromString(Name);
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin FMars_Dicing_Spec Get_Spec(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing_Params).Spec;
}

mixin EMars_Dicing_State Get_MaterialState(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing).MaterialState;
}

mixin EMars_Dicing_State Get_RequestedState(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing_Params).Spec.RequestedState;
}

// The requested texture or anything past it.
mixin bool Get_HasReachedRequested(const FCk_Handle_Dicing& Self)
{
    return int32(Self.Get_MaterialState()) >= int32(Self.Get_RequestedState());
}

mixin float32 Get_HandLateral(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing).HandLateral;
}

mixin float32 Get_BandCenter(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing).BandCenter;
}

mixin bool Get_IsAligned(const FCk_Handle_Dicing& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Dicing);
    return Math::Abs(State.HandLateral - State.BandCenter) <= Self.Get_Fragment(FMars_Fragment_Dicing_Params).Spec.BandHalfWidth;
}

mixin bool Get_IsChopping(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing).IsChopping;
}

mixin int32 Get_UsefulChops(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing).UsefulChops;
}

mixin int32 Get_ChopsInState(const FCk_Handle_Dicing& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Dicing).ChopsInState;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Nudge(FCk_Handle_Dicing& Self, const FMars_Request_Dicing_Nudge& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Requests);
    Requests.NudgeRequests.Add(InRequest);
}

mixin void Request_Chop(FCk_Handle_Dicing& Self, const FMars_Request_Dicing_Chop& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Requests);
    Requests.ChopRequests.Add(InRequest);
}

mixin void Request_Reset(FCk_Handle_Dicing& Self, const FMars_Request_Dicing_Reset& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Requests);
    Requests.ResetRequests.Add(InRequest);
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnChopResolved(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnChopResolved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Signals);
    Fragment.OnChopResolved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnChopResolved(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnChopResolved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnChopResolved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnStateChanged(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnStateChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Signals);
    Fragment.OnStateChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnStateChanged(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnStateChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnStateChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnBandMoved(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnBandMoved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Signals);
    Fragment.OnBandMoved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnBandMoved(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnBandMoved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnBandMoved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnHandMoved(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnHandMoved InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Signals);
    Fragment.OnHandMoved.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnHandMoved(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnHandMoved InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnHandMoved.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnRequestedStateReached(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnRequestedStateReached InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Dicing_Signals);
    Fragment.OnRequestedStateReached.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnRequestedStateReached(FCk_Handle_Dicing& Self, FMars_Delegate_Dicing_OnRequestedStateReached InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Dicing_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Dicing_Signals).OnRequestedStateReached.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
