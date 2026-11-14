// The fail channel makes the steward seize the nearest prey and the run reaches the client: with A (200 from it) and B
// (600 from it) prey on the server, the channel rising makes the server's steward seize A, run it Completed and stand
// Idle with its ledger reading serial 1, Completed, itself, B never marked; the client's copy, without authority,
// raises each phase once in run order and one Completed end with its copy of A, marks A during the run and never B,
// stages the view at the face with its own handlers and its own tick, and ends Idle with nothing marked and its sink
// Powered.
// Surface: Ck.Steward.Net.AS_Steward_TheFailChannelMakesItSeizeTheNearestAndTheRunReachesTheClient
class UCk_AutoTest_Net_Steward_TheFailChannelMakesItSeizeTheNearestAndTheRunReachesTheClient : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(641000.0, 0.0, 5000.0);
    private const FString k_Row = "TheFailChannelMakesItSeizeTheNearestAndTheRunReachesTheClient";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::AAndB);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_StewardCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSteward();
        Spawn_ServerStewardVictims();
        WaitUntil(n"Is_StewardSinkEvaluated", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ComposeSeconds, n"OnServerComposed");
    }

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_MakePrey(_VictimA);
        Request_MakePrey(_VictimB);
        Spawn_ServerFailSource(EMars_MechanismSource_Output::Deasserted);
        WaitSampling(k_RiseDelaySeconds, n"OnServerReadyToRise");
    }

    UFUNCTION()
    private void OnServerReadyToRise(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFailChannel(EMars_MechanismSource_Output::Asserted);
        WaitUntil(n"Is_StewardEndedOnce", n"OnServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_DevourLedger();
        const auto SeizeFrame = _DevourPhases.Num() > 0 ? _DevourPhases[0].Frame : -1;
        Assert_True(Get_AreDevourRuns(1), "the server recorded one run in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the server raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _VictimA, "the run ended with A");
        Assert_True(_StewardNamedVictims == "A,", "the only victim the server's steward named was A");
        Assert_False(_StewardEverMarkedB, "B was never marked on the server");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the server's steward is Idle");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Idle, "the server's ledger reads Idle");
        Assert_Equals_Int(Ledger.Serial, 1, "the server's ledger reads serial 1");
        Assert_True(Ledger.LastEnd == EMars_Devour_End::Completed, "the server's ledger reads Completed");
        Assert_True(Describe_RawVictim() == "self", "the server's ledger names the steward itself while Idle");
        Hold_StewardServerRow(k_Row, f"seizeFrame={SeizeFrame}");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_StewardEndedOnce", n"OnClientEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = Get_DevourLedger();
        const auto SeizeFrame = _DevourPhases.Num() > 0 ? _DevourPhases[0].Frame : -1;
        Log_StewardRow(k_Row, f"seizeFrame={SeizeFrame} phasesAlone={Count_DevourPhasesAlone()}");
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over its copy of the steward");
        Assert_True(Get_AreDevourRuns(1), "the client recorded one run in run order, each phase once");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the client's run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _VictimA, "the client's run ended with its copy of A");
        Assert_True(_StewardEverMarkedA, "the client's copy of A was marked by its copy of the steward during the run");
        Assert_False(_StewardEverMarkedB, "the client's copy of B was never marked");
        Assert_True(Get_WasViewStaged(), "the client's steward staged the view at its face");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), "the client's steward is Idle");
        Assert_False(Get_HasRunningTag(), "the client's steward has no Running tag");
        Assert_False(Get_HasVictimMarker(_VictimA), "the client's copy of A has no marker");
        Assert_False(Get_HasVictimMarker(_VictimB), "the client's copy of B has no marker");
        Assert_True(Get_StewardPower() == EMars_MechanismSink_Power::Powered, "the client's sink reads Powered");
        Assert_True(Ledger.Phase == EMars_Devour_Phase::Idle, "the client's ledger reads Idle");
        Assert_Equals_Int(Ledger.Serial, 1, "the client's ledger reads serial 1");
        Assert_True(Ledger.LastEnd == EMars_Devour_End::Completed, "the client's ledger reads Completed");
        Finish_DevourRow();
    }
}
