// With a one-handed item in the right glove, a target made with that item (ReachHand Holding: a torch to a candle) is
// reached for by the right glove, its fingers kept closed on the item, while the free left glove stays at rest; the same
// target reached for Free goes to the left glove as before. A torch's hold offset stands its shaft along the fist's
// closing axis with its grip point at the grip bone. Beside the hands rig: a torch item seeded in a holder (set as the
// hold) and a transform-only interactable 40 cm left of the hand node. Isolated origin (160000, -82000, -30000).
class UMars_AutoTest_FPHands_AHoldingReachCarriesTheItemGloveToTheTarget : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(160000.0, -82000.0, -30000.0);
    private const FVector k_LeftSpot = FVector(60.0, -40.0, 0.0);

    private FCk_Handle_Inventory_DataOnly _Holder;
    private FCk_Handle_Item _Torch;
    private FCk_Handle _PointOwner;
    private FCk_Handle_Interactable _Point;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.3f;
        Spec.Reach.Grab.GripSeconds = 0.3f;
        Spec.Reach.Grab.BackSeconds = 0.3f;
        auto Root = Add_Hands(InHandle, Spec);
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(k_Origin));
        Add_HandsSm();

        auto Owner = InHandle;
        _Holder = Add_SeededHolder(Owner, mars_items::Torch());
        _Point = Add_PlainInteractable(Owner, k_Origin + k_LeftSpot, _PointOwner);

        Add_Step("a torch's hold offset stands its shaft along the fist", n"Step_AssertShaftOffset");
        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_RestListening", 0, 0);
        Add_Step_WaitUntil("the torch item is seeded", n"Check_TorchSeeded", 0, 0);
        Add_Step("the right glove holds the torch", n"Step_HoldTorch");
        Add_Step_WaitUntil("the hold is one-handed", n"Check_HoldingOneHanded", 0, 0);
        Add_Step("a Free reach for the point on the left", n"Step_ReachFree");
        Add_Step_WaitUntil("the gloves reach out", n"Check_IsReachingOut", k_SlowPolls, 0);
        Add_Step("the free left glove reaches; the right keeps the torch where it is", n"Step_AssertLeftGloveOnly");
        Add_Step_WaitUntil("the grab ran back to rest", n"Check_RestListening", k_SlowPolls, 0);
        Add_Step("a Holding reach for the same point", n"Step_ReachHolding");
        Add_Step_WaitUntil("the gloves reach out", n"Check_IsReachingOut", k_SlowPolls, 0);
        Add_Step("the right glove carries the torch to the point, fingers closed; the left stays", n"Step_AssertRightGloveCarries");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertShaftOffset(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto GripHeight = -8.25;
        const auto Offset = utils_fphands::Make_ShaftHeldOffset(GripHeight);
        const auto FistAxis = FMars_FPHands_RestSpec().GripRotation_R.GetForwardVector();
        const auto Shaft = Offset.GetRotation().GetUpVector();
        Assert_True(Shaft.Equals(FistAxis, 0.001), f"the shaft (+Z) runs along the fist's closing axis (grip X): shaft {Shaft}, fist {FistAxis}");
        Assert_True(FistAxis.Z > 0.8, f"the fist's closing axis points up at rest, so the torch head is up: {FistAxis}");
        const auto GripPoint = Offset.TransformPosition(FVector(0.0, 0.0, GripHeight));
        Assert_True(GripPoint.IsNearlyZero(0.01), f"the shaft's grip point lands at the grip bone: {GripPoint}");
    }

    UFUNCTION()
    private void Check_TorchSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = _Holder.Get_NumItems() == 1;
        if (IsReady && ck::Is_NOT_Valid(_Torch))
        { _Torch = _Holder.Get_SoleItem(); }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_HoldTorch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_Torch));
    }

    UFUNCTION()
    private void Check_HoldingOneHanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::OneHanded);
    }

    private FMars_Request_FPHands_StartReach Make_PointReach(EMars_FPHands_ReachHand InReachHand)
    {
        auto Request = FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_Point, _PointOwner),
            ECk_Interaction_CompletionPolicy::Instant, EMars_FPHands_ReachKind::Grab);
        Request.ReachHand = InReachHand;
        return Request;
    }

    UFUNCTION()
    private void Step_ReachFree(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(Make_PointReach(EMars_FPHands_ReachHand::Free));
    }

    UFUNCTION()
    private void Step_ReachHolding(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(Make_PointReach(EMars_FPHands_ReachHand::Holding));
    }

    UFUNCTION()
    private void Check_IsReachingOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Phase = _Hands.Get_Phase();
        auto Res = OutResult;
        Res.Set(Phase == EMars_FPHands_Phase::Reach || Phase == EMars_FPHands_Phase::Grip);
    }

    UFUNCTION()
    private void Step_AssertLeftGloveOnly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Left), "a Free reach goes to the free left glove");
        Assert_False(_Hands.Get_IsReaching(EMars_Hand::Right), "the right glove keeps the torch where it is");
    }

    UFUNCTION()
    private void Step_AssertRightGloveCarries(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Right), "a Holding reach goes to the right glove, which holds the torch");
        Assert_False(_Hands.Get_IsReaching(EMars_Hand::Left), "the free left glove stays at rest");
        Assert_False(_Hands.TryGet_ReachPose(EMars_Hand::Right).IsSet(), "the holding glove plays no reach pose: its fingers stay on the torch");

        const auto HandWorld = utils_transform::Get_EntityCurrentTransform(_Hands.Get_HandNode());
        auto Targets = FMars_FPHands_HandTargets();
        _Hands.Get_HandTargets(FMars_FPHands_TargetFrame(HandWorld, FVector::ZeroVector, FVector::ZeroVector), Targets);
        Assert_True(Targets.Right.Pose == EMars_HandGripPose::Power, f"the right glove keeps the torch's Power grip (got {Targets.Right.Pose :n})");
        Assert_True(Targets.Right.ReachAlpha > 0.0f, "the right glove is on its way to the point");
    }
}
