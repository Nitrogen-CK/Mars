// Every pass maps the state machine's current state class onto Phase; on a change writes it and broadcasts
// OnPhaseChanged. Phase is written only here and in utils_camp_session::Add.
class UMars_Processor_CampSession_Sync : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CampSession);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle, FMars_Fragment_CampSession& InState)
    {
        // Null until the state machine enters its first state.
        auto Current = utils_state_machine::Get_CurrentStateClass(InState.StateMachine);
        if (ck::Is_NOT_Valid(Current))
        { return; }

        auto Mapped = EMars_CampPhase::Lobby;
        if (Current == UMars_SmState_Camp_Live)
        { Mapped = EMars_CampPhase::Live; }
        else if (ck::EnsureIfNot(Current == UMars_SmState_Camp_Lobby,
            f"[CampSession] [{InHandle.ToString()}] state machine is in [{Current.Get().GetName()}], which is neither camp phase"))
        { return; }

        if (Mapped == InState.Phase)
        { return; }

        const auto Previous = InState.Phase;
        InState.Phase = Mapped;

        if (InHandle.Has_Fragment(FMars_Fragment_CampSession_Signals))
        { InHandle.Get_Fragment(FMars_Fragment_CampSession_Signals).OnPhaseChanged.Broadcast(InHandle.As_CampSession(), Previous, Mapped); }
    }
}
