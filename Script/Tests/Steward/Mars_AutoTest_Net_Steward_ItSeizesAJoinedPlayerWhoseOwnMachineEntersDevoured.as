// The steward seizes a joined player, whose own machine enters Devoured: with the production pawn possessed by the
// client's controller (prey on the server through the shared tag), the channel rising makes the server's steward seize
// the pawn's entity; the client's copy of that entity is marked by the client's copy of the steward, so the client's
// state machine enters Devoured once, its camera takes the Devour layer and the steward's View node, staged at the
// face, and it is Alive again when the run ends Completed, the layer and the marker gone, Health 100, never Downed. The
// server hands the pawn back only after the client has asserted.
// Surface: Ck.Steward.Net.AS_Steward_ItSeizesAJoinedPlayerWhoseOwnMachineEntersDevoured
class UCk_AutoTest_Net_Steward_ItSeizesAJoinedPlayerWhoseOwnMachineEntersDevoured : UMars_AutoTestRig_NetSteward
{
    default _TimeoutSeconds = 28.0f;

    private const FVector k_RowBase = FVector(642000.0, 0.0, 5000.0);
    private const FString k_Row = "ItSeizesAJoinedPlayerWhoseOwnMachineEntersDevoured";

    private FString _InDevoured = "";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_StewardRow(k_RowBase, EMars_NetDevourTest_Victims::None);

        if (Get_IsServer())
        {
            Spawn_ServerPawn();
            WaitUntil(n"Is_ServerReadyForSteward", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ClientReady", n"OnClientReady", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_InDevouredSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Get_IsPawnComposedForDevour();
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Devoured));
    }

    UFUNCTION()
    private void Is_InAliveSampling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Get_IsPawnComposedForDevour();
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Alive));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ServerReadyForSteward(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && Get_IsPawnComposedForDevour()
            && Get_IsReceiverFound());
    }

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        Spawn_ServerSteward();
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
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_StewardRow(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        WaitUntil(n"Is_ServerSeesAPlayersPawn", n"OnServerSeesPrey", k_SlowPolls);
    }

    // The server's copy of the state machine is in Alive and the pawn's entity is prey.
    UFUNCTION()
    private void Is_ServerSeesAPlayersPawn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Alive) && utils_entity_tag::Has(_Player, n"TAG_MarsSharedCombatTarget"));
    }

    UFUNCTION()
    private void OnServerSeesPrey(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerFailSource(EMars_MechanismSource_Output::Deasserted);
        WaitSampling(k_RiseDelaySeconds, n"OnServerReadyToRise");
    }

    UFUNCTION()
    private void OnServerReadyToRise(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerFailChannel(EMars_MechanismSource_Output::Asserted);
        WaitUntil(n"Is_InDevouredSampling", n"OnServerSeesDevoured", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesDevoured(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_DevourVictim() == _Player, "the server's steward names the pawn's entity as its victim");
        Assert_True(Get_IsMarkedByDevourer(_Player), "the pawn's entity is marked on the server");
        WaitUntil(n"Is_ServerEndedAndAlive", n"OnServerSeesEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerEndedAndAlive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 1 && Get_IsInState(UMars_SmState_Alive));
    }

    UFUNCTION()
    private void OnServerSeesEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_ServerHoldSeconds, n"OnServerEndWaited");
    }

    UFUNCTION()
    private void OnServerEndWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto SeizeFrame = _DevourPhases.Num() > 0 ? _DevourPhases[0].Frame : -1;
        Log_StewardRow(k_Row, f"seizeFrame={SeizeFrame}");
        Assert_Equals_Int(_DevouredEntries, 1, "the server's copy of the state machine entered Devoured once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _Player, "the run ended with the pawn's entity");
        Assert_True(Get_IsCurrent(100.0f), "the server's copy reads Health 100");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserted first: handing the pawn back makes its copy a non-owning one, which replays the history.
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // It controls the pawn locally, its state machine is in Alive, and it has found its copy of the steward.
    UFUNCTION()
    private void Is_ClientReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Steward();
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposedForDevour() && _Pawn.IsLocallyControlled() && Get_IsInState(UMars_SmState_Alive)
            && Get_AreDevourCopiesFound());
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        WaitUntil(n"Is_InDevouredSampling", n"OnClientDevoured", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientDevoured(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientDevouredSettled");
    }

    UFUNCTION()
    private void OnClientDevouredSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Devourer = utils_devour::TryGet_Devourer(_Player);
        const auto HasView = ck::IsValid(Devourer) && ck::IsValid(Devourer.Get_View());
        const auto HasPlayerAuthority = utils_net::Get_HasAuthority(_Player);
        _InDevoured = f"inDevoured=[marked {Describe_Marked()} victim {Describe_DevourHandle(Get_DevourVictim())} layer {Get_HasDevourLayer()} view {HasView} playerAuthority {HasPlayerAuthority} stewardAuthority {Get_HasDevourerAuthority()}]";
        Assert_True(Get_IsMarkedByDevourer(_Player), "the client's copy of its pawn's entity is marked by its copy of the steward");
        Assert_True(Get_DevourVictim() == _Player, "the client's steward names its pawn's entity as its victim");
        Assert_True(Get_HasDevourLayer(), "the client's camera carries the Devour layer");
        Assert_True(HasView, "the client's steward has a View node");
        Assert_False(HasPlayerAuthority, "the client has no authority over its pawn's entity");
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over the steward");
        WaitUntil(n"Is_InAliveSampling", n"OnClientAliveAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAliveAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSampling(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_StewardRow(k_Row, _InDevoured);
        Assert_Equals_Int(_DevouredEntries, 1, "the client's state machine entered Devoured exactly once");
        Assert_True(Get_AreDevourRuns(1), "the client recorded one run in run order");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the client's run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _Player, "the client's run ended with its pawn's entity");
        Assert_True(Get_WasViewStaged(), "the client's steward staged the view at its face while the pawn was held");
        Assert_False(Get_HasVictimMarker(_Player), "the client's copy of its pawn's entity has no marker");
        Assert_False(Get_HasDevourLayer(), "the client's camera no longer carries the Devour layer");
        Assert_True(Get_IsCurrent(100.0f), "the client's copy reads Health 100");
        Assert_Equals_Int(_DownedEntries, 0, "the client's state machine never entered Downed");
        Finish_DevourRow();
    }
}
