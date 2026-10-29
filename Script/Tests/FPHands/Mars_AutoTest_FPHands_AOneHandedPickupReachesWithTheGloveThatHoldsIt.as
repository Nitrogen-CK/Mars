// A one-handed item lying left of centre is reached for with the right glove - the glove that will hold it
// (Get_HoldsWith) - not the glove on its side; a point target that never enters the hand (a bare interactable at the same
// spot) still goes to the glove on its side, the left. Beside the hands rig: a World-mode tallow (one-handed, no grip
// sockets) on a static floor and a transform-only interactable, both 40 cm left of the hand node. Isolated origin
// (160000, -74000, -30000).
class UMars_AutoTest_FPHands_AOneHandedPickupReachesWithTheGloveThatHoldsIt : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(160000.0, -74000.0, -30000.0);
    // Left of the hand node (its -Y), well past Focus.SideSwitchMarginCm.
    private const FVector k_LeftSpot = FVector(60.0, -40.0, 0.0);

    private FCk_Handle _TallowEntity;
    private FCk_Handle_WorldItem _Tallow;
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
        const auto FloorTop = k_Origin + k_LeftSpot;
        Add_StaticBox(Owner, FloorTop - FVector(0.0, 0.0, 1.0), FVector(80.0, 80.0, 1.0));
        _TallowEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::Tallow()), FTransform(FRotator::ZeroRotator, FloorTop + FVector(0.0, 0.0, 10.0))));
        _Point = Add_PlainInteractable(Owner, k_Origin + k_LeftSpot, _PointOwner);

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach", n"Check_RestListening", 0, 0);
        Add_Step_WaitUntil("the tallow is a world item with its reach hint", n"Check_TallowReady", 0, 0);
        Add_Step("grab the tallow lying on the left", n"Step_GrabTallow");
        Add_Step_WaitUntil("the gloves reach out", n"Check_IsReachingOut", k_SlowPolls, 0);
        Add_Step("the right glove alone reaches for the one-handed tallow", n"Step_AssertRightGloveOnly");
        Add_Step_WaitUntil("the grab ran back to rest", n"Check_RestListening", k_SlowPolls, 0);
        Add_Step("grab the bare interactable on the left", n"Step_GrabPoint");
        Add_Step_WaitUntil("the gloves reach out", n"Check_IsReachingOut", k_SlowPolls, 0);
        Add_Step("the left glove alone reaches for the point on its side", n"Step_AssertLeftGloveOnly");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_TallowReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = ck::IsValid(_TallowEntity) && _TallowEntity.Is_WorldItem()
            && ck::IsValid(_TallowEntity.As_WorldItem().Get_HeldItem()) && _TallowEntity.Has_ReachHint();
        if (IsReady && ck::Is_NOT_Valid(_Tallow))
        { _Tallow = _TallowEntity.As_WorldItem(); }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_GrabTallow(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_TallowEntity.Get_ReachHint().Handedness == EMars_ItemPresentation_Handedness::OneHanded, "the tallow is one-handed");
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_Tallow.Get_Pickup(), _TallowEntity),
            ECk_Interaction_CompletionPolicy::Instant));
    }

    UFUNCTION()
    private void Check_IsReachingOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Phase = _Hands.Get_Phase();
        auto Res = OutResult;
        Res.Set(Phase == EMars_FPHands_Phase::Reach || Phase == EMars_FPHands_Phase::Grip);
    }

    UFUNCTION()
    private void Step_AssertRightGloveOnly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Right), "the right glove, which will hold the tallow, reaches for it");
        Assert_False(_Hands.Get_IsReaching(EMars_Hand::Left), "the left glove, on the tallow's side, stays at rest");
    }

    UFUNCTION()
    private void Step_GrabPoint(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_Point, _PointOwner),
            ECk_Interaction_CompletionPolicy::Instant));
    }

    UFUNCTION()
    private void Step_AssertLeftGloveOnly(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Hands.Get_IsReaching(EMars_Hand::Left), "the left glove reaches for the point on its side");
        Assert_False(_Hands.Get_IsReaching(EMars_Hand::Right), "the right glove stays at rest for a point it will never hold");
    }
}
