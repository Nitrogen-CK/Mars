// A client in the production pawn walks (a move intent on its own copy, as its Move input writes it) and stops. Its copy
// of the player's state machine goes Loco_Idle -> Loco_Walk -> Loco_Idle inside Locomotion's sub-SM; the server's copy
// follows: it is seen in Loco_Walk while the client walks, ends in Loco_Idle, and stays in Alive's Locomotion and the
// Hands sub-SM's Hands_Rest throughout. A relayed event the server drops ("not active under root") leaves its copy behind;
// the lane counts that log line (lane-sweep --strings), this row reads the state the drop would leave.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AClientsLocomotionStatesReachTheServer
class UCk_AutoTest_Net_RealPawn_AClientsLocomotionStatesReachTheServer : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(918000.0, 0.0, 5000.0);
    private const FString k_Row = "AClientsLocomotionStatesReachTheServer";
    private const float32 k_WalkSeconds = 1.5f;

    // Server: whether its copy was seen in Loco_Walk, and every frame it left Alive's Locomotion or Hands_Rest.
    private bool _ServerSawWalk = false;
    private int32 _ServerFramesOutOfLocomotion = 0;
    private int32 _ServerFramesOutOfHandsRest = 0;
    private bool _ServerSampling = false;
    // Client: whether its own copy reached Loco_Walk.
    private bool _ClientSawWalk = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_ClientOwnerReady", n"OnClientReady", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        WaitUntil(n"Is_ServerPawnAndOwnerReady", n"OnServerComposed", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerComposed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_ComposeSeconds, n"OnServerComposeWaited");
    }

    UFUNCTION()
    private void OnServerComposeWaited(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Request_ServerPossessByRemote(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); return; }

        Mark_Deadline(20.0);
        WaitUntil(n"Is_ServerWalkedAndIdle", n"OnServerChecked", k_SlowPolls);
    }

    // Samples the server's copy every frame once it first reads Loco_Idle; done once it has walked and is idle again.
    UFUNCTION()
    private void Is_ServerWalkedAndIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto States = Get_ActiveStates(_Sm);
        const auto IsIdle = Get_HasState(States, UMars_SmState_Loco_Idle);
        if (IsIdle)
        { _ServerSampling = true; }

        if (_ServerSampling)
        {
            if (Get_HasState(States, UMars_SmState_Loco_Walk))
            { _ServerSawWalk = true; }

            if (Get_HasState(States, UMars_SmState_Locomotion) == false)
            { _ServerFramesOutOfLocomotion += 1; }

            if (Get_HasState(States, UMars_SmState_Hands_Rest) == false)
            { _ServerFramesOutOfHandsRest += 1; }
        }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (_ServerSawWalk && IsIdle));
    }

    UFUNCTION()
    private void OnServerChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto States = Describe_ActiveStates();
        Log_RealPawnRow(k_Row, f"sawWalk={_ServerSawWalk} framesOutOfLocomotion={_ServerFramesOutOfLocomotion} framesOutOfHandsRest={_ServerFramesOutOfHandsRest}");
        Assert_True(_ServerSawWalk, f"the server's copy of the client's state machine followed it into Loco_Walk (active states now [{States}])");
        Assert_True(Get_IsStateActive(UMars_SmState_Loco_Idle), f"the server's copy ends in Loco_Idle with the client (active states [{States}])");
        Assert_Equals_Int(_ServerFramesOutOfLocomotion, 0, "the server's copy never left Alive's Locomotion");
        Assert_Equals_Int(_ServerFramesOutOfHandsRest, 0, "the server's copy of the Hands sub-SM stayed in Hands_Rest");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientReady(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        // The server starts sampling at its copy's first Loco_Idle; give it time to arrive.
        WaitSeconds(k_SettleSeconds, n"OnClientWalk");
    }

    UFUNCTION()
    private void OnClientWalk(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Intents = _Player.As_InputIntents();
        Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector(1.0, 0.0, 0.0)));
        Mark_Deadline(k_WalkSeconds);
        WaitUntil(n"Is_ClientWalked", n"OnClientStop", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientWalked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_IsStateActive(UMars_SmState_Loco_Walk))
        { _ClientSawWalk = true; }

        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline());
    }

    UFUNCTION()
    private void OnClientStop(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Intents = _Player.As_InputIntents();
        Intents.Request_SetMoveDirection(FMars_Request_InputIntents_SetMoveDirection(FVector::ZeroVector));
        Mark_Deadline(5.0);
        WaitUntil(n"Is_ClientIdle", n"OnClientChecked", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientIdle(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsStateActive(UMars_SmState_Loco_Idle));
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto States = Describe_ActiveStates();
        Log_RealPawnRow(k_Row, f"sawWalk={_ClientSawWalk}");
        Assert_True(_ClientSawWalk, f"the client's own state machine entered Loco_Walk on the move intent (active states [{States}])");
        Assert_True(Get_IsStateActive(UMars_SmState_Loco_Idle), f"the client's own state machine returned to Loco_Idle (active states [{States}])");
        FinishSuccess();
    }
}
