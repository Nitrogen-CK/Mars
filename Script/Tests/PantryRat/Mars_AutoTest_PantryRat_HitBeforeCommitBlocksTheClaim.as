// R17, first half (hit during transfer: death wins before the commit). The rat rummages the cheese slot under its lease. A
// chef's cleaver strike lands on its body zone; once the rat's drain has latched the lethal hit (LethalPending, still before
// any claim), its claim is enqueued. The lethal latch wins: the claim is refused by the drain (a stale request, never issued
// to the inventory). No transfer lands - the cheese is still in its slot, the pocket is empty - the rat dies once (Health
// depleted exactly once, Monster dead) and holds as an empty corpse (DeadHold) with no release issued. (The other order - a
// claim the inventory commits in the same frame, before the hit reaches the rat - is a committed theft, released once:
// Mars_AutoTest_PantryRat_HitAfterCommitReleasesOnce.)
class UMars_AutoTest_PantryRat_HitBeforeCommitBlocksTheClaim : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private int32 _Depletions = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(680000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Theft.RummageSeconds = 20.0f;
        _Spec.Theft.LeaseSeconds = 25.0f;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat rummages the cheese slot under its lease", n"Check_FirstRatClaiming", k_LongPolls, 0);
        Add_Step("strike", n"Step_Strike");
        Add_Step_WaitUntil("the lethal hit is latched", n"Check_Latched", k_SlowPolls, 0);
        Add_Step("claim after the latch", n"Step_Claim");
        Add_Step_WaitUntil("the rat holds as a corpse", n"Check_DeadHold", k_SlowPolls, 0);
        Add_Step("no transfer landed, one death, no release", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent)
    {
        ++_Depletions;
    }

    private int32 _Token = 0;
    private int32 _StaleBefore = 0;

    UFUNCTION()
    private void Step_Strike(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        const auto Target = _Rat.Get_Target();
        if (Target.IsSet() == false)
        {
            FinishFailure("precondition: the rummaging rat holds a target");
            return;
        }

        _Token = Target.GetValue().Token;
        auto Health = _Rat.Get_Monster().Get_BodyHealth();
        Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        Strike_Rat(_Rat, 0);
    }

    UFUNCTION()
    private void Check_Latched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Rat.Get_Death().LethalPending);
    }

    UFUNCTION()
    private void Step_Claim(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Rat.Get_ClaimTransfersIssued(), 0, "no claim before the latch");
        _StaleBefore = _Rat.Get_StaleResults();
        _Rat.Request_Claim(FMars_Request_PantryRat_Claim(_Token));
    }

    UFUNCTION()
    private void Check_DeadHold(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Rat.Get_Phase() == EMars_PantryRat_Phase::DeadHold);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Rat.Get_ClaimTransfersIssued(), 0, "the claim was never issued to the inventory");
        Assert_True(_Rat.Get_StaleResults() > _StaleBefore, "the drain refused the claim after the latch");
        Assert_True(Get_Slot(1).Get_Item() == _CheeseItem, "the cheese is still in slot 1");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the pocket is empty");
        Assert_False(_Rat.Get_IsLoaded(), "no loot recorded");
        Assert_Equals_Int(_Depletions, 1, "the body Health depleted exactly once");
        Assert_True(_Rat.Get_Monster().Get_IsDead(), "the monster is dead");
        Assert_Equals_Int(_Rat.Get_Death().ReleaseOperationId, 0, "no release was issued");
        Assert_Equals_Int(_Raid.Get_RatCount(), 1, "the corpse is still the raid's (Phase 4 cleans it up)");
        Assert_True(_Den.Get_SlotState(0) == EMars_RatDen_SlotState::DeadCooldown, "its den slot cools down");
    }
}

// Hand-authored: should a claim's transfer ever reach the pocket's acceptance with the latch set, CkInventory logs its
// rollback for the refused add (expected, never required).
class AMars_AutoTest_PantryRat_HitBeforeCommitBlocksTheClaim_Actor : ACk_AutoTestRunner
{
    default _TestEntityScriptClass = UMars_AutoTest_PantryRat_HitBeforeCommitBlocksTheClaim;
    default _TimeoutSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        Out.Add("(Item (Mars_ItemDef_MonksRind))] (Failed Rejected by Custom Acceptance Logic)");
        return Out;
    }
}
