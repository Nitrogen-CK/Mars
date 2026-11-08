// R25 (corpse drop failure). The rat steals the Mushroom (Persistent Food). The test fills the Mushroom world item's own
// one-slot holder with a Rock, so its Release can never transfer the Mushroom home. A chef's cleaver strike kills the rat:
// it issues its one release, the world item refuses it (TransferFailed: the WorldItem drain's own ensure, the inventory's
// rollback warning) and the rat goes BlockedCleanup with an actionable diagnostic. The corpse stays: the rat entity lives,
// still owns its pocket, the Mushroom is still in that pocket (no item loss), FadeAlpha stays 1 and no receipt is claimed.
// Phase 4: the corpse is watched for 4 s (past the 3 s DeathHold): it never enters CorpseFade, never fades, never hides.
class UMars_AutoTest_PantryRat_ReleaseRefusalBlocksCleanup : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(700000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _MushroomFirst = true;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);

        Add_CourtSteps();
        Add_Step_WaitUntil("the Mushroom is stolen and rides the rat", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("fill the Mushroom's own holder with a rock", n"Step_FillHolder");
        Add_Step_WaitUntil("the holder is full", n"Check_HolderFull", k_SlowPolls, 0);
        Add_Step("strike", n"Step_Strike");
        Add_Step_WaitUntil("the cleanup is blocked", n"Check_Blocked", k_SlowPolls, 0);
        Add_Step_WaitSeconds("the corpse stays past its 3 s hold", 4.0f);
        Add_Step("visible, owning its pocket, no loss, no receipt", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_FillHolder(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        auto Holder = _Food.Get_Holder();
        auto Request = FCk_Request_Inventory_AddItemByDefinition(mars_items::Rock(), 1);
        Request.Set_Policy(ECk_Inventory_AddPolicy::ForceNewItem);
        Holder.Request_AddItemByDefinition(Request, FCk_Delegate_Inventory_OnOperationResult_AddByDefinition());
    }

    UFUNCTION()
    private void Check_HolderFull(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Food.Get_Holder().Get_NumItems() == 1);
    }

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Strike_Rat(_Rat, 0);
    }

    UFUNCTION()
    private void Check_Blocked(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Rat.Get_Phase() == EMars_PantryRat_Phase::BlockedCleanup);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        FCk_Handle RatEntity = _Rat;
        Assert_True(ck::IsValid(RatEntity) && utils_world_item::Get_IsEnding(RatEntity) == false, "the corpse entity lives");
        Assert_True(_Rat.Get_Phase() == EMars_PantryRat_Phase::BlockedCleanup, "still BlockedCleanup");
        Assert_False(_Rat.Get_Death().ReleaseReceipt, "no receipt claimed");
        Assert_Equals_Int(_Rat.Get_Death().ReleaseOperationId, 1, "one release issued");
        Assert_False(_Rat.Get_Death().BlockedReason.IsEmpty(), "an actionable diagnostic");
        const FCk_Handle Parent = _FoodItem.Get_ParentInventory();
        FCk_Handle Pocket = _Rat.Get_Pocket();
        Assert_True(Parent == Pocket, "the Mushroom is still in the pocket: no item loss");
        Assert_True(_Rat.Get_FadeAlpha() == 1.0f, "no fade");
        Assert_False(_Rat.Get_IsHidden(), "never hidden");
        Assert_False(_Rat.Get_Death().DestroyRequested, "never destroyed");
        Assert_True(_Rat.Get_Clock() - _Rat.Get_Death().DiedAt >= _Rat.Get_Tuning().DeathHoldSeconds, "watched past the hold");
    }
}

// Hand-authored: the refusal is the WorldItem drain's own ensure and CkInventory's rollback warning (the full holder refuses
// the add), and the rat's diagnostic is a Warning. All three are this scenario's expected trace.
class AMars_AutoTest_PantryRat_ReleaseRefusalBlocksCleanup_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_PantryRat_ReleaseRefusalBlocksCleanup;
    default _TimeoutSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("rolled back source remove");
        Out.Add("it stays mounted");
        Out.Add("blocked its corpse cleanup");
        return Out;
    }

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_RequiredLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("blocked its corpse cleanup");
        return Out;
    }
}
