// Every StartReach the gloves do not take is refused out loud, once, naming its interact target, the gesture it asked for
// and why (OnReachRefused). The hands rig's gloves, rooted at this test's origin, and eight transform-only levers (each a
// Timed control whose interactable has one target) draw each refusal in turn:
//   Superseded:  two reaches for different levers in one drain at rest: the earlier one; the gloves hold the later one.
//   Busy:        a reach for another lever while the gloves hold.
//   PushStarted: a push and a reach in one drain at rest.
//   SubjectGone: a reach for a lever destroyed (its interact target gone) before the drain.
//   Malformed:   a Grab reach that names a place spot. It ensures; the runner at the bottom expects that message.
//   Carrying:    a reach while the gloves return from grabbing a world rock with a picked-up rock riding in (a rock item
//                set as the hold mid-grab, so the carry is set; without a HeldItem it lasts the whole grab).
//   OutOfReach:  a Grab reach for a lever while the gloves hold that rock two-handed.
// Each of those seven levers is refused exactly once with its own reason and kind, and nothing else is refused: not the
// lever the gloves took, not the world rock grab. Isolated origin (160000, -70000, -30000).
class UMars_AutoTest_FPHands_ARefusedReachSaysWhy : UMars_AutoTestRig_Hands
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(160000.0, -70000.0, -30000.0);
    private const FVector k_RockFloorTop = FVector(160000.0, -69700.0, -30000.0);

    // The levers, by the refusal each one draws; k_Taken is the one the gloves hold instead of k_Superseded.
    private const int32 k_Superseded = 0;
    private const int32 k_Taken = 1;
    private const int32 k_Busy = 2;
    private const int32 k_PushStarted = 3;
    private const int32 k_SubjectGone = 4;
    private const int32 k_Malformed = 5;
    private const int32 k_Carrying = 6;
    private const int32 k_OutOfReach = 7;
    private const int32 k_LeverCount = 8;

    private TArray<FCk_Handle> _LeverRoots;
    private TArray<FCk_Handle_Interactable> _LeverInteractables;
    private TArray<FCk_Handle_InteractTarget> _LeverTargets;

    private FCk_Handle_Inventory_DataOnly _Holder;
    private FCk_Handle_Item _HeldRock;
    private FCk_Handle _WorldRockEntity;
    private FCk_Handle_WorldItem _WorldRock;

    // Every OnReachRefused, in parallel, in arrival order.
    private TArray<FCk_Handle_InteractTarget> _RefusedTargets;
    private TArray<EMars_FPHands_ReachKind> _RefusedKinds;
    private TArray<EMars_FPHands_ReachRefusal> _RefusedReasons;

    // The lever whose refusal Check_AwaitedRefused waits for.
    private int32 _Awaited = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = 0.3f;
        Spec.Reach.Grab.GripSeconds = 0.3f;
        // Long enough that a reach asked once the return is seen lands inside it.
        Spec.Reach.Grab.BackSeconds = 1.0f;
        Spec.Reach.Hold.ReleaseSeconds = 0.2f;
        auto Root = Add_Hands(InHandle, Spec);
        utils_transform::Request_SetLocation(Root, FCk_Request_Transform_SetLocation(k_Origin));
        Add_HandsSm();
        Log_Phases();
        _Hands.BindTo_OnReachRefused(FMars_Delegate_FPHands_OnReachRefused(this, n"OnReachRefused"));

        for (int32 Index = 0; Index < k_LeverCount; ++Index)
        { Build_Lever(InHandle, k_Origin + FVector(60.0, float64(Index) * 30.0 - 105.0, 0.0)); }

        Build_Rocks(InHandle);

        Add_Step_WaitUntil("the Hands SM rests, listening for a reach and a push", n"Check_RestListeningForBoth", 0, 0);
        Add_Step_WaitUntil("the rock item is seeded and the world rock is constructed", n"Check_RocksReady", 0, 0);
        Add_Step("reach for two levers in one drain", n"Step_ReachForTwo");
        Add_Step_WaitUntil("the earlier reach was refused and the gloves hold the later one's lever", n"Check_SupersededAndHolding", 0, 0);
        Add_Step("while holding, reach for another lever", n"Step_ReachWhileHolding");
        Add_Step_WaitUntil("the reach while holding was refused", n"Check_AwaitedRefused", 0, 0);
        Add_Step_WaitUntil("the Hold state listens for a lost target", n"Check_HoldListening", 0, 0);
        Add_Step("let go of the held lever", n"Step_RequestRelease");
        Add_Step_WaitUntil("the gloves rest again, listening for a reach and a push", n"Check_RestListeningForBoth", 0, 0);
        Add_Step("push and reach in one drain at rest", n"Step_PushAndReach");
        Add_Step_WaitUntil("the reach beside the push was refused and the push ran back to rest", n"Check_RefusedAndPushedBackToRest", 0, 0);
        Add_Step("destroy a lever", n"Step_DestroyLever");
        Add_Step_WaitUntil("the destroyed lever's interact target is gone", n"Check_DestroyedLeverGone", 0, 0);
        Add_Step("reach for the destroyed lever", n"Step_ReachForDestroyedLever");
        Add_Step_WaitUntil("the reach for the destroyed lever was refused", n"Check_AwaitedRefused", 0, 0);
        Add_Step("a Grab reach that names a place spot", n"Step_GrabNamingAPlaceSpot");
        Add_Step_WaitUntil("the self-contradicting reach was refused", n"Check_AwaitedRefused", 0, 0);
        Add_Step("grab the world rock", n"Step_GrabWorldRock");
        Add_Step_WaitUntil("the gloves reach for the world rock", n"Check_ReachingForWorldRock", 0, 0);
        Add_Step("the rock item lands in the gloves mid-grab", n"Step_HoldRockItem");
        Add_Step_WaitUntil("the gloves start back with the rock riding in", n"Check_ReturningWithCarry", 0, 0);
        Add_Step("reach for a lever while the rock rides in", n"Step_ReachWhileCarrying");
        Add_Step_WaitUntil("the reach during the carry was refused", n"Check_AwaitedRefused", 0, 0);
        Add_Step_WaitUntil("the gloves rest holding the rock two-handed", n"Check_RestHoldingTwoHanded", 0, 0);
        Add_Step("a Grab reach for a lever with both gloves holding", n"Step_GrabWithBothGlovesHolding");
        Add_Step_WaitUntil("the Grab with both gloves holding was refused", n"Check_AwaitedRefused", 0, 0);
        Add_Step("each lever drew its own refusal once; nothing else was refused", n"Step_AssertRefusals");
        Run_Steps(InHandle);
    }

    // A Timed lever (a long hold); a reach for it resolves as a point grip at its root.
    private void Build_Lever(FCk_Handle InHandle, FVector InLocation)
    {
        const auto Lever = Add_TimedLever(InHandle, InLocation, 5.0f);
        _LeverRoots.Add(Lever.Root);
        _LeverInteractables.Add(Lever.Interactable);
        _LeverTargets.Add(Lever.Target);
    }

    // A rock item seeded in a one-slot holder (what the gloves come to hold), and a World-mode rock lying on a static floor
    // (what they grab).
    private void Build_Rocks(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        _Holder = Add_SeededHolder(Owner, mars_items::Rock());
        Add_StaticBox(Owner, k_RockFloorTop - FVector(0.0, 0.0, 1.0), FVector(80.0, 80.0, 1.0));

        _WorldRockEntity = utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, k_RockFloorTop + FVector(0.0, 0.0, 20.0))));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_RestListeningForBoth(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRestListening());
    }

    UFUNCTION()
    private void Check_RocksReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto IsReady = _Holder.Get_NumItems() == 1 && ck::IsValid(_WorldRockEntity) && _WorldRockEntity.Is_WorldItem()
            && ck::IsValid(_WorldRockEntity.As_WorldItem().Get_HeldItem());
        if (IsReady && ck::Is_NOT_Valid(_HeldRock))
        {
            _HeldRock = _Holder.Get_SoleItem();
            _WorldRock = _WorldRockEntity.As_WorldItem();
        }

        auto Res = OutResult;
        Res.Set(IsReady);
    }

    UFUNCTION()
    private void Step_ReachForTwo(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_Superseded;
        Request_HoldReach(k_Superseded);
        Request_HoldReach(k_Taken);
    }

    UFUNCTION()
    private void Check_SupersededAndHolding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_RefusalCount(_LeverTargets[k_Superseded]) > 0 && _Hands.Get_Phase() == EMars_FPHands_Phase::Hold
            && _Hands.Get_IsReachTarget(_LeverTargets[k_Taken]));
    }

    UFUNCTION()
    private void Step_ReachWhileHolding(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_Busy;
        Request_HoldReach(k_Busy);
    }

    UFUNCTION()
    private void Check_AwaitedRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_RefusalCount(_LeverTargets[_Awaited]) > 0);
    }

    UFUNCTION()
    private void Check_HoldListening(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Has_Fragment(FMars_Fragment_FPHands_Signals)
            && _Hands.Get_Fragment(FMars_Fragment_FPHands_Signals).OnReachTargetLost._Inner.IsBound());
    }

    UFUNCTION()
    private void Step_PushAndReach(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_PushStarted;
        _Hands.Request_StartPush(FMars_Request_FPHands_StartPush(FMars_FPHands_Hold(), EMars_LaunchKind::Drop));
        Request_HoldReach(k_PushStarted);
    }

    UFUNCTION()
    private void Check_RefusedAndPushedBackToRest(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_RefusalCount(_LeverTargets[k_PushStarted]) > 0 && _Phases.Contains(EMars_FPHands_Phase::Push)
            && Get_IsRestListening());
    }

    UFUNCTION()
    private void Step_DestroyLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto LeverRoot = _LeverRoots[k_SubjectGone];
        utils_entity_lifetime::Request_DestroyEntity(LeverRoot);
    }

    UFUNCTION()
    private void Check_DestroyedLeverGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_LeverTargets[k_SubjectGone]));
    }

    UFUNCTION()
    private void Step_ReachForDestroyedLever(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_SubjectGone;
        Request_HoldReach(k_SubjectGone);
    }

    UFUNCTION()
    private void Step_GrabNamingAPlaceSpot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_Malformed;
        auto Request = FMars_Request_FPHands_StartReach(Make_LeverSubject(k_Malformed), ECk_Interaction_CompletionPolicy::Instant,
            EMars_FPHands_ReachKind::Grab);
        Request.PlaceAtWorld = TOptional<FTransform>(FTransform(FRotator::ZeroRotator, k_Origin));
        _Hands.Request_StartReach(Request);
    }

    // A reach that serves no interaction: the world rock's pickup and the rock itself, no interact target.
    UFUNCTION()
    private void Step_GrabWorldRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle WorldRockEntity = _WorldRock;
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(FMars_FPHands_ReachSubject(_WorldRock.Get_Pickup(), WorldRockEntity),
            ECk_Interaction_CompletionPolicy::Instant));
    }

    UFUNCTION()
    private void Check_ReachingForWorldRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Reach);
    }

    UFUNCTION()
    private void Step_HoldRockItem(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Hands.Request_SetHold(FMars_Request_FPHands_SetHold(_HeldRock));
    }

    UFUNCTION()
    private void Check_ReturningWithCarry(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Return && _Hands.Get_Fragment(FMars_Fragment_FPHands).Carry.IsSet());
    }

    UFUNCTION()
    private void Step_ReachWhileCarrying(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_Carrying;
        Request_HoldReach(k_Carrying);
    }

    UFUNCTION()
    private void Check_RestHoldingTwoHanded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRestListening() && _Hands.Get_Hold().Kind == EMars_FPHands_HoldKind::TwoHanded);
    }

    UFUNCTION()
    private void Step_GrabWithBothGlovesHolding(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Awaited = k_OutOfReach;
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Make_LeverSubject(k_OutOfReach), ECk_Interaction_CompletionPolicy::Instant,
            EMars_FPHands_ReachKind::Grab));
    }

    UFUNCTION()
    private void Step_AssertRefusals(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_RefusedReasons.Num(), 7, "seven reaches were refused, one per cause");

        Verify_RefusedOnce(k_Superseded, EMars_FPHands_ReachRefusal::Superseded, EMars_FPHands_ReachKind::Hold);
        Verify_RefusedOnce(k_Busy, EMars_FPHands_ReachRefusal::Busy, EMars_FPHands_ReachKind::Hold);
        Verify_RefusedOnce(k_PushStarted, EMars_FPHands_ReachRefusal::PushStarted, EMars_FPHands_ReachKind::Hold);
        Verify_RefusedOnce(k_SubjectGone, EMars_FPHands_ReachRefusal::SubjectGone, EMars_FPHands_ReachKind::Hold);
        Verify_RefusedOnce(k_Malformed, EMars_FPHands_ReachRefusal::Malformed, EMars_FPHands_ReachKind::Grab);
        Verify_RefusedOnce(k_Carrying, EMars_FPHands_ReachRefusal::Carrying, EMars_FPHands_ReachKind::Hold);
        Verify_RefusedOnce(k_OutOfReach, EMars_FPHands_ReachRefusal::OutOfReach, EMars_FPHands_ReachKind::Grab);

        Assert_Equals_Int(Get_RefusalCount(_LeverTargets[k_Taken]), 0, "the lever the gloves took was never refused");

        // The world rock grab names no interact target: a refusal of it would name none of the levers.
        for (int32 Index = 0; Index < _RefusedTargets.Num(); ++Index)
        { Assert_True(_LeverTargets.Contains(_RefusedTargets[Index]), f"refusal {Index} names one of the levers, not the world rock grab"); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Helpers and handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnReachRefused(FCk_Handle_FPHands InHands, FCk_Handle_InteractTarget InTarget, EMars_FPHands_ReachKind InKind,
                                EMars_FPHands_ReachRefusal InReason)
    {
        _RefusedTargets.Add(InTarget);
        _RefusedKinds.Add(InKind);
        _RefusedReasons.Add(InReason);
    }

    private FMars_FPHands_ReachSubject Make_LeverSubject(int32 InLever)
    {
        return FMars_FPHands_ReachSubject(_LeverTargets[InLever], _LeverInteractables[InLever], _LeverRoots[InLever]);
    }

    private void Request_HoldReach(int32 InLever)
    {
        _Hands.Request_StartReach(FMars_Request_FPHands_StartReach(Make_LeverSubject(InLever), ECk_Interaction_CompletionPolicy::Timed,
            EMars_FPHands_ReachKind::Hold));
    }

    private int32 Get_RefusalCount(FCk_Handle_InteractTarget InTarget)
    {
        auto Count = 0;
        for (const auto& Target : _RefusedTargets)
        {
            if (Target == InTarget)
            { ++Count; }
        }

        return Count;
    }

    private void Verify_RefusedOnce(int32 InLever, EMars_FPHands_ReachRefusal InReason, EMars_FPHands_ReachKind InKind)
    {
        auto Count = 0;
        for (int32 Index = 0; Index < _RefusedTargets.Num(); ++Index)
        {
            if (_RefusedTargets[Index] != _LeverTargets[InLever])
            { continue; }

            ++Count;
            Assert_True(_RefusedReasons[Index] == InReason, f"lever {InLever} was refused {InReason :n} (got {_RefusedReasons[Index] :n})");
            Assert_True(_RefusedKinds[Index] == InKind, f"lever {InLever}'s refusal names the {InKind :n} it asked for (got {_RefusedKinds[Index] :n})");
        }

        Assert_Equals_Int(Count, 1, f"lever {InLever} was refused once ({InReason :n})");
    }
}

// Hand-authored so the gloves' ensure on the self-contradicting reach (a Grab that names a place spot) is an expected error
// rather than a failure. Pinned to that ensure's own wording so an unrelated FPHands ensure still fails the test.
class AMars_AutoTest_FPHands_ARefusedReachSaysWhy_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_FPHands_ARefusedReachSaysWhy;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("reach names a place spot: only a Place reach sets something down");
        return Out;
    }
}
