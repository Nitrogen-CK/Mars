// A copy that starts to show a run late shows it from its standing phase's start: the server seizes A in the very
// continuation in which it finds its copies and the run reaches a long Lift; the client's copy reads Lift, marks A,
// carries the Running tag, times Lift on its own clock from the phase's arrival and has recorded at most Seize and
// Lift, in run order, and no end. A lane cannot make the copy late: the log says how many phases it recorded (0: the
// run stood when the rig bound; 2: it arrived after).
// Surface: Ck.Devour.Net.AS_Devour_ALateBinderSeesTheRunFromItsPhasesStart
class UCk_AutoTest_Net_Devour_ALateBinderSeesTheRunFromItsPhasesStart : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(625000.0, 0.0, 5000.0);
    private const FString k_Row = "ALateBinderSeesTheRunFromItsPhasesStart";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_DevourRow(k_RowBase, k_DevourerOffset, EMars_NetDevourTest_Victims::A);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_DevourCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_InLift(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDevourerIn(EMars_Devour_Phase::Lift));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDevourRow(Make_LongLiftTiming(), ECk_EnableDisable::Disable);
        WaitUntil(n"Is_DevourCopiesFound", n"OnServerFound", k_SlowPolls);
    }

    // The run begins as soon as the server has its copies, before the client's can have composed.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourBegin(_VictimA);
        WaitUntil(n"Is_InLift", n"OnServerInLift", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInLift(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(4.0f, n"OnServerLiftWaited");
    }

    UFUNCTION()
    private void OnServerLiftWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Lift), "the server's devourer is still in Lift");
        Hold_DevourServerRow(k_Row, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_InLift", n"OnClientInLift", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInLift(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Seconds = Get_IsDevourerGone() ? -1.0f : _Devourer.Get_PhaseSeconds();
        const FString Path = _DevourPhases.Num() == 0 ? "stoodWhenBound" : "arrivedAfter";
        Log_DevourRow(k_Row, f"recorded={_DevourPhases.Num()} path={Path}");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Lift), "the client's devourer is still in Lift");
        Assert_True(Get_IsMarkedByDevourer(_VictimA), "the client's copy of A is marked");
        Assert_True(Get_HasRunningTag(), "the client's devourer carries the Running tag");
        Assert_True(Seconds >= 0.8f && Seconds <= 3.0f, f"the client's PhaseSeconds [{Seconds}] is between 0.8 and 3.0");
        Assert_True(_DevourPhases.Num() <= 2, "the client recorded at most two phases");
        Assert_True(Get_AreDevourPhasesInRunOrder(), "the client's recorded phases are in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 0, "the client raised no OnEnded");
        Finish_DevourRow();
    }
}
