// The victim's marker stands on both machines' copies of the victim for the run and goes at its end: while the
// server's devourer holds A in Grin, A is marked by the devourer on the server and on the client (each by its own
// copy), B is not, the client's copy names A as its victim, carries the Running tag and times Grin on its own clock;
// once the run ends neither copy of either victim carries a marker.
// Surface: Ck.Devour.Net.AS_Devour_TheMarkStandsOnBothCopiesOfTheVictimAndGoesAtTheEnd
class UCk_AutoTest_Net_Devour_TheMarkStandsOnBothCopiesOfTheVictimAndGoesAtTheEnd : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(622000.0, 0.0, 5000.0);
    private const FString k_Row = "TheMarkStandsOnBothCopiesOfTheVictimAndGoesAtTheEnd";

    private FString _InGrin = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_DevourRow(k_RowBase, k_DevourerOffset, EMars_NetDevourTest_Victims::AAndB);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_DevourCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_InGrin(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsDevourerIn(EMars_Devour_Phase::Grin));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerDevourRow(Make_LongGrinTiming(), ECk_EnableDisable::Disable);
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
        WaitUntil(n"Is_InGrin", n"OnServerInGrin", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerInGrin(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(1.5f, n"OnServerGrinWaited");
    }

    UFUNCTION()
    private void OnServerGrinWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InGrin = f"inGrin=[marked {Describe_Marked()} victim {Describe_DevourHandle(Get_DevourVictim())}]";
        Assert_True(Get_IsMarkedByDevourer(_VictimA), "A is marked by the server's devourer");
        Assert_False(Get_HasVictimMarker(_VictimB), "B has no marker on the server");
        Assert_True(Get_DevourVictim() == _VictimA, "the server's devourer names A as its victim");
        WaitUntil(n"Is_DevourEndedOnce", n"OnServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(2.0f, n"OnServerEndWaited");
    }

    UFUNCTION()
    private void OnServerEndWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_False(Get_HasVictimMarker(_VictimA), "A has no marker on the server after the run");
        Assert_False(Get_HasVictimMarker(_VictimB), "B has no marker on the server after the run");
        Hold_DevourServerRow(k_Row, _InGrin);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_InGrin", n"OnClientInGrin", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInGrin(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientGrinSettled");
    }

    UFUNCTION()
    private void OnClientGrinSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsDevourerGone())
        { FinishFailure("the client's devourer went before the run ended"); return; }

        const auto Seconds = _Devourer.Get_PhaseSeconds();
        const auto Alpha = _Devourer.Get_PhaseAlpha();
        _InGrin = f"inGrin=[marked {Describe_Marked()} victim {Describe_DevourHandle(Get_DevourVictim())} seconds {Seconds} alpha {Alpha} running {Get_HasRunningTag()}]";
        Assert_True(Get_IsMarkedByDevourer(_VictimA), "the client's copy of A is marked by its copy of the devourer");
        Assert_True(Get_DevourVictim() == _VictimA, "the client's devourer names its copy of A as its victim");
        Assert_False(Get_HasVictimMarker(_VictimB), "the client's copy of B has no marker");
        Assert_True(Get_HasRunningTag(), "the client's devourer carries the Running tag");
        Assert_True(Seconds >= 0.5f && Seconds <= 2.5f, f"the client's PhaseSeconds [{Seconds}] is between 0.5 and 2.5");
        Assert_True(Alpha >= 0.1f && Alpha <= 0.7f, f"the client's PhaseAlpha [{Alpha}] is between 0.1 and 0.7");
        WaitUntil(n"Is_DevourEndedOnce", n"OnClientEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientEndSettled");
    }

    UFUNCTION()
    private void OnClientEndSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_DevourRow(k_Row, _InGrin);
        Assert_False(Get_HasVictimMarker(_VictimA), "the client's copy of A has no marker fragment after the run");
        Assert_False(Get_HasVictimMarker(_VictimB), "the client's copy of B has no marker fragment after the run");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the client's devourer is Idle");
        Finish_DevourRow();
    }
}
