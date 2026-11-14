// A victim a machine cannot see is nobody there, never the victim before it: the server's devourer runs A through a
// whole run, then a victim only the server has; the client's copy shows the second run with no victim (Get_Victim
// invalid, A unmarked, the raw handle not A) and ends it Completed with an invalid victim, two runs in run order.
// Surface: Ck.Devour.Net.AS_Devour_AVictimThisMachineCannotSeeIsNobodyThere
class UCk_AutoTest_Net_Devour_AVictimThisMachineCannotSeeIsNobodyThere : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(620000.0, 0.0, 5000.0);
    private const FString k_Row = "AVictimThisMachineCannotSeeIsNobodyThere";

    private FString _InSecondRun = "";
    // Every ledger this machine read that differed from the one before it: frame, phase, serial, the raw victim.
    private FString _Arrivals = "";
    private FString _LastArrival = "";
    private float64 _SettleAt = 0.0;

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

    private void Sample_Arrival()
    {
        if (Get_IsDevourerGone())
        { return; }

        const auto Ledger = Get_DevourLedger();
        const auto Arrival = f"{Ledger.Phase :n}/{Ledger.Serial}/{Describe_RawVictim()}";
        if (Arrival == _LastArrival)
        { return; }

        _LastArrival = Arrival;
        _Arrivals += f"{Arrival}@{utils_time::Get_FrameCounter()},";
    }

    UFUNCTION()
    private void Is_EndedOnceSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Arrival();
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 1);
    }

    UFUNCTION()
    private void Is_EndedTwiceSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Arrival();
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 2);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDevourRow(Make_NetTiming(), ECk_EnableDisable::Disable);
        Spawn_ServerUnseenVictim();
        WaitUntil(n"Is_DevourCopiesFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourBegin(_VictimA);
        WaitUntil(n"Is_EndedOnceSampling", n"OnServerFirstEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFirstEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerFirstEndWaited");
    }

    UFUNCTION()
    private void OnServerFirstEndWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourBegin(_UnseenVictim);
        WaitUntil(n"Is_EndedTwiceSampling", n"OnServerSecondEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSecondEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_AreDevourRuns(2), "the server recorded two runs in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 2, "the server raised OnEnded twice");
        Assert_True(_DevourEnds[0].End == EMars_Devour_End::Completed && _DevourEnds[0].Victim == _VictimA,
            "the first run ended Completed with A");
        Assert_True(_DevourEnds[1].End == EMars_Devour_End::Completed && _DevourEnds[1].Victim == _UnseenVictim,
            "the second run ended Completed with the unseen victim");
        Hold_DevourServerRow(k_Row, f"arrivals=[{_Arrivals}]");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_EndedOnceSampling", n"OnClientFirstEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientFirstEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_DevourEnds[0].Victim == _VictimA, "the client's first run ended with its copy of A");
        WaitUntil(n"Is_SecondRunShown", n"OnClientSecondRun", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_SecondRunShown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Arrival();
        auto Result = OutResult;
        Result.Set(Get_DevourLedger().Serial >= 2 && Get_IsDevourerGone() == false && _Devourer.Get_IsActive());
    }

    UFUNCTION()
    private void OnClientSecondRun(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _SettleAt = Get_TestWorld().GetTimeSeconds() + k_SettleSeconds;
        WaitUntil(n"Is_SecondRunSettled", n"OnClientSecondRunSettled", k_SlowPolls);
    }

    // A settle that keeps recording the arrivals.
    UFUNCTION()
    private void Is_SecondRunSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Arrival();
        auto Result = OutResult;
        Result.Set(Get_TestWorld().GetTimeSeconds() >= _SettleAt);
    }

    UFUNCTION()
    private void OnClientSecondRunSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Raw = Describe_RawVictim();
        _InSecondRun = f"inSecondRun=[active {_Devourer.Get_IsActive()} running {Get_HasRunningTag()} victim {Describe_DevourHandle(Get_DevourVictim())} raw {Raw} marked {Describe_Marked()}]";
        Assert_True(_Devourer.Get_IsActive(), "the client shows the second run");
        Assert_True(Get_HasRunningTag(), "the client's devourer carries the Running tag in the second run");
        Assert_False(ck::IsValid(Get_DevourVictim()), "the client's devourer knows no victim in the second run");
        Assert_False(Get_HasVictimMarker(_VictimA), "the client's copy of A has no marker in the second run");
        Assert_True(Raw != "A", f"the client's raw victim [{Raw}] is not A");
        WaitUntil(n"Is_EndedTwiceSampling", n"OnClientSecondEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientSecondEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_DevourRow(k_Row, f"{_InSecondRun} arrivals=[{_Arrivals}]");
        Assert_True(Get_AreDevourRuns(2), "the client recorded two runs in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 2, "the client raised OnEnded twice");
        Assert_True(_DevourEnds.Num() == 2 && _DevourEnds[1].End == EMars_Devour_End::Completed, "the second run ended Completed");
        Assert_True(_DevourEnds.Num() == 2 && ck::Is_NOT_Valid(_DevourEnds[1].Victim), "the second run ended with an invalid victim");
        Assert_False(Get_HasVictimMarker(_VictimA), "the client's copy of A is unmarked");
        Finish_DevourRow();
    }
}
