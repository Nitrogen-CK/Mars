// R08 (claim interrupted by guard). One rat reaches the unattended pack and rummages (ClaimTell, holding the lease). In one
// step the claim request is enqueued (the test plays the control's part) and a chef steps to 100 cm from the pack: the
// claim's transfer is issued before the chef's move lands, and the inventory's commit runs after it, so the pocket's
// drain-time acceptance reads the chef's CURRENT transform and refuses. CkInventory rolls the cheese back (its warning is
// expected below): the cheese is still in its slot, the pocket is empty, the slot never showed empty, the result is the
// benign Contended, the lease is gone and the rat is back to Observe - no ensure on the rat path.
class UMars_AutoTest_PantryRaid_GuardArrivesBeforeCommit : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private TArray<FCk_Handle_Item> _SlotChanges;
    private bool _Watching = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(652000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        // Long enough that the control's own claim never comes first: the test issues it.
        _Spec.Theft.RummageSeconds = 20.0f;
        _Spec.Theft.LeaseSeconds = 25.0f;
        Arrange_Court(InHandle, 1);

        Add_CourtSteps();
        Add_Step("watch slot 1", n"Step_Watch");
        Add_Step_WaitUntil("the rat rummages the cheese slot under its lease", n"Check_FirstRatClaiming", k_LongPolls, 0);
        Add_Step("claim and the chef's arrival in one step", n"Step_ClaimAndGuard");
        Add_Step_WaitUntil("the claim was answered", n"Check_Answered", k_SlowPolls, 0);
        Add_Step("refused at the commit: nothing moved, the rat observes", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnSlotItemChanged(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InMaybeItem)
    {
        if (_Watching)
        { _SlotChanges.Add(InMaybeItem); }
    }

    UFUNCTION()
    private void Step_Watch(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Slot = Get_Slot(1);
        Slot.BindTo_OnItemChanged(FMars_Delegate_CargoSlot_OnItemChanged(this, n"OnSlotItemChanged"));
    }

    UFUNCTION()
    private void Step_ClaimAndGuard(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        const auto Target = _Rat.Get_Target();
        if (Target.IsSet() == false)
        {
            FinishFailure("precondition: the rummaging rat holds a target");
            return;
        }

        _Watching = true;
        _Rat.Request_Claim(FMars_Request_PantryRat_Claim(Target.GetValue().Token));
        Move_Chef(0, Get_PackSide(100.0));
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Rat.Get_LastClaimResult() != EMars_PantryRat_ClaimResult::None);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Rat.Get_ClaimTransfersIssued(), 1, "the claim's transfer was issued (the commit decided it)");
        Assert_True(_Rat.Get_LastClaimResult() == EMars_PantryRat_ClaimResult::Contended, f"refused as Contended (got [{_Rat.Get_LastClaimResult() :n}])");
        Assert_True(Get_Slot(1).Get_Item() == _CheeseItem, "the cheese is still in slot 1");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the pocket is empty");
        Assert_Equals_Int(_SlotChanges.Num(), 0, "the slot never showed empty");
        Assert_False(_Raid.TryGet_LeaseOf(_Rat).IsSet(), "the lease is gone");
        Assert_True(_Rat.Get_Phase() != EMars_PantryRat_Phase::ClaimTransfer && _Rat.Get_IsLoaded() == false, "the rat is back to its empty phases");
    }
}

// Hand-authored so CkInventory's rollback warning for the refused claim is expected (never required: it is the refusal's
// own trace). No ensure is expected: the rat path never ensures.
class AMars_AutoTest_PantryRaid_GuardArrivesBeforeCommit_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_PantryRaid_GuardArrivesBeforeCommit;
    default _TimeoutSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_MonksRind))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }
}
