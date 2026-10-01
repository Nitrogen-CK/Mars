// Drains Play: while the state machine is not in the Live state, requests the transition into it. Any number of Play
// requests in one drain issue ONE transition; a Play while Live is ignored.
class UMars_Processor_CampSession_HandleRequests : UCk_Processor_Script_Base_UE
{
    default _Group = n"FGroup_Gameplay_Script";
    default _MarkedDirtyBy = FMars_Fragment_CampSession_Requests;

    UFUNCTION(BlueprintOverride)
    void Configure(FCk_ScriptProcessorQuery& Query)
    {
        Query.Require(FMars_Feature_CampSession);
    }

    void ForEachEntity(FCk_Time InDeltaT, FCk_Handle& InHandle,
                       FMars_Fragment_CampSession_Requests& InRequests,
                       FMars_Fragment_CampSession& InState)
    {
        auto Self = InHandle.As_CampSession();

        TArray<FMars_Request_CampSession_Play> PlayRequests = InRequests.PlayRequests;

        // Swap-and-pop - InRequests is dead past this line.
        Self.Request_TryRemove(FMars_Fragment_CampSession_Requests);

        if (PlayRequests.Num() == 0)
        { return; }

        auto Current = utils_state_machine::Get_CurrentStateClass(InState.StateMachine);
        if (Current == UMars_SmState_Camp_Live)
        {
            ck::Trace("[CampSession] Play ignored: already Live");
            return;
        }

        InState.StateMachine.Request_Transition(UMars_SmState_Camp_Live);
    }
}
