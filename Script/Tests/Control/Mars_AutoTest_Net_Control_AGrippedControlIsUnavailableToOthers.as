// While a stand-in holds the grip on a replicated lever, the client's interactable holds the Operated claim and an
// interaction the client starts on it does not begin; once the stand-in lets go the claim is gone. Then the client grips
// the lever itself: the server's interactable holds the claim while the client holds the grip and drops it when the client
// lets go, and the client's own interactable never holds it.
// Surface: Ck.Control.Net.AS_Control_AGrippedControlIsUnavailableToOthers
class UCk_AutoTest_Net_Control_AGrippedControlIsUnavailableToOthers : UMars_AutoTestRig_NetControl
{
    private const FVector k_Location = FVector(148000.0, 0.0, 5000.0);
    // How long the stand-in holds while the client tries, and how long the client holds its own grip.
    private const float32 k_StandInHoldSeconds = 3.0f;
    private const float32 k_ClientHoldSeconds = 1.0f;
    private const int32 k_ClaimFrames = 10;

    private bool _RefusedStartBegan = false;
    private int32 _ClaimedFramesWhileOwnGrip = 0;
    private int32 _OwnGripFrames = 0;
    private float32 _OwnGripSeconds = 0.0f;
    private bool _ServerClaimedWhileClientGripped = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_LeverFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Client
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClaimedForTheStandIn", n"OnClientSawTheClaim", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClaimedForTheStandIn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsStandInFound() && _Control.Get_Gripper() == _StandIn && Get_IsClaimed());
    }

    UFUNCTION()
    private void OnClientSawTheClaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Start_ClientInteraction();
        WaitSeconds(k_SettleSeconds, n"OnClientTried");
    }

    UFUNCTION()
    private void OnClientTried(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _RefusedStartBegan = ck::IsValid(_Interaction);
        Log(f"[ControlNetTest] AGrippedControlIsUnavailableToOthers client held by the stand-in: interactionBegan {_RefusedStartBegan}, manipulating {_Control.Get_IsManipulating()}, {Get_PullText()}, {Get_GripText(_Control)}");
        WaitUntil(n"Is_FreeAndUnclaimed", n"OnClientSawTheRelease", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_FreeAndUnclaimed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_IsGripped() == false && _Control.Get_GripSerial() >= 1 && Get_IsClaimed() == false);
    }

    UFUNCTION()
    private void OnClientSawTheRelease(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Interaction = FCk_Handle_Interaction();
        Start_ClientInteraction();
        WaitUntil(n"Is_HasInteraction", n"OnClientInteracting", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientInteracting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Begin_ClientGrip();
        WaitUntil(n"Is_GrippedBySubject", n"OnClientGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnClientGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Get_FrameSeconds();
        WaitUntil(n"Is_ClientHeldItsGrip", n"OnClientHeld", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientHeldItsGrip(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _OwnGripSeconds += Get_FrameSeconds();
        _OwnGripFrames += 1;
        if (Get_IsClaimed())
        { _ClaimedFramesWhileOwnGrip += 1; }

        auto Result = OutResult;
        Result.Set(_OwnGripSeconds >= k_ClientHoldSeconds);
    }

    UFUNCTION()
    private void OnClientHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Control.Request_EndManipulation(FMars_Request_Control_EndManipulation());
        WaitUntil(n"Is_GripReleasedAfterOwnGrip", n"OnClientReleasedOwnGrip", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_GripReleasedAfterOwnGrip(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (Get_IsClaimed())
        { _ClaimedFramesWhileOwnGrip += 1; }

        auto Result = OutResult;
        Result.Set(_Control.Get_GripSerial() >= 2 && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnClientReleasedOwnGrip(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGrippedControlIsUnavailableToOthers client: refusedStartBegan {_RefusedStartBegan}, ownGripFrames {_OwnGripFrames}, claimedFramesWhileOwnGrip {_ClaimedFramesWhileOwnGrip}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_RefusedStartBegan == false, "an interaction the client started while the stand-in held the grip did not begin");
        Assert_True(_OwnGripFrames > 0 && _ClaimedFramesWhileOwnGrip == 0, f"the gripping client's own interactable never held the claim (got {_ClaimedFramesWhileOwnGrip} frames)");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        FinishSuccess();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerLever(k_Location, EMars_Control_Activation::Inactive);
        WaitUntil(n"Is_LeverAndStandInFound", n"OnServerFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_LeverAndStandInFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsControlFound(n"TAG_MarsLever") && Get_IsStandInFound());
    }

    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::Begin);
        WaitUntil(n"Is_GrippedByStandIn", n"OnServerGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_StandInHoldSeconds, n"OnServerStandInHeld");
    }

    UFUNCTION()
    private void OnServerStandInHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_StandIn, EMars_Control_GripVerb::LetGo);
        WaitUntil(n"Is_GrippedBySubject", n"OnServerClientGranted", k_SlowPolls);
    }

    UFUNCTION()
    private void OnServerClientGranted(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_ClaimFrames, n"OnServerClaimSettled");
    }

    UFUNCTION()
    private void OnServerClaimSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _ServerClaimedWhileClientGripped = Get_IsClaimed();
        WaitUntil(n"Is_ClientGripReleased", n"OnServerClientReleased", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientGripReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_GripSerial() >= 2 && _Control.Get_IsGripped() == false);
    }

    UFUNCTION()
    private void OnServerClientReleased(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitFrames(k_ClaimFrames, n"OnServerReleaseSettled");
    }

    UFUNCTION()
    private void OnServerReleaseSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Log(f"[ControlNetTest] AGrippedControlIsUnavailableToOthers server: claimedWhileClientGripped {_ServerClaimedWhileClientGripped}, claimedAfter {Get_IsClaimed()}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}");
        Assert_True(_ServerClaimedWhileClientGripped, "the server's interactable held the claim while the client held the grip");
        Assert_True(Get_IsClaimed() == false, "the claim is gone once the client let go");
        Assert_True(Get_NewEnsures() == 0, f"no ensure fired (got {Get_NewEnsures()})");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }
}
