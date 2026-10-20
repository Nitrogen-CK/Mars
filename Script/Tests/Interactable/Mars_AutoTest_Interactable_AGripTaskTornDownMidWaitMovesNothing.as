// A grip task torn down while it still waits for the gloves moves nothing. A carrier whose gloves reach out slowly focuses
// a rock lying on a floor and starts its pickup; the pickup's task asks the gloves for the reach and waits for their Grip.
// While the gloves reach, a ledger claims the rock (a claim that takes it out of focus): the claim ends the interaction
// Failed and the target leaves Interacting, tearing the pickup state down, before the gloves' Grip. The gloves still close,
// come back and rest; at every frame from the claim until they rest the rock's holder kept its item and the hotbar held
// nothing, and afterwards the rock is still a World-mode item holding its item, no interaction is live and its target is
// Disabled. Isolated origin (163000, -70000, -30000).
class UMars_AutoTest_Interactable_AGripTaskTornDownMidWaitMovesNothing : UMars_AutoTestRig_Carrier
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_Origin = FVector(163000.0, -70000.0, -30000.0);
    private const FVector k_FloorTop = FVector(163200.0, -70000.0, -30000.0);
    // How long the gloves take to reach out: the claim's teardown lands well inside it.
    private const float32 k_ReachOutSeconds = 1.0f;

    private FCk_Handle _RockEntity;
    private FCk_Handle_WorldItem _Rock;
    private FCk_Handle_Item _RockItem;
    private FCk_Handle_InteractTarget _RockTarget;

    // _HandPhases.Num() when the claim was asked for.
    private int32 _PhasesAtClaim = 0;
    // At the gloves' Grip: whether the pickup's interaction was still live, and its target still Interacting.
    private TOptional<bool> _LiveAtGrip;
    private TOptional<bool> _InteractingAtGrip;
    // Frames, from the claim until the gloves rest, on which the rock's holder had lost its item or the hotbar held one.
    private int32 _FramesRockLeftItsHolder = 0;
    private int32 _FramesHotbarHeldSomething = 0;
    // Every interaction the rock's target finished.
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 2);
        Add_SlowReachingHands();
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));
        _RockEntity = Spawn_RockOnAFloor(InHandle);

        Add_Step_WaitUntil("the rock is a constructed world item holding its item", n"Check_RockConstructed", 0, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step("the carrier focuses the rock's pickup", n"Step_FocusRock");
        Add_Step_WaitUntil("the pickup's target enters Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("the carrier starts the pickup", n"Step_PickUp");
        Add_Step_WaitUntil("the pickup's task has the gloves reaching for the rock, its interaction live", n"Check_GlovesReachingForTheRock", 0, 0);
        Add_Step("a ledger claims the rock out of focus while the gloves reach", n"Step_ClaimTheRock");
        Add_Step_WaitUntil("the gloves closed, came back and rest, the rock and the hotbar watched every frame", n"Check_GlovesRestWatchingTheRock", 0, 0);
        Add_Step("the interaction ended before the Grip and nothing moved: the rock holds its item and the hotbar is empty", n"Step_AssertNothingMoved");
        Run_Steps(InHandle);
    }

    // Add_CarrierHands with gloves that take k_ReachOutSeconds to reach out.
    private void Add_SlowReachingHands()
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = k_ReachOutSeconds;
        Add_CarrierHands(Spec);
    }

    // A World-mode rock dropped onto a static floor of its own, both under the test.
    private FCk_Handle Spawn_RockOnAFloor(FCk_Handle InHandle)
    {
        auto Owner = InHandle;
        Spawn_FloorSlab(Owner, k_FloorTop);
        return utils_world_item::Request_SpawnWorld(Owner, FMars_WorldItem_WorldSpec(
            utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FRotator::ZeroRotator, k_FloorTop + FVector(0.0, 0.0, 20.0))));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Check_RockConstructed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rock = TryGet_ConstructedWorldItem(_RockEntity);
        const auto IsConstructed = ck::IsValid(Rock);
        if (IsConstructed && ck::Is_NOT_Valid(_Rock))
        {
            _Rock = Rock;
            _RockItem = _Rock.Get_HeldItem();
            auto Pickup = _Rock.Get_Pickup();
            _RockTarget = Pickup.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        }

        auto Res = OutResult;
        Res.Set(IsConstructed);
    }

    UFUNCTION()
    private void Step_FocusRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Pickup = _Rock.Get_Pickup();
        Pickup.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
        Await_FocusOf(Pickup);
    }

    // What the player's interaction glue does on a press; the pickup's own task asks the gloves for the reach.
    UFUNCTION()
    private void Step_PickUp(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _RockTarget.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnRockTargetFinished"));
        _RockTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_GlovesReachingForTheRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::Reach && _Hands.Get_IsReachTarget(_RockTarget)
            && ck::IsValid(utils_interact_target::TryGet_Interaction(_RockTarget, _Carrier)));
    }

    UFUNCTION()
    private void Step_ClaimTheRock(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _PhasesAtClaim = _HandPhases.Num();
        utils_world_item::Request_ClaimPickup(_RockEntity, EMars_Interactable_DisableReason::Ledger, ECk_EnableDisable::Disable);
    }

    UFUNCTION()
    private void Check_GlovesRestWatchingTheRock(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        if (ck::Is_NOT_Valid(_Rock) || _Rock.Get_HeldItem() != _RockItem)
        { ++_FramesRockLeftItsHolder; }

        if (Get_HotbarItemCount() > 0)
        { ++_FramesHotbarHeldSomething; }

        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None && Get_PhaseSinceClaim(EMars_FPHands_Phase::Grip)
            && Get_PhaseSinceClaim(EMars_FPHands_Phase::Return));
    }

    UFUNCTION()
    private void Step_AssertNothingMoved(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_LiveAtGrip.IsSet(), "the gloves reached their Grip");
        Assert_True(_LiveAtGrip.IsSet() && _LiveAtGrip.GetValue() == false, "the claim had ended the pickup's interaction before the gloves' Grip");
        Assert_True(_InteractingAtGrip.IsSet() && _InteractingAtGrip.GetValue() == false,
            "the rock's target had left Interacting, its pickup state torn down, before the gloves' Grip");

        Assert_Equals_Int(_FinishedResults.Num(), 1, "the pickup's interaction finished once");
        if (_FinishedResults.Num() == 1)
        { Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Failed, "it finished Failed"); }

        Assert_True(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_RockTarget, _Carrier)), "no interaction from the carrier is live on the rock");
        Assert_True(utils_state_machine::Get_CurrentStateClass(_RockTarget.As_StateMachine()) == UMars_SmState_Interactable_Disabled,
            "the claimed rock's target is Disabled");

        Assert_Equals_Int(_FramesRockLeftItsHolder, 0, "at every frame from the claim on, the rock's holder kept its item");
        Assert_Equals_Int(_FramesHotbarHeldSomething, 0, "at every frame from the claim on, the hotbar held nothing");

        if (ck::Is_NOT_Valid(_Rock))
        {
            FinishFailure("the rock's world item is gone");
            return;
        }

        Assert_True(_Rock.Get_HeldItem() == _RockItem && _Rock.Get_Holder().Get_NumItems() == 1, "the rock still holds its item");
        Assert_True(_Rock.Get_Mount() == EMars_WorldItem_Mount::World, "the rock is still in the world");
        Assert_Equals_Int(Get_HotbarItemCount(), 0, "the hotbar holds nothing");
        Assert_True(_Hands.Get_Phase() == EMars_FPHands_Phase::None, "the gloves rest");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Helpers and handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        if (InNew != EMars_FPHands_Phase::Grip || _LiveAtGrip.IsSet())
        { return; }

        _LiveAtGrip = TOptional<bool>(ck::IsValid(utils_interact_target::TryGet_Interaction(_RockTarget, _Carrier)));
        _InteractingAtGrip = TOptional<bool>(
            utils_state_machine::Get_CurrentStateClass(_RockTarget.As_StateMachine()) == UMars_SmState_Interactable_Interacting);
    }

    UFUNCTION()
    private void OnRockTargetFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }

    private bool Get_PhaseSinceClaim(EMars_FPHands_Phase InPhase) const
    {
        for (int32 Index = _PhasesAtClaim; Index < _HandPhases.Num(); ++Index)
        {
            if (_HandPhases[Index] == InPhase)
            { return true; }
        }

        return false;
    }

    private int32 Get_HotbarItemCount() const
    {
        const auto Slots = _Hotbar.Get_Slots();
        auto Count = 0;
        for (const auto& Slot : Slots)
        { Count += Slot.Get_NumItems(); }

        return Count;
    }
}
