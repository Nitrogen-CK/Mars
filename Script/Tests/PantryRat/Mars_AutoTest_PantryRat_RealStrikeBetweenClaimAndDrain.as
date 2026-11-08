// R16 (c) / R17 (hit during transfer) through the real strike. The rat rummages the cheese slot; on the first frame its
// Claim request is queued and not yet drained (or, if the drain beat this watch in that frame, the first frame the claim is
// in flight: ClaimTransfer / CarryMountPending), the chef's real strike (the cleaver's Strike trait through the dealer's
// StrikeSweep) lands on its hurtbox. Whichever order the frame resolves - the lethal latch refusing the claim, or the
// inventory committing it before the hit reaches the rat - death wins exactly once: one Health depletion, one Dying, at
// most one release, the cheese never duplicated or lost (in its slot, or outside the pocket after the one release, never
// both), and a committed claim's late receipt is released once. The observed order is logged ([PantryRatTest] ordering).
class UMars_AutoTest_PantryRat_RealStrikeBetweenClaimAndDrain : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private bool _Struck = false;
    private bool _SweepHit = false;
    private FString _Ordering;
    private int32 _Depletions = 0;
    private int32 _DyingEntries = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(716000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);
        Make_ChefDealer(0, 1.0f);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the strike lands as the claim goes in", n"Check_Struck", k_LongPolls, 0);
        Add_Step_WaitUntil("the corpse holds", n"Check_DeadHold", k_SlowPolls, 0);
        Add_Step("death won once; the cheese is in exactly one place", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Struck)
        { return; }

        auto Rat = Get_FirstRat();
        if (ck::Is_NOT_Valid(Rat))
        { return; }

        const auto Phase = Rat.Get_Phase();
        const auto ClaimQueued = Phase == EMars_PantryRat_Phase::ClaimTell && Rat.Has_Fragment(FMars_Fragment_PantryRat_Requests)
            && Rat.Get_Fragment(FMars_Fragment_PantryRat_Requests).ClaimRequests.Num() > 0;
        const auto ClaimInFlight = Phase == EMars_PantryRat_Phase::ClaimTransfer || Phase == EMars_PantryRat_Phase::CarryMountPending;
        if (ClaimQueued == false && ClaimInFlight == false)
        { return; }

        _Rat = Rat;
        _Struck = true;
        _Ordering = ClaimQueued ? "strike issued with the Claim queued, before the rat's drain" : f"strike issued with the claim already drained ({Phase :n})";
        auto Health = _Rat.Get_Monster().Get_BodyHealth();
        Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        _Rat.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnPhaseChanged"));
        _SweepHit = Strike_RatAsTheChef(_Rat, 0, FVector(0.0, 1.0, 0.0));
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent)
    {
        ++_Depletions;
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        if (InNew == EMars_PantryRat_Phase::Dying)
        { ++_DyingEntries; }
    }

    UFUNCTION()
    private void Check_Struck(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Struck);
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
        const auto Committed = _Rat.Get_ClaimTransfersIssued() > 0 && _Rat.Get_LastClaimResult() == EMars_PantryRat_ClaimResult::Accepted;
        Log(f"[PantryRatTest] ordering: {_Ordering}; claim transfers issued [{_Rat.Get_ClaimTransfersIssued()}], committed [{Committed}], "
            + f"release operations [{_Rat.Get_Death().ReleaseOperationId}]");

        Assert_True(_SweepHit, "the real strike's sweep hit the rat");
        Assert_Equals_Int(_Depletions, 1, "one Health depletion");
        Assert_Equals_Int(_DyingEntries, 1, "one Dying");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the corpse's pocket is empty");

        const FCk_Handle Parent = _CheeseItem.Get_ParentInventory();
        FCk_Handle Pocket = _Rat.Get_Pocket();
        FCk_Handle SlotInventory = Get_Slot(1).Get_Inventory();
        if (Committed)
        {
            Assert_Equals_Int(_Rat.Get_Death().ReleaseOperationId, 1, "the committed claim's late receipt is released once");
            Assert_True(_Rat.Get_Death().ReleaseReceipt, "its release receipt landed");
            Assert_True(ck::IsValid(Parent) && Parent != Pocket && Parent != SlotInventory, "the cheese is outside, once");
            Assert_True(ck::Is_NOT_Valid(Get_Slot(1).Get_Item()), "no rollback copy in the slot");
        }
        else
        {
            Assert_Equals_Int(_Rat.Get_Death().ReleaseOperationId, 0, "no release: nothing was taken");
            Assert_True(Get_Slot(1).Get_Item() == _CheeseItem, "the cheese never left its slot");
        }
    }
}
