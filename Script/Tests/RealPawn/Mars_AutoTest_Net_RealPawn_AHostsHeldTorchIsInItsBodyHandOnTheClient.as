// The host's own production pawn (possessed by the server's local controller) picks up a torch and turns its view
// 180 degrees; the client, standing beside it in a pawn of its own, sees the real torch in the host body's right hand:
// its copy of the hand mount rides the body (Player.BodyGrip), the torch's root is within k_GripCm of its copy's grip_r and
// within k_HandToleranceCm of HeldOffset on that mount, and the body draws no proxy beside it (HeldItemShadow empty). The
// turn is there because the first-person hand on a copy that is not its player's view hangs off a frozen view: an item
// on it would be behind the turned body. The rendered gap through the turn is measured at the end of every client frame
// by a probe (AMars_AutoTestProbe_BodyHandLag, TG_LastDemotable: after this frame's animation and the ECS's late pose
// pass), from before the client sees the turn until k_TurnSettleSeconds after: the torch's root against where the mount
// puts it on grip_r as drawn that frame stays within k_TurnGapBoundCm, the lag row's bound (the body's palm thickness,
// TPBody.Hold.PalmSurfaceOffset). The server holds the torch k_PreTurnSeconds before it turns, so the client's torch has
// settled and its probe runs before the turn reaches it.
// Surface: Ck.RealPawn.Net.AS_RealPawn_AHostsHeldTorchIsInItsBodyHandOnTheClient
class UCk_AutoTest_Net_RealPawn_AHostsHeldTorchIsInItsBodyHandOnTheClient : UMars_AutoTestRig_NetRealPawn
{
    private const FVector k_Base = FVector(920000.0, 0.0, 5000.0);
    private const FString k_Row = "AHostsHeldTorchIsInItsBodyHandOnTheClient";
    private const float64 k_HandToleranceCm = 5.0;
    private const float64 k_GripCm = 30.0;
    private const float64 k_TurnGapBoundCm = 2.8;
    private const float64 k_TurnedYaw = 180.0;
    private const float64 k_YawToleranceDeg = 5.0;
    private const float32 k_TurnSettleSeconds = 1.0f;
    private const float32 k_PreTurnSeconds = 1.5f;

    private FCk_Handle_WorldItem _Torch;
    private AMars_AutoTestProbe_BodyHandLag _Probe;
    // The client's copy's yaw when its probe started sampling; unset before.
    private TOptional<float64> _ProbeStartYaw;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_Rig(k_Base);

        if (Get_IsServer() == false)
        {
            Mark_Deadline(22.0);
            WaitUntil(n"Is_ClientHoldsTheTorchSettled", n"OnClientHoldsTheTorch", k_SlowPolls);
            return;
        }

        Spawn_ServerPawn();
        Spawn_ServerViewer();
        Spawn_ServerJoltFloor(InHandle);
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
        if (Request_ServerPossessByLocal(_Pawn) == false)
        { FinishFailure("the server's world has not exactly one local player controller"); return; }

        Spawn_ServerWorldItem(mars_items::Torch(), _Base + k_ItemFromBase);
        Mark_Deadline(16.0);
        WaitUntil(n"Is_ServerReadyToPickUp", n"OnServerReadyToPickUp", k_SlowPolls);
    }

    // The host's copy is locally controlled and idle in Locomotion, its hotbar is ready and the torch is there.
    UFUNCTION()
    private void Is_ServerReadyToPickUp(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Torch = Find_WorldItemNear(mars_items::Torch(), _Base + k_ItemFromBase, 100.0);
        const auto Hotbar = _Player.As_Hotbar(ECk_SanityCheck::UnChecked);
        const auto IsReady = _Pawn.IsLocallyControlled() && Get_IsStateActive(UMars_SmState_Loco_Idle) && ck::IsValid(Hotbar)
            && Hotbar.Get_IsReady() && ck::IsValid(_Torch);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || IsReady);
    }

    UFUNCTION()
    private void OnServerReadyToPickUp(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, f"torch={ck::IsValid(_Torch)}");
            FinishFailure("the host's pawn, its hotbar or the torch was not ready on the server");
            return;
        }

        _Torch.Request_PickUp(FMars_Request_WorldItem_PickUp(_Player));
        WaitUntil(n"Is_ServerHoldingTheTorch", n"OnServerHoldingTheTorch", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerHoldingTheTorch(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsHolding(mars_items::Torch()) && Get_IsPresentationAtHand(k_HandToleranceCm)));
    }

    UFUNCTION()
    private void OnServerHoldingTheTorch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            Log_RealPawnRow(k_Row, f"holding={Get_IsHolding(mars_items::Torch())} presentationError={Get_PresentationErrorCm() :.2}");
            FinishFailure("the host's pawn did not come to hold the torch at its hand");
            return;
        }

        WaitSeconds(k_PreTurnSeconds, n"OnServerTurn");
    }

    UFUNCTION()
    private void OnServerTurn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerTurnView(FRotator(0.0, k_TurnedYaw, 0.0));
        WaitUntil(n"Is_ServerTurned", n"OnServerTurned", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerTurned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Get_IsFacingYaw(k_TurnedYaw, k_YawToleranceDeg));
    }

    UFUNCTION()
    private void OnServerTurned(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto IsTurned = Get_IsFacingYaw(k_TurnedYaw, k_YawToleranceDeg);
        Log_RealPawnRow(k_Row, f"turned={IsTurned} yaw={_Pawn.GetActorRotation().Yaw :.1} firstPersonMount={Get_IsMountFirstPerson()}");
        Assert_True(IsTurned, f"the host's pawn turned to yaw {k_TurnedYaw} (yaw {_Pawn.GetActorRotation().Yaw :.1})");
        Assert_True(Get_IsMountFirstPerson(), "the host's own copy of the hand mount is under its gloves");
        WaitSeconds(k_ServerHoldSeconds + 3.0f, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_ClientHoldsTheTorchSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Holds = Get_IsPawnComposed() && Get_IsHolding(mars_items::Torch()) && Get_IsPresentationAtHand(k_HandToleranceCm);
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || Holds);
    }

    // The probe samples from here, before the turn reaches this client (the server waits k_PreTurnSeconds).
    UFUNCTION()
    private void OnClientHoldsTheTorch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            OnClientChecked(InTimer, InChrono, InDeltaT);
            return;
        }

        const auto HeldItem = Get_HeldItem();
        const auto HeldOffset = HeldItem.Get_CurrentItem().Get_Presentation().Mounting.HeldOffset;
        _Probe = Spawn_BodyHandProbe(HeldItem.Get_PresentationEntity().As_Transform(), HeldOffset);
        if (ck::Is_NOT_Valid(_Probe))
        { FinishFailure("the client's end-of-frame probe did not spawn"); return; }

        _Probe.Reset_Samples();
        _Probe.IsSampling = true;
        _ProbeStartYaw = TOptional<float64>(_Pawn.GetActorRotation().Yaw);
        WaitUntil(n"Is_ClientSeesTheTurn", n"OnClientSawTheTurn", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientSeesTheTurn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPastDeadline() || (Get_IsPawnComposed() && Get_IsFacingYaw(k_TurnedYaw, k_YawToleranceDeg)));
    }

    // The capsule faces the turn as soon as its rotation replicates; the mesh may still be smoothing round, so the probe
    // keeps sampling k_TurnSettleSeconds more.
    UFUNCTION()
    private void OnClientSawTheTurn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Get_IsPastDeadline())
        {
            OnClientChecked(InTimer, InChrono, InDeltaT);
            return;
        }

        WaitSeconds(k_TurnSettleSeconds, n"OnClientChecked");
    }

    UFUNCTION()
    private void OnClientChecked(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto HasProbe = ck::IsValid(_Probe);
        if (HasProbe)
        { _Probe.IsSampling = false; }

        const auto IsComposed = Get_IsPawnComposed();
        const auto IsHolding = IsComposed && Get_IsHolding(mars_items::Torch());
        const auto IsTurned = Get_IsFacingYaw(k_TurnedYaw, k_YawToleranceDeg);
        const auto FromMount = IsComposed ? Get_PresentationErrorCm() : -1.0;
        const auto FromGrip = IsComposed ? Get_PresentationFromBodyGripCm() : -1.0;
        const auto OnBody = IsComposed && Get_IsMountOnBody();
        const auto Shadow = Get_HeldItemShadowMesh();
        const auto Yaw = ck::IsValid(_Pawn) ? _Pawn.GetActorRotation().Yaw : 0.0;
        const auto StartYaw = _ProbeStartYaw.IsSet() ? _ProbeStartYaw.GetValue() : -999.0;
        const auto Samples = HasProbe ? _Probe.Samples : 0;
        const auto TurnGap = HasProbe ? _Probe.MaxGapCm : -1.0;
        const auto TurnMeanGap = HasProbe ? _Probe.Get_MeanGapCm() : -1.0;
        const auto TurnFromGrip = HasProbe ? _Probe.MaxFromSocketCm : -1.0;
        const auto TurnTravel = HasProbe ? _Probe.MaxTravelCm : -1.0;
        Log_RealPawnRow(k_Row, f"composed={IsComposed} holding={IsHolding} yaw={Yaw :.1} onBody={OnBody} fromMount={FromMount :.2} fromGrip={FromGrip :.2} probeStartYaw={StartYaw :.1} samples={Samples} turnMaxGap={TurnGap :.3} turnMeanGap={TurnMeanGap :.3} turnMaxFromGrip={TurnFromGrip :.2} turnMaxTravel={TurnTravel :.2} shadow={Describe_Mesh(Shadow)}");
        Assert_True(IsHolding, "the client's copy of the host's HeldItem holds the torch");
        Assert_True(IsTurned, f"the client's copy of the host's pawn turned to yaw {k_TurnedYaw} (yaw {Yaw :.1})");
        Assert_True(OnBody, "the client's copy of the host's hand mount rides the body's grip_r");
        Assert_True(FromMount >= 0.0 && FromMount <= k_HandToleranceCm,
            f"the torch's root sits at HeldOffset on the client's copy of the hand mount (error {FromMount :.2} cm; -1: no settled torch in the hand)");
        Assert_True(FromGrip >= 0.0 && FromGrip <= k_GripCm,
            f"the torch is in the host body's right hand on the client ({FromGrip :.2} cm from grip_r; -1: no settled torch in the hand)");
        Assert_False(ck::IsValid(Shadow), f"the client draws no proxy beside the real torch (HeldItemShadow mesh {Describe_Mesh(Shadow)})");
        Assert_True(_ProbeStartYaw.IsSet() && Math::Abs(Math::FindDeltaAngleDegrees(StartYaw, k_TurnedYaw)) > 90.0,
            f"the client's probe sampled from before the turn (yaw {StartYaw :.1} when it started)");
        Assert_True(Samples > 10, f"the probe sampled the turn ({Samples} frames)");
        Assert_True(TurnGap >= 0.0 && TurnGap <= k_TurnGapBoundCm,
            f"through the replicated turn the rendered torch trails the body hand by at most {k_TurnGapBoundCm} cm (max {TurnGap :.3}, mean {TurnMeanGap :.3}; grip_r travels up to {TurnTravel :.2} cm a frame)");
        Assert_True(TurnFromGrip >= 0.0 && TurnFromGrip <= k_GripCm,
            f"through the turn the rendered torch stays within {k_GripCm} cm of grip_r (max {TurnFromGrip :.2})");

        if (HasProbe)
        { _Probe.DestroyActor(); }

        FinishSuccess();
    }
}
