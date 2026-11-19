// The production pawn (the player-combat rig). Unpossessed, its copy is not locally controlled and its view follows its
// aim (UMars_Processor_PlayerViewpoint_FollowAim): turned to yaw k_TurnedYaw, the view forward turns with it. Possessed
// by the local controller, the view is its own camera's: snapped to k_OwnView and then held against a controller
// rotation forced to k_OtherAim every frame for k_HoldFrames frames, the view never leaves k_OwnView (a copy that becomes
// locally controlled after composition stops following). Isolated origin (-252000, 252000, 8000).
class UMars_AutoTest_PlayerViewpoint_OnlyACopyNotLocallyControlledFollowsItsAim : UMars_AutoTestRig_PlayerCombat
{
    default _Origin = FVector(-252000.0, 252000.0, 8000.0);

    private const float64 k_TurnedYaw = 90.0;
    private const FRotator k_OwnView = FRotator(-20.0, -45.0, 0.0);
    private const FRotator k_OtherAim = FRotator(10.0, 135.0, 0.0);
    private const float64 k_ToleranceDeg = 1.0;

    private int32 _AimFrames = 0;
    private TOptional<FVector> _LastHandOffset;
    private float64 _LastYaw = 0.0;
    private int32 _StillPolls = 0;
    private float64 _MaxOffOwnDeg = 0.0;
    private float64 _MinOffOtherDeg = 360.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        SpawnFloorAndUnpossessedPawn(InHandle);

        Add_Step_WaitUntil("the pawn's entity is linked and composed", n"Check_EntityComposed", k_SlowPolls, 0);
        Add_Step("turn the unpossessed pawn", n"Step_TurnTheActor");
        Add_Step_WaitUntil("its view turns with its aim", n"Check_ViewFollowsTheActor", k_SlowPolls, 0);
        Add_Step("possess it", n"Step_Possess");
        Add_Step_WaitUntil("the pawn's entity is Alive and standing on the floor", n"Check_PlayerReady", k_SlowPolls, 0);
        Add_Step_WaitUntil("its copy is locally controlled", n"Check_LocallyControlled", k_SlowPolls, 0);
        Add_Step("its own camera turns the view", n"Step_SnapOwnView");
        Add_Step_WaitUntil("the view is the camera's", n"Check_ViewIsOwn", k_SlowPolls, 0);
        Add_Step_WaitUntil("the view holds against another aim", n"Check_HoldsAgainstAnotherAim", k_SlowPolls, 0);
        Add_Step("the view never followed the aim", n"Step_AssertHeld");
        // A pawn torn down while it still turns, or while its hand sway still swings, trips the transform sync's ensure:
        // it first takes its view's yaw again and comes to rest.
        Add_Step_WaitUntil("the pawn faces its view again and is at rest", n"Check_AtRestFacingTheOwnView", k_SlowPolls, 0);
        Add_Step("tear down", n"Step_TearDown");
        Add_Step_WaitUntil("the player's entity is gone", n"Check_PlayerEntityGone", k_SlowPolls, 0);
        Run_Steps(InHandle);
    }

    private float64 Get_AngleDeg(FVector InA, FVector InB)
    {
        return Math::RadiansToDegrees(Math::Acos(Math::Clamp(InA.GetSafeNormal().DotProduct(InB.GetSafeNormal()), -1.0, 1.0)));
    }

    private FVector Get_ViewForward()
    {
        return utils_transform::Get_EntityCurrentTransform(_Player.As_PlayerViewpoint().Get_Viewpoint()).GetRotation().GetForwardVector();
    }

    UFUNCTION()
    private void Step_TurnTheActor(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Pawn.SetActorRotation(FRotator(0.0, k_TurnedYaw, 0.0));
    }

    UFUNCTION()
    private void Check_ViewFollowsTheActor(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AngleDeg(Get_ViewForward(), FRotator(0.0, k_TurnedYaw, 0.0).Quaternion().GetForwardVector()) <= k_ToleranceDeg);
    }

    UFUNCTION()
    private void Step_Possess(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        PossessPawn();
    }

    UFUNCTION()
    private void Check_LocallyControlled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(utils_net::Get_IsEntityLocallyControlled_ByPlayer(_Player) == ECk_Utils_Net_IsLocallyControlled_Result::IsLocallyControlled);
    }

    UFUNCTION()
    private void Step_SnapOwnView(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Camera = _Player.As_PlayerViewpoint().Get_Camera();
        utils_camera::Request_SnapBoomRotation(Camera, k_OwnView);
    }

    UFUNCTION()
    private void Check_ViewIsOwn(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_AngleDeg(Get_ViewForward(), k_OwnView.Quaternion().GetForwardVector()) <= k_ToleranceDeg);
    }

    // Every frame the controller's rotation (the pawn's base aim) is forced to k_OtherAim; the view is measured against both.
    UFUNCTION()
    private void Check_HoldsAgainstAnotherAim(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Forward = Get_ViewForward();
        _MaxOffOwnDeg = Math::Max(_MaxOffOwnDeg, Get_AngleDeg(Forward, k_OwnView.Quaternion().GetForwardVector()));
        _MinOffOtherDeg = Math::Min(_MinOffOtherDeg, Get_AngleDeg(Forward, k_OtherAim.Quaternion().GetForwardVector()));
        _Controller.SetControlRotation(k_OtherAim);
        _AimFrames += 1;

        auto Res = OutResult;
        Res.Set(_AimFrames >= k_HoldFrames);
    }

    UFUNCTION()
    private void Step_AssertHeld(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        ck::Trace(f"[PlayerViewpointTest] OnlyACopyNotLocallyControlledFollowsItsAim frames={_AimFrames} maxOffOwn={_MaxOffOwnDeg :.2} minOffOther={_MinOffOtherDeg :.2} aim={_Pawn.GetBaseAimRotation()}");
        Assert_True(_MaxOffOwnDeg <= k_ToleranceDeg,
            f"the locally controlled view stayed its camera's over {_AimFrames} frames (max {_MaxOffOwnDeg :.2} deg off; nearest the forced aim {_MinOffOtherDeg :.2} deg)");
        _Controller.SetControlRotation(k_OwnView);
    }

    // Facing the view's yaw, and neither the yaw nor the swaying Hand node's offset (Player.Hand, the side node's
    // grandparent) has moved for 10 polls in a row.
    UFUNCTION()
    private void Check_AtRestFacingTheOwnView(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto HandBob = utils_scene_node::Get_Parent(_Player.As_FPHands().Get_SideNode());
        const auto Hand = HandBob.As_SceneNode(ECk_SanityCheck::UnChecked).Get_Parent().As_SceneNode(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Hand))
        {
            Res.Set(false);
            return;
        }

        const auto Yaw = _Pawn.GetActorRotation().Yaw;
        const auto HandOffset = utils_scene_node::Get_Offset(Hand).GetLocation();
        const auto IsStill = _LastHandOffset.IsSet() && _LastHandOffset.GetValue().Equals(HandOffset, 0.01)
            && Math::Abs(Math::FindDeltaAngleDegrees(Yaw, _LastYaw)) < 0.01;
        _StillPolls = IsStill ? _StillPolls + 1 : 0;
        _LastHandOffset = TOptional<FVector>(HandOffset);
        _LastYaw = Yaw;
        Res.Set(Math::Abs(Math::FindDeltaAngleDegrees(Yaw, k_OwnView.Yaw)) <= k_ToleranceDeg && _StillPolls >= 10);
    }
}

// The rig's runner: it lists the production pawn's known spawn-time log noise.
class AMars_AutoTest_PlayerViewpoint_OnlyACopyNotLocallyControlledFollowsItsAim_Actor : AMars_AutoTestRunner_PlayerCombat
{
    default _TestEntityScriptClass = UMars_AutoTest_PlayerViewpoint_OnlyACopyNotLocallyControlledFollowsItsAim;
}
