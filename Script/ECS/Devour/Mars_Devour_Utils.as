// The Devour feature's public surface: the composer, the request writers, the getters and the signal binds. The Do*
// functions are the two transitions its processors share; nothing else calls them.

namespace utils_devour
{
    // A spec that fails Validate() ensures and adds nothing.
    FCk_Handle_Devour Add(FCk_Handle& InHandle, FMars_Devour_Spec InSpec)
    {
        const auto Validation = InSpec.Validate();
        if (ck::EnsureIfNot(Validation.IsValid(), f"[Devour] [{InHandle.ToString()}] rejected the spec: {Validation.Get_Error()}"))
        { return FCk_Handle_Devour(); }

        auto Params = FMars_Fragment_Devour_Params();
        Params.Timing = InSpec.Timing;
        Params.View = InSpec.View;

        InHandle.Add_Fragment(FMars_Feature_Devour());
        InHandle.Add_Fragment(Params);
        InHandle.Add_Fragment(FMars_Fragment_Devour());

        return InHandle.As_Devour();
    }

    // The devourer holding InVictim; invalid when nothing holds it.
    FCk_Handle_Devour TryGet_Devourer(const FCk_Handle& InVictim)
    {
        if (ck::Is_NOT_Valid(InVictim) || InVictim.Has_Fragment(FMars_Fragment_Devour_Victim) == false)
        { return FCk_Handle_Devour(); }

        return InVictim.Get_Fragment(FMars_Fragment_Devour_Victim).Devourer;
    }

    // Processor-only: takes InVictim and enters Seize. The caller broadcasts.
    void DoSeize(FCk_Handle_Devour& InDevour, FMars_Fragment_Devour& InState, FCk_Handle InVictim)
    {
        auto Marker = FMars_Fragment_Devour_Victim();
        Marker.Devourer = InDevour;

        // A by-value handle is read-only; the copy is the same entity.
        auto Victim = InVictim;
        Victim.Add_Fragment(Marker);

        InState.Victim = Victim;
        InState.Phase = EMars_Devour_Phase::Seize;
        InState.PhaseSeconds = 0.0f;
        InDevour.Add_Fragment(FMars_Tag_Devour_Running());
    }

    // Processor-only: lets the victim go and returns to Idle. Returns the victim that was held (it may be invalid). The
    // caller broadcasts.
    FCk_Handle DoRelease(FCk_Handle_Devour& InDevour, FMars_Fragment_Devour& InState)
    {
        auto Victim = InState.Victim;
        if (ck::IsValid(Victim) && Victim.Has_Fragment(FMars_Fragment_Devour_Victim))
        { Victim.Request_TryRemove(FMars_Fragment_Devour_Victim); }

        InState.Victim = FCk_Handle();
        InState.Phase = EMars_Devour_Phase::Idle;
        InState.PhaseSeconds = 0.0f;
        InDevour.Request_TryRemove(FMars_Tag_Devour_Running);
        return Victim;
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_Devour_Phase Get_Phase(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour).Phase;
}

// A victim is held.
mixin bool Get_IsActive(const FCk_Handle_Devour& Self)
{
    return Self.Get_Phase() != EMars_Devour_Phase::Idle;
}

// Whether a Begin for InVictim would be taken now: nobody is held, and the victim is valid, is not the devourer itself
// and is not already held.
mixin bool Get_CanSeize(const FCk_Handle_Devour& Self, const FCk_Handle& InVictim)
{
    if (Self.Get_IsActive() || ck::Is_NOT_Valid(InVictim))
    { return false; }

    if (InVictim == Self.H())
    { return false; }

    return InVictim.Has_Fragment(FMars_Fragment_Devour_Victim) == false;
}

// Invalid while Idle.
mixin FCk_Handle Get_Victim(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour).Victim;
}

mixin float32 Get_PhaseSeconds(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour).PhaseSeconds;
}

// How far through the current phase, 0..1; 0 while Idle.
mixin float32 Get_PhaseAlpha(const FCk_Handle_Devour& Self)
{
    const auto& State = Self.Get_Fragment(FMars_Fragment_Devour);
    const auto Seconds = Self.Get_Timing().Get_Seconds(State.Phase);
    if (Seconds <= 0.0f)
    { return 0.0f; }

    return Math::Clamp(State.PhaseSeconds / Seconds, 0.0f, 1.0f);
}

mixin FMars_Devour_Timing Get_Timing(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour_Params).Timing;
}

// The node a held victim's view is given to; invalid when the spec named none.
mixin FCk_Handle_Transform Get_View(const FCk_Handle_Devour& Self)
{
    return Self.Get_Fragment(FMars_Fragment_Devour_Params).View;
}

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Begin(FCk_Handle_Devour& Self, const FMars_Request_Devour_Begin& InRequest)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Requests);
    Requests.BeginRequests.Add(InRequest);
}

mixin void Request_Cancel(FCk_Handle_Devour& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Requests);
    Requests.CancelRequests.Add(FMars_Request_Devour_Cancel());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Devour_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void BindTo_OnEnded(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnEnded InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_Devour_Signals);
    Fragment.OnEnded.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnEnded(FCk_Handle_Devour& Self, FMars_Delegate_Devour_OnEnded InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_Devour_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_Devour_Signals).OnEnded.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
