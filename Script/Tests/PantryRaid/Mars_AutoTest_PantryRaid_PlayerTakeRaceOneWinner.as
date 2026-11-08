// R10 (player take / pack pickup race). The rat rummages the cheese slot under its lease. In one step the chef steps to
// 100 cm (inside interaction range, so a guard) and takes the cheese through the slot's ordinary Take into its hotbar while
// the rat's claim is enqueued: both transfers leave the same slot inventory in the same pass. Whichever the coordinator runs
// first, there is one winner and it is the chef: the cheese ends in the chef's hotbar, the pocket is empty, the rat's claim
// is a benign Contended or Cancelled, the slot reports no failed transfer, and the court's item count is unchanged.
class UMars_AutoTest_PantryRaid_PlayerTakeRaceOneWinner : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private int32 _SlotFailures = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(660000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Theft.RummageSeconds = 20.0f;
        _Spec.Theft.LeaseSeconds = 25.0f;
        Arrange_Court(InHandle, 1);

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat rummages the cheese slot under its lease", n"Check_FirstRatClaiming", k_LongPolls, 0);
        Add_Step("the chef's take and the rat's claim in one pass", n"Step_Race");
        Add_Step_WaitUntil("both transfers answered", n"Check_Answered", k_SlowPolls, 0);
        Add_Step("one winner, the chef; the item count unchanged", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnSlotTransferFailed(FCk_Handle_CargoSlot InSlot, FCk_Handle_Item InItem)
    {
        ++_SlotFailures;
    }

    UFUNCTION()
    private void Step_Race(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        const auto Target = _Rat.Get_Target();
        const auto TakeTarget = _Chefs[0].As_Hotbar().TryGet_TakeTarget(_CheeseItem);
        if (Target.IsSet() == false || ck::Is_NOT_Valid(TakeTarget))
        {
            FinishFailure("precondition: the rat holds a target and the chef's hotbar can take the cheese");
            return;
        }

        auto Slot = Get_Slot(1);
        Slot.BindTo_OnTransferFailed(FMars_Delegate_CargoSlot_OnTransferFailed(this, n"OnSlotTransferFailed"));
        Move_Chef(0, Get_PackSide(100.0));
        Slot.Request_Take(FMars_Request_CargoSlot_Take(_CheeseItem, TakeTarget));
        _Rat.Request_Claim(FMars_Request_PantryRat_Claim(Target.GetValue().Token));
    }

    UFUNCTION()
    private void Check_Answered(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const FCk_Handle Parent = _CheeseItem.Get_ParentInventory();
        FCk_Handle ChefEntity = _Chefs[0];
        auto Result = OutResult;
        Result.Set(_Rat.Get_LastClaimResult() != EMars_PantryRat_ClaimResult::None
            && utils_entity_lifetime::Get_LifetimeOwner(Parent) == ChefEntity);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Result = _Rat.Get_LastClaimResult();
        Assert_True(Result == EMars_PantryRat_ClaimResult::Contended || Result == EMars_PantryRat_ClaimResult::Cancelled,
            f"the rat lost benignly (got [{Result :n}])");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the pocket is empty");
        Assert_True(ck::Is_NOT_Valid(Get_Slot(1).Get_Item()), "slot 1 is empty: the chef took it");
        Assert_Equals_Int(_SlotFailures, 0, "the chef's take did not fail");
        Assert_True(Get_Slot(2).Get_Item() == _FoodItem, "the Mushroom is untouched");
        const FCk_Handle Parent = _CheeseItem.Get_ParentInventory();
        FCk_Handle ChefEntity = _Chefs[0];
        const auto WithChef = utils_entity_lifetime::Get_LifetimeOwner(Parent) == ChefEntity ? 1 : 0;
        Assert_Equals_Int(WithChef, 1, "the cheese is in the chef's hotbar");
        Assert_Equals_Int(Count_CourtItems() + WithChef, 2, "two ingredients in all: no copy, no loss");
    }
}

// Hand-authored so CkInventory's rollback warning is expected when the rat's claim reaches the commit first (the pocket's
// acceptance refuses it because the chef guards the pack); when the chef's take runs first the rat's transfer finds the
// source empty and nothing is logged.
class AMars_AutoTest_PantryRaid_PlayerTakeRaceOneWinner_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_PantryRaid_PlayerTakeRaceOneWinner;
    default _TimeoutSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_MonksRind))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }
}
