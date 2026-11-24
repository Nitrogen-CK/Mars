// How far a held item trails the body's hand (DESIGN_10_HAND ruling C7): Player.BodyGrip samples grip_r when the ECS
// ticks, and the item's root rides it, so the item can lag the bone the body renders. The production pawn, unpossessed
// (its hand mount rides grip_r), holds a torch (a persistent item: the real item is on the body's hand; the arms raise from
// the local held-item change), is possessed by an AI controller (locally controlled but not by a player: the mount stays
// on the body) and walks forward at full input; then, standing, it strikes (a chop arc through Request_Strike). A probe ticking after the
// frame's pose is final (AMars_AutoTestProbe_BodyHandLag) reads the root's distance from where the mount puts it on grip_r
// as drawn that frame, and the socket's own travel per frame beside it. Both phases must stay within k_BoundCm: the
// body's palm thickness (TPBody.Hold.PalmSurfaceOffset, 2.8 cm), the gap the hold already leaves between grip_r and the
// item's face, so a lag under it never shows the item leaving the palm. Isolated origin (-210000, 214000, 8000).
class UMars_AutoTest_TPBody_AHeldItemKeepsUpWithTheBodyHand : UMars_AutoTestRig_PlayerHand
{
    default _Origin = FVector(-210000.0, 214000.0, 8000.0);
    default _TimeoutSeconds = 40.0f;

    private const float64 k_BoundCm = 2.8;
    private const float32 k_ArmsSettleSeconds = 0.75f;
    // Frames sampled at walking speed, after it reaches k_WalkSpeedShare of Walk.
    private const int32 k_WalkFrames = 45;
    private const float64 k_WalkSpeedShare = 0.9;

    private AMars_AutoTestProbe_BodyHandLag _Probe;
    private AAIController _Walker;
    private int32 _WalkedFrames = 0;
    private int32 _UpToSpeedPolls = 0;
    private float64 _WalkMaxGap = 0.0;
    private float64 _WalkMeanGap = 0.0;
    private float64 _WalkMaxTravel = 0.0;
    private int32 _WalkSamples = 0;
    private float64 _WalkSpeed = 0.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Spawn_PawnAndSlab(InHandle);
        Spawn_Item(mars_items::Torch());

        Add_Step_WaitUntil("the unpossessed pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the torch is composed", n"Check_ItemReady", k_SlowPolls, 0);
        Add_Step("the pawn picks the torch up", n"Step_GiveItem");
        Add_Step_WaitUntil("the pawn holds the torch on the body's hand", n"Check_ItemHeld", k_SlowPolls, 0);
        Add_Step("possess the pawn by the walker; place the probe", n"Step_HoldAndProbe");
        Add_Step_WaitSeconds("the arms take the hold", k_ArmsSettleSeconds);
        Add_Step_WaitUntil("walk up to speed", n"Check_UpToSpeed", k_SlowPolls, 0);
        Add_Step("start sampling the walk", n"Step_StartSampling");
        Add_Step_WaitUntil("walk while sampling", n"Check_WalkedEnough", k_SlowPolls, 0);
        Add_Step("record the walk; stop", n"Step_RecordWalk");
        Add_Step_WaitUntil("the pawn stands", n"Check_Standing", k_SlowPolls, 0);
        Add_Step("strike, sampling", n"Step_Strike");
        Add_Step_WaitUntil("the swing ends", n"Check_SwingOver", k_SlowPolls, 0);
        Add_Step("the torch kept up with the hand through the walk and the swing", n"Step_AssertLag");
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_HoldAndProbe(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Item = Get_HeldItem().Get_CurrentItem();
        _Walker = Cast<AAIController>(SpawnActor(AAIController, _Origin));
        if (ck::Is_NOT_Valid(_Walker))
        {
            FinishFailure("the AI controller that walks the pawn did not spawn");
            return;
        }

        _Walker.Possess(_Pawn);

        _Probe = Cast<AMars_AutoTestProbe_BodyHandLag>(SpawnActor(AMars_AutoTestProbe_BodyHandLag, _Origin));
        if (ck::Is_NOT_Valid(_Probe))
        {
            FinishFailure("the lag probe actor did not spawn");
            return;
        }

        _Probe.Pawn = _Pawn;
        _Probe.ItemRoot = _WorldItem.As_Transform();
        _Probe.HeldOffset = Item.Get_Presentation().Mounting.HeldOffset;
    }

    UFUNCTION()
    private void Check_UpToSpeed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Pawn.AddMovementInput(FVector(1.0, 0.0, 0.0), 1.0);
        _UpToSpeedPolls += 1;
        if (_UpToSpeedPolls % 240 == 0)
        { ck::Trace(f"[HandMountLag] walking up: speed={Get_Speed() :.1} mode={_Pawn.CharacterMovement.MovementMode :n} controller={_Pawn.GetController()}"); }

        auto Result = OutResult;
        Result.Set(Get_Speed() >= k_WalkSpeedShare * float64(_Pawn.Config.Movement.Speeds.Walk));
    }

    UFUNCTION()
    private void Step_StartSampling(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Pawn.AddMovementInput(FVector(1.0, 0.0, 0.0), 1.0);
        _Probe.Reset_Samples();
        _Probe.IsSampling = true;
        _WalkedFrames = 0;
    }

    UFUNCTION()
    private void Check_WalkedEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Pawn.AddMovementInput(FVector(1.0, 0.0, 0.0), 1.0);
        _WalkedFrames += 1;
        _WalkSpeed = Math::Max(_WalkSpeed, Get_Speed());
        auto Result = OutResult;
        Result.Set(_WalkedFrames >= k_WalkFrames);
    }

    UFUNCTION()
    private void Step_RecordWalk(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Probe.IsSampling = false;
        _WalkMaxGap = _Probe.MaxGapCm;
        _WalkMeanGap = _Probe.Get_MeanGapCm();
        _WalkMaxTravel = _Probe.MaxTravelCm;
        _WalkSamples = _Probe.Samples;
    }

    UFUNCTION()
    private void Check_Standing(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_Speed() < 1.0);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Probe.Reset_Samples();
        _Probe.IsSampling = true;
        _Pawn.Request_Strike(FMars_Request_HandSwing_Start(utils_hand_swing::Make_ChopArc(), 0.15f, 0.35f));
    }

    UFUNCTION()
    private void Check_SwingOver(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Swing = _Player.As_HandSwing(ECk_SanityCheck::UnChecked);
        auto Result = OutResult;
        Result.Set(ck::Is_NOT_Valid(Swing) || (_Probe.Samples > 2 && Swing.Get_IsSwinging() == false));
    }

    UFUNCTION()
    private void Step_AssertLag(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Probe.IsSampling = false;
        const auto SwingMaxGap = _Probe.MaxGapCm;
        Log(f"[HandMountLag] bound={k_BoundCm} walk: speed={_WalkSpeed :.1} samples={_WalkSamples} maxGap={_WalkMaxGap :.3} meanGap={_WalkMeanGap :.3} maxTravel={_WalkMaxTravel :.3} | swing: samples={_Probe.Samples} maxGap={SwingMaxGap :.3} meanGap={_Probe.Get_MeanGapCm() :.3} maxTravel={_Probe.MaxTravelCm :.3}");
        Assert_True(_WalkSamples >= k_WalkFrames / 2, f"the walk was sampled ({_WalkSamples} frames)");
        Assert_True(_Probe.Samples > 2, f"the swing was sampled ({_Probe.Samples} frames)");
        Assert_True(_WalkMaxGap <= k_BoundCm,
            f"walking at {_WalkSpeed :.0} cm/s the torch trails grip_r by at most {k_BoundCm} cm (max {_WalkMaxGap :.2}, mean {_WalkMeanGap :.2}; the socket travels up to {_WalkMaxTravel :.2} cm a frame)");
        Assert_True(SwingMaxGap <= k_BoundCm,
            f"mid-swing the torch trails grip_r by at most {k_BoundCm} cm (max {SwingMaxGap :.2}, mean {_Probe.Get_MeanGapCm() :.2}; the socket travels up to {_Probe.MaxTravelCm :.2} cm a frame)");

        Assert_False(_Pawn.Get_IsLocalPlayerView(), "the AI-walked pawn is not a player's own view");
        Assert_True(Get_MountParent() == Get_BodyGripTransform(), f"the mount rode the body throughout ({Describe_Mount()})");

        if (ck::IsValid(_Probe))
        { _Probe.DestroyActor(); }

        if (ck::IsValid(_Walker))
        {
            _Walker.UnPossess();
            _Walker.DestroyActor();
        }
    }

    private float64 Get_Speed()
    {
        return _Pawn.CharacterMovement.Velocity.Size2D();
    }
}

class AMars_AutoTest_TPBody_AHeldItemKeepsUpWithTheBodyHand_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TimeoutSeconds = 40.0f;
    default _TestEntityScriptClass = UMars_AutoTest_TPBody_AHeldItemKeepsUpWithTheBodyHand;
}
