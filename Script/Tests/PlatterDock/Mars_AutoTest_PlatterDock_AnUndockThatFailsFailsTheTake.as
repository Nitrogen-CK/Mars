// A Take whose transfer the hands' inventory refuses ends; it does not wait for an undock that will never come. Two docks
// on one root each hold a platter; a carrier without gloves (one overflow slot for a platter) focuses both and uses both
// Takes in one frame, so each Take finds the overflow empty at its grip and asks its dock to undock into it. Only one
// platter fits: one dock undocks (OnUndocked) and the carrier holds that platter, while the other's transfer is refused by
// the full overflow, so that dock broadcasts OnUndockRefused for its item and keeps its platter, and its Take fails on it:
// that dock's interactable reports UndockRefused and its interaction finishes Failed, while the other's finishes Succeeded.
// Both docks' interactions end: their targets are Focused again.
class UMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake : UMars_AutoTestRig_PlatterDock
{
    private const FVector k_Origin = FVector(38200.0, -21000.0, -30000.0);
    // A poll budget, not a ceiling: platters construct, drop and settle over seconds.
    private const int32 k_SlowPolls = 900;

    private TArray<FCk_Handle_PlatterDock> _Docks;
    private TArray<FCk_Handle_InteractTarget> _Targets;
    private UMars_AutoTestHelper_InteractionOutcomes _Outcomes;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Add_CarrierBody(InHandle, k_Origin);
        Add_Hotbar(_Carrier, 1);
        _HeldItem = utils_held_item::Add(_Carrier);

        auto Root = Build_StationRoot(InHandle, k_Origin);
        _Docks.Add(Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(60.0, 40.0, 50.0)), "input platter")));
        _Docks.Add(Build_Dock(Root, Make_DockSpec(Make_Policy(TOptional<FGameplayTag>(), false),
            FTransform(FRotator::ZeroRotator, FVector(60.0, -40.0, 50.0)), "finished tray")));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, 60.0, 0.0))));
        Spawn_Platter(InHandle, FMars_Platter_SpawnSpec(FTransform(FRotator::ZeroRotator, k_Origin + FVector(200.0, -60.0, 0.0))));

        Add_Step_WaitUntil("both platters are constructed", n"Check_PlattersConstructed", k_SlowPolls, 0);
        Add_Step("dock one platter on each dock", n"Step_DockBoth");
        Add_Step_WaitUntil("both platters have landed on their docks", n"Check_BothArrived", k_SlowPolls, 0);
        Add_Step("the carrier focuses both docks", n"Step_FocusBoth");
        Add_Step_WaitUntil("the docks' targets enter Focused", n"Check_AwaitedFocus", 0, 0);
        Add_Step("both docks offer Take; use both in one frame", n"Step_TakeBoth");
        Add_Step_WaitUntil("one dock undocked, the other refused, and both interactions ended", n"Check_OneTakenOneRefused", 0, 0);
        Add_Step_WaitFrames("a late undock would have drained by now", 5);
        Add_Step("the refused Take failed; its dock keeps its platter", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_DockBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Dock(_Docks[0], _PlatterItems[0]);
        Dock(_Docks[1], _PlatterItems[1]);
    }

    UFUNCTION()
    private void Check_BothArrived(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_ArrivedCount(_Docks[0]) == 1 && Get_ArrivedCount(_Docks[1]) == 1);
    }

    UFUNCTION()
    private void Step_FocusBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Outcomes = Cast<UMars_AutoTestHelper_InteractionOutcomes>(NewObject(this, UMars_AutoTestHelper_InteractionOutcomes));
        for (const auto& Dock : _Docks)
        {
            auto Interactable = Dock.Get_Interactable();
            Interactable.Request_Focus(FMars_Request_Interactable_Focus(_Carrier));
            Await_FocusOf(Interactable);
            _Targets.Add(Interactable.Get_InteractTarget(GameplayTags::InteractionChannel_Mars_Use));
            _Outcomes.Watch_Interactable(Interactable);
            _Outcomes.Watch_Target(_Targets.Last());
        }
    }

    // What the player's interaction glue does on a press, for both docks at once: no gloves, so each Take acts at once.
    UFUNCTION()
    private void Step_TakeBoth(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        for (int32 Index = 0; Index < _Docks.Num(); ++Index)
        {
            const auto Action = _Docks[Index].Get_ActionFor(_Carrier);
            Assert_True(Action == EMars_PlatterDock_Action::Take, f"dock {Index} offers Take (got [{Action :n}])");
            Assert_True(Get_IsFocusedState(_Targets[Index]), f"dock {Index}'s target is Focused");
        }

        for (auto& Target : _Targets)
        { Target.Request_StartInteraction(FCk_Try_InteractTarget_StartInteraction(_Carrier, _Carrier)); }
    }

    UFUNCTION()
    private void Check_OneTakenOneRefused(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Undocked = Get_UndockedCount(_Docks[0]) + Get_UndockedCount(_Docks[1]);
        auto Res = OutResult;
        Res.Set(Undocked == 1 && _UndockRefused.Num() == 1 && Get_IsFocusedState(_Targets[0]) && Get_IsFocusedState(_Targets[1])
            && _Outcomes.Get_FinishedCount(_Targets[0]) == 1 && _Outcomes.Get_FinishedCount(_Targets[1]) == 1);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(Get_UndockedCount(_Docks[0]) + Get_UndockedCount(_Docks[1]), 1, "one dock undocked");
        Assert_Equals_Int(_UndockRefused.Num(), 1, "one undock was refused");
        if (_UndockRefused.Num() != 1)
        { return; }

        const auto Refused = _UndockRefused[0];
        const auto RefusedIndex = Refused.Dock == _Docks[0] ? 0 : 1;
        const auto TakenIndex = 1 - RefusedIndex;
        Assert_True(Refused.Dock == _Docks[RefusedIndex], "the refusal names one of the docks");
        Assert_Equals_Int(Get_UndockedCount(_Docks[RefusedIndex]), 0, "the refused dock never undocked");
        Assert_True(Refused.Item == _PlatterItems[RefusedIndex], "the refusal names that dock's platter item");
        Assert_True(Refused.Refusal == EMars_PlatterDock_Refusal::TransferFailed, f"the transfer failed (got [{Refused.Refusal :n}])");

        Assert_True(_Docks[RefusedIndex].Get_IsOccupied() && _Docks[RefusedIndex].Get_Item() == _PlatterItems[RefusedIndex],
            "the refused dock keeps its platter");
        Assert_False(_Docks[TakenIndex].Get_IsOccupied(), "the other dock is empty");
        Assert_True(_Hotbar.Get_ItemAt(_Hotbar.Get_OverflowIndex()) == _PlatterItems[TakenIndex], "the carrier's overflow holds the taken platter");

        Assert_True(Get_IsFocusedState(_Targets[0]) && Get_IsFocusedState(_Targets[1]), "both interactions ended: both targets are Focused");

        const auto RefusedResult = _Outcomes.TryGet_Result(_Targets[RefusedIndex]);
        Assert_True(RefusedResult.IsSet() && RefusedResult.GetValue() == ECk_SucceededFailed::Failed, "the refused dock's Take finished Failed");
        const auto TakenResult = _Outcomes.TryGet_Result(_Targets[TakenIndex]);
        Assert_True(TakenResult.IsSet() && TakenResult.GetValue() == ECk_SucceededFailed::Succeeded, "the other dock's Take finished Succeeded");

        const auto Reasons = _Outcomes.Get_FailReasons(_Targets[RefusedIndex]);
        Assert_Equals_Int(Reasons.Num(), 1, "the refused dock reported one failure");
        if (Reasons.Num() == 1)
        { Assert_True(Reasons[0] == EMars_Interaction_FailReason::UndockRefused, f"it failed UndockRefused (got [{Reasons[0] :n}])"); }

        Assert_Equals_Int(_Outcomes.Get_FailureCount(), 1, "nothing else failed");
    }

    private bool Get_IsFocusedState(const FCk_Handle_InteractTarget& InTarget) const
    {
        return utils_state_machine::Get_CurrentStateClass(InTarget.As_StateMachine()) == UMars_SmState_Interactable_Focused;
    }
}

// Hand-authored so the dock's ensure on the refused undock transfer and CkInventory's rollback Warning for it are expected
// rather than failures (the automation controller elevates Warnings to test errors). Pinned to the platter item and the
// transfer's result so an unrelated refusal still fails the test.
class AMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake_Actor : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 20.0f;
    default _TestEntityScriptClass = UMars_AutoTest_PlatterDock_AnUndockThatFailsFailsTheTake;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("failed with [Failed_NoSpaceInTarget]");
        Out.Add("(Mars_ItemDef_Platter))] (Failed No Space Available); rolled back source remove");
        return Out;
    }
}
