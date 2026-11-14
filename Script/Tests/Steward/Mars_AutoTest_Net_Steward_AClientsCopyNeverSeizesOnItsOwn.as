// A client's copy never seizes on its own: the client makes its own copy of A prey while the server's copy of A is not,
// and the channel rising seizes nothing on either machine (Idle, serial 0, A unmarked, no signal, no pending request on
// the client). Then the channel falls, an unseen prey (a victim only the server has) is tagged and the channel rises
// again: the server's steward runs the unseen prey through a whole run, and the client's copy shows it with nobody (one
// run in run order, one Completed end with an invalid victim), never naming a victim, never marking A and never reading
// A in its ledger.
// Surface: Ck.Steward.Net.AS_Steward_AClientsCopyNeverSeizesOnItsOwn
class UCk_AutoTest_Net_Steward_AClientsCopyNeverSeizesOnItsOwn : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(645000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsCopyNeverSeizesOnItsOwn";

    private FString _InQuietRise = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::A);

        if (Get_IsServer())
        {
            WaitUntil(n"Is_ServerSpawnOwnerReady", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_StewardCopiesFound", n"OnClientFound", k_SlowPolls);
    }

    // Nothing recorded and nothing begun, A unmarked.
    private void Assert_NothingSeized(FString InMachine)
    {
        Assert_True(Get_StewardPower() == EMars_MechanismSink_Power::Powered, f"the {InMachine}'s sink reads Powered");
        Assert_True(Get_IsDevourerIn(EMars_Devour_Phase::Idle), f"the {InMachine}'s steward is Idle");
        Assert_Equals_Int(Get_DevourLedger().Serial, 0, f"the {InMachine}'s ledger reads serial 0");
        Assert_False(Get_HasVictimMarker(_VictimA), f"the {InMachine}'s copy of A has no marker");
        Assert_Equals_Int(_DevourPhases.Num(), 0, f"the {InMachine} recorded no phase");
        Assert_Equals_Int(_DevourEnds.Num(), 0, f"the {InMachine} recorded no end");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerSteward();
        Spawn_ServerStewardVictims();
        Spawn_ServerUnseenPrey();
        Spawn_ServerFailSource(EMars_MechanismSource_Output::Deasserted);
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
        Request_ServerFailChannel(EMars_MechanismSource_Output::Asserted);
        WaitSampling(k_ServerQuietSeconds, n"OnServerQuiet");
    }

    UFUNCTION()
    private void OnServerQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_NothingSeized("server");
        Request_ServerFailChannel(EMars_MechanismSource_Output::Deasserted);
        WaitSampling(k_RiseDelaySeconds, n"OnServerFallen");
    }

    UFUNCTION()
    private void OnServerFallen(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_MakePrey(_UnseenVictim);
        Request_ServerFailChannel(EMars_MechanismSource_Output::Asserted);
        WaitUntil(n"Is_StewardEndedOnce", n"OnServerEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_AreDevourRuns(1), "the server recorded one run in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the server raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _UnseenVictim, "the run ended with the unseen prey");
        Assert_False(_StewardEverMarkedA, "A was never marked on the server");
        Hold_StewardServerRow(k_Row, "");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // Prey on this machine only: the server's copy of A carries no tag.
        Request_MakePrey(_VictimA);
        WaitUntil(n"Is_StewardSinkPowered", n"OnClientPowered", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientPowered(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ClientQuietSeconds, n"OnClientQuiet");
    }

    UFUNCTION()
    private void OnClientQuiet(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _InQuietRise = f"quietRise=[phase {_Devourer.Get_Phase() :n} serial {Get_DevourLedger().Serial} requests {Get_HasDevourRequests()} phases {_DevourPhases.Num()} ends {_DevourEnds.Num()}]";
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over its copy of the steward");
        Assert_NothingSeized("client");
        Assert_False(Get_HasDevourRequests(), "the client's copy has no pending Devour request");
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
        Log_StewardRow(k_Row, _InQuietRise);
        Assert_True(Get_AreDevourRuns(1), "the client recorded one run in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the client's run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && ck::Is_NOT_Valid(_DevourEnds[0].Victim), "the client's run ended with an invalid victim");
        Assert_False(_StewardEverMarkedA, "the client's copy of A was never marked");
        Assert_False(_StewardEverNamedVictim, "the client's steward never named a victim");
        Assert_False(_StewardRawVictimEverA, "the client's ledger never named A");
        Finish_DevourRow();
    }
}
