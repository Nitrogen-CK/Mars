namespace utils_camp_session
{
    // The phase lives on a CkStateMachine so it can replicate with server authority; the machine does not replicate yet.
    FCk_Handle_CampSession Add(FCk_Handle& InOwner, FMars_CampSession_Spec InSpec)
    {
        const auto StartsLive = InSpec.StartPhase == EMars_CampPhase::Live;
        auto SmSpec = FCk_StateMachine_Spec(UMars_SmState_Camp_Lobby);
        if (StartsLive)
        { SmSpec = FCk_StateMachine_Spec(UMars_SmState_Camp_Live); }

        auto State = FMars_Fragment_CampSession();
        State.Phase = InSpec.StartPhase;
        State.StateMachine = utils_state_machine::Add(InOwner, SmSpec);

        InOwner.Add_Fragment(FMars_Feature_CampSession());
        InOwner.Add_Fragment(State);
        return InOwner.As_CampSession();
    }
}

//--------------------------------------------------------------------------------------------------------------------------
// Getters
//--------------------------------------------------------------------------------------------------------------------------

mixin EMars_CampPhase Get_Phase(const FCk_Handle_CampSession& Self)
{ return Self.Get_Fragment(FMars_Fragment_CampSession).Phase; }

mixin bool Get_IsLive(const FCk_Handle_CampSession& Self)
{ return Self.Get_Phase() == EMars_CampPhase::Live; }

//--------------------------------------------------------------------------------------------------------------------------
// Requests
//--------------------------------------------------------------------------------------------------------------------------

mixin void Request_Play(FCk_Handle_CampSession& Self)
{
    auto& Requests = Self.AddOrGet_Fragment(FMars_Fragment_CampSession_Requests);
    Requests.PlayRequests.Add(FMars_Request_CampSession_Play());
}

//--------------------------------------------------------------------------------------------------------------------------
// Signal Binding
//--------------------------------------------------------------------------------------------------------------------------

mixin void BindTo_OnPhaseChanged(FCk_Handle_CampSession& Self, FMars_Delegate_CampSession_OnPhaseChanged InDelegate)
{
    auto& Fragment = Self.AddOrGet_Fragment(FMars_Fragment_CampSession_Signals);
    Fragment.OnPhaseChanged.AddUFunction(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}

mixin void UnbindFrom_OnPhaseChanged(FCk_Handle_CampSession& Self, FMars_Delegate_CampSession_OnPhaseChanged InDelegate)
{
    if (Self.Has_Fragment(FMars_Fragment_CampSession_Signals) == false)
    { return; }

    Self.Get_Fragment(FMars_Fragment_CampSession_Signals).OnPhaseChanged.Unbind(InDelegate.GetUObject(), InDelegate.GetFunctionName());
}
