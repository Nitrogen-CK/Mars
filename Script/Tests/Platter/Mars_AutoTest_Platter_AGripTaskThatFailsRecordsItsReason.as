// A grip task that fails names why, and the interaction's Failed end reports it. A carrier whose gloves reach out slowly
// holds a platter and starts a Place on an empty dock nobody focuses (the dock's prompt, which re-reads the action and
// disables the target when it changes, runs only while the dock is focused, so the refusal comes from the dock's own
// drain). While the gloves reach, a second platter is docked; at the gloves' Grip the Place's task asks the dock for the
// held platter, the dock refuses it Occupied, the task fails, and the dock's interactable reports OnInteractionFailed with
// DockRefused for the carrier on the dock's target. The interaction finished Failed and none is live, the held platter is
// still in the carrier's hands, and the dock keeps the second platter. Isolated origin (161000, -70000, -30000).
class UMars_AutoTest_Platter_AGripTaskThatFailsRecordsItsReason : UMars_AutoTestRig_PlatterDock
{
    default _TimeoutSeconds = 30.0f;

    private const FVector k_Origin = FVector(161000.0, -70000.0, -30000.0);
    // A poll budget, not a ceiling: platters construct, drop and settle over seconds.
    private const int32 k_SlowPolls = 900;
    // How long the gloves take to reach out: the second platter docks well inside it.
    private const float32 k_ReachOutSeconds = 1.0f;

    private FCk_Handle_PlatterDock _Dock;
    private FCk_Handle_InteractTarget _DockTarget;
    private bool _PlaceReachRequested = false;
    // At the gloves' first Grip: whether the dock was occupied, and by what.
    private TOptional<bool> _DockOccupiedAtGrip;
    private FCk_Handle_Item _DockItemAtGrip;

    // Every OnInteractionFailed the dock's interactable reported, in parallel.
    private TArray<FCk_Handle_InteractTarget> _FailedTargets;
    private TArray<FCk_Handle> _FailedInitiators;
    private TArray<EMars_Interaction_FailReason> _FailReasons;
    // Every interaction the dock's target finished.
    private TArray<ECk_SucceededFailed> _FinishedResults;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);
        Add_SlowReachingHands();
        _Hands.BindTo_OnReachRequested(FMars_Delegate_FPHands_OnReachRequested(this, n"OnReachRequested"));
        _Hands.BindTo_OnPhaseChanged(FMars_Delegate_FPHands_OnPhaseChanged(this, n"OnPhaseChanged"));

        auto Root = Build_StationRoot(InHandle, k_Origin);
        _Dock = Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(60.0, 20.0, 50.0)), "input platter"));
        auto Interactable = _Dock.Get_Interactable();
        Interactable.BindTo_OnInteractionFailed(FMars_Delegate_Interactable_OnInteractionFailed(this, n"OnDockInteractionFailed"));

        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 0.0, 0.0))));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 150.0, 0.0))));

        Add_Step_WaitUntil("both platters are constructed", n"Check_PlattersConstructed", k_SlowPolls, 0);
        Add_Step_WaitUntil("the gloves rest, listening for a reach", n"Check_CarrierHandsRest", 0, 0);
        Add_Step("stow the first platter into the overflow", n"Step_StowCarriedPlatter");
        Add_Step_WaitUntil("the first platter has settled Held in the carrier's hands", n"Check_CarriedPlatterHeld", k_SlowPolls, 0);
        Add_Step("the unfocused empty dock offers Place; the carrier starts it", n"Step_StartPlace");
        Add_Step_WaitUntil("the Place's task has the gloves reaching with a Place reach", n"Check_PlaceReaching", 0, 0);
        Add_Step("dock the second platter while the gloves reach", n"Step_DockSecondPlatter");
        Add_Step_WaitUntil("the dock holds the second platter", n"Check_SecondPlatterDocked", 0, 0);
        Add_Step_WaitUntil("the Place's interaction ended and its failure was reported", n"Check_PlaceFailed", 0, 0);
        Add_Step_WaitUntil("the gloves rest again and the second platter landed on the dock", n"Check_SettledAfterwards", k_SlowPolls, 0);
        Add_Step("the dock refused the held platter at the Grip, the interaction failed DockRefused, the platter stays in the hands", n"Step_AssertFailedDockRefused");
        Run_Steps(InHandle);
    }

    // Add_CarrierHands with gloves that take k_ReachOutSeconds to reach out.
    private void Add_SlowReachingHands()
    {
        auto Spec = FMars_FPHands_Spec();
        Spec.Reach.Grab.OutSeconds = k_ReachOutSeconds;
        Add_CarrierHands(Spec);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Steps
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Step_StowCarriedPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Stow_Platter(0);
    }

    UFUNCTION()
    private void Check_CarriedPlatterHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held && _HeldItem.Get_CurrentItem() == _PlatterItems[0]
            && _WorldItems[0].Get_IsSettled());
    }

    UFUNCTION()
    private void Step_StartPlace(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Action = _Dock.Get_ActionFor(_Carrier);
        Assert_True(Action == EMars_PlatterDock_Action::Place, f"holding a platter, the empty dock offers Place (got [{Action :n}])");
        Assert_False(_Dock.Get_Interactable().Get_IsFocused(), "nobody focuses the dock");

        auto Interactable = _Dock.Get_Interactable();
        _DockTarget = Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use);
        _DockTarget.BindTo_OnInteractionFinished(FCk_Delegate_InteractTarget_OnInteractionFinished(this, n"OnDockTargetFinished"));
        _DockTarget.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier));
    }

    UFUNCTION()
    private void Check_PlaceReaching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_PlaceReachRequested && _Hands.Get_Phase() == EMars_FPHands_Phase::Reach);
    }

    UFUNCTION()
    private void Step_DockSecondPlatter(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_Dock, _PlatterItems[1]);
    }

    UFUNCTION()
    private void Check_SecondPlatterDocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Dock.Get_Item() == _PlatterItems[1]);
    }

    UFUNCTION()
    private void Check_PlaceFailed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_FailReasons.Num() > 0 && _FinishedResults.Num() > 0
            && (utils_state_machine::Get_CurrentStateClass(_DockTarget.As_StateMachine()) == UMars_SmState_Interactable_Interacting) == false);
    }

    UFUNCTION()
    private void Check_SettledAfterwards(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Hands.Get_Phase() == EMars_FPHands_Phase::None && _HandPhases.Contains(EMars_FPHands_Phase::Return)
            && Get_ArrivedCount(_Dock) == 1);
    }

    UFUNCTION()
    private void Step_AssertFailedDockRefused(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_DockOccupiedAtGrip.IsSet() && _DockOccupiedAtGrip.GetValue() && _DockItemAtGrip == _PlatterItems[1],
            "the second platter was on the dock at the gloves' Grip, where the Place asks the dock for the held platter");

        const auto Refusals = Get_Refusals(_Dock);
        Assert_Equals_Int(Refusals.Num(), 1, "the dock refused one Dock");
        if (Refusals.Num() == 1)
        {
            Assert_True(Refusals[0].Item == _PlatterItems[0], "the refusal names the held platter's item");
            Assert_True(Refusals[0].Refusal == EMars_PlatterDock_Refusal::Occupied, f"the dock refused it Occupied (got [{Refusals[0].Refusal :n}])");
        }

        Assert_Equals_Int(_FailReasons.Num(), 1, "the dock's interactable reported one failed interaction");
        if (_FailReasons.Num() == 1)
        {
            Assert_True(_FailReasons[0] == EMars_Interaction_FailReason::DockRefused, f"it failed DockRefused (got [{_FailReasons[0] :n}])");
            Assert_True(_FailedTargets[0] == _DockTarget, "on the dock's target");
            Assert_True(_FailedInitiators[0] == _Carrier, "for the carrier");
        }

        Assert_Equals_Int(_FinishedResults.Num(), 1, "the dock's target finished one interaction");
        if (_FinishedResults.Num() == 1)
        { Assert_True(_FinishedResults[0] == ECk_SucceededFailed::Failed, "it finished Failed"); }

        Assert_True(ck::Is_NOT_Valid(utils_interact_target::TryGet_Interaction(_DockTarget, _Carrier)), "no interaction from the carrier is live on the dock");

        Assert_True(_HeldItem.Get_CurrentItem() == _PlatterItems[0], "the carrier still holds the first platter");
        Assert_True(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex()) == _PlatterItems[0], "the first platter is still in the carrier's overflow slot");
        Assert_True(_WorldItems[0].Get_Mount() == EMars_WorldItem_Mount::Held, "the first platter is still Held");
        Assert_True(_Dock.Get_Platter() == _Platters[1], "the dock keeps the second platter");
        Assert_Equals_Int(Get_DockedCount(_Dock), 1, "the dock docked only the second platter");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnReachRequested(FCk_Handle_FPHands InHands, EMars_FPHands_ReachKind InKind)
    {
        if (InKind == EMars_FPHands_ReachKind::Place)
        { _PlaceReachRequested = true; }
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_FPHands InHands, EMars_FPHands_Phase InPrevious, EMars_FPHands_Phase InNew)
    {
        if (InNew != EMars_FPHands_Phase::Grip || _DockOccupiedAtGrip.IsSet())
        { return; }

        _DockOccupiedAtGrip = TOptional<bool>(_Dock.Get_IsOccupied());
        _DockItemAtGrip = _Dock.Get_Item();
    }

    UFUNCTION()
    private void OnDockInteractionFailed(FCk_Handle_Interactable InInteractableHandle, FMars_Interactable_Failure InFailure)
    {
        _FailedTargets.Add(InFailure.Target);
        _FailedInitiators.Add(InFailure.Initiator);
        _FailReasons.Add(InFailure.Reason);
    }

    UFUNCTION()
    private void OnDockTargetFinished(FCk_Handle_InteractTarget InTarget, FCk_Handle_Interaction InInteraction, ECk_SucceededFailed InResult)
    {
        _FinishedResults.Add(InResult);
    }
}
