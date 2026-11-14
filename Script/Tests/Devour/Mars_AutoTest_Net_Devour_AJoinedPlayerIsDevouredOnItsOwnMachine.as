// A joined player is devoured on its own machine: with the production pawn possessed by the client's controller, the
// server's devourer seizes the pawn's entity; the client's copy of that entity is marked by the client's copy of the
// devourer, so the client's own state machine (the owning copy decides) enters Devoured once, gives the view to the
// devourer's View node through the Devour layer, and leaves for Alive when the run ends, the layer and the marker gone;
// the server's copy follows. The controller gets its old pawn back only after the client has asserted.
// Surface: Ck.Devour.Net.AS_Devour_AJoinedPlayerIsDevouredOnItsOwnMachine
class UCk_AutoTest_Net_Devour_AJoinedPlayerIsDevouredOnItsOwnMachine : UMars_AutoTestRig_NetDevour
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_RowBase = FVector(624000.0, 0.0, 5000.0);
    private const FVector k_RowDevourerOffset = FVector(300.0, 0.0, 100.0);
    private const FString k_Row = "AJoinedPlayerIsDevouredOnItsOwnMachine";

    private FString _InDevoured = "";
    // The first frame this machine read the pawn's entity marked by its devourer; -1 before.
    private int32 _MarkedFrame = -1;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_DevourRow(k_RowBase, k_RowDevourerOffset, EMars_NetDevourTest_Victims::None);

        if (Get_IsServer())
        {
            Spawn_ServerPawn();
            WaitUntil(n"Is_ServerReadyForDevourer", n"OnServerOwnerReady", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ClientReady", n"OnClientReady", k_SlowPolls);
    }

    private void Sample_Marked()
    {
        Get_IsPawnComposedForDevour();
        if (_MarkedFrame < 0 && Get_IsMarkedByDevourer(_Player))
        { _MarkedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void Is_InDevoured(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Marked();
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Devoured));
    }

    UFUNCTION()
    private void Is_InAliveForDevour(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Marked();
        auto Result = OutResult;
        Result.Set(Get_IsInState(UMars_SmState_Alive));
    }

    // The run has ended and the state machine is back in Alive.
    UFUNCTION()
    private void Is_EndedAndAlive(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_DevourEnds.Num() >= 1 && Get_IsInState(UMars_SmState_Alive));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ServerReadyForDevourer(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && Get_IsPawnComposedForDevour());
    }

    UFUNCTION()
    private void OnServerOwnerReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        Spawn_ServerDevourRow(Make_LongGrinTiming(), ECk_EnableDisable::Enable);
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
        if (Request_ServerPossessByRemote(_Pawn) == false)
        {
            Log_DevourRow(k_Row, "remoteController=none");
            FinishFailure("the server's world has not exactly one player controller that is not local");
            return;
        }

        WaitUntil(n"Is_InAliveForDevour", n"OnServerSeesAlive", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesAlive(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_DevourBegin(_Player);
        WaitUntil(n"Is_InDevoured", n"OnServerSeesDevoured", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesDevoured(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(Get_IsMarkedByDevourer(_Player), "the pawn's entity is marked on the server");
        WaitUntil(n"Is_EndedAndAlive", n"OnServerSeesEnded", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerSeesEnded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(2.0f, n"OnServerEndWaited");
    }

    UFUNCTION()
    private void OnServerEndWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto SeizeFrame = _DevourPhases.Num() > 0 ? _DevourPhases[0].Frame : -1;
        Log_DevourRow(k_Row, f"seizeFrame={SeizeFrame} markedFrame={_MarkedFrame}");
        Assert_Equals_Int(_DevouredEntries, 1, "the server's copy of the state machine entered Devoured once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the run ended Completed");
        Assert_True(Get_IsCurrent(100.0f), "the server's copy reads Health 100");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        // The client asserted first: handing the pawn back makes its copy a non-owning one, which replays the history.
        Request_ServerReturnRemote();
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    // It controls the pawn locally, its state machine is in Alive, and it has found its copy of the devourer.
    UFUNCTION()
    private void Is_ClientReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposedForDevour() && _Pawn.IsLocallyControlled() && Get_IsInState(UMars_SmState_Alive)
            && Get_AreDevourCopiesFound());
    }

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Require_Receiver(k_Row) == false)
        { return; }

        WaitUntil(n"Is_InDevoured", n"OnClientDevoured", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientDevoured(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientDevouredSettled");
    }

    UFUNCTION()
    private void OnClientDevouredSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Devourer = utils_devour::TryGet_Devourer(_Player);
        const auto HasView = ck::IsValid(Devourer) && ck::IsValid(Devourer.Get_View());
        const auto HasPlayerAuthority = utils_net::Get_HasAuthority(_Player);
        _InDevoured = f"inDevoured=[marked {Describe_Marked()} victim {Describe_DevourHandle(Get_DevourVictim())} layer {Get_HasDevourLayer()} view {HasView} playerAuthority {HasPlayerAuthority} devourerAuthority {Get_HasDevourerAuthority()}]";
        Assert_True(Get_IsMarkedByDevourer(_Player), "the client's copy of its pawn's entity is marked by its copy of the devourer");
        Assert_True(Get_DevourVictim() == _Player, "the client's devourer names its pawn's entity as its victim");
        Assert_True(Get_HasDevourLayer(), "the client's camera carries the Devour layer");
        Assert_True(HasView, "the client's devourer has a View node");
        Assert_False(HasPlayerAuthority, "the client has no authority over its pawn's entity");
        Assert_False(Get_HasDevourerAuthority(), "the client has no authority over the devourer");
        WaitUntil(n"Is_InAliveForDevour", n"OnClientAliveAgain", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientAliveAgain(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log_DevourRow(k_Row, f"{_InDevoured} markedFrame={_MarkedFrame}");
        Assert_Equals_Int(_DevouredEntries, 1, "the client's state machine entered Devoured exactly once");
        Assert_False(Get_HasVictimMarker(_Player), "the client's copy of its pawn's entity has no marker");
        Assert_False(Get_HasDevourLayer(), "the client's camera no longer carries the Devour layer");
        Assert_Equals_Int(_DevourEnds.Num(), 1, "the client raised OnEnded once");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].End == EMars_Devour_End::Completed, "the client's run ended Completed");
        Assert_True(_DevourEnds.Num() == 1 && _DevourEnds[0].Victim == _Player, "the client's run ended with its pawn's entity");
        Assert_True(Get_IsCurrent(100.0f), "the client's copy reads Health 100");
        Assert_Equals_Int(_DownedEntries, 0, "the client's state machine never entered Downed");
        Finish_DevourRow();
    }
}
