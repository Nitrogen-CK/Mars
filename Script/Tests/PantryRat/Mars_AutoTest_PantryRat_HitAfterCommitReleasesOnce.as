// R17, second half (hit during transfer: a committed item is released once). The theft commits (the cheese is in the
// pocket); the chef's cleaver strikes the moment the rat's carry phases begin (CarryMountPending or the first flee phase).
// The rat dies once and releases that same item exactly once (one release operation), the release's receipt lands (the
// cheese in a World holder outside the pocket) before the corpse holds, and nothing was rolled back or duplicated.
class UMars_AutoTest_PantryRat_HitAfterCommitReleasesOnce : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private bool _Struck = false;
    private int32 _Depletions = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(684000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Make_WeaponHolder(InHandle);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the claim commits and the strike lands", n"Check_Struck", k_LongPolls, 0);
        Add_Step_WaitUntil("the corpse holds", n"Check_DeadHold", k_SlowPolls, 0);
        Add_Step("one release, its receipt, the same item outside", n"Step_Assert");
        Run_Steps(InHandle);
    }

    // Strikes on the first frame the committed loot is the rat's.
    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Struck)
        { return; }

        auto Rat = Get_FirstRat();
        if (ck::Is_NOT_Valid(Rat) || utils_pantry_rat::Get_IsLoadedPhase(Rat.Get_Phase()) == false)
        { return; }

        _Rat = Rat;
        _Struck = true;
        auto Health = _Rat.Get_Monster().Get_BodyHealth();
        Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnDepleted"));
        Strike_Rat(_Rat, 0);
    }

    UFUNCTION()
    private void OnDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent)
    {
        ++_Depletions;
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
        const auto Death = _Rat.Get_Death();
        Assert_Equals_Int(Death.ReleaseOperationId, 1, "exactly one release operation");
        Assert_True(Death.ReleaseReceipt, "the release's receipt landed before the hold");
        Assert_Equals_Int(_Depletions, 1, "one death");
        Assert_Equals_Int(_Rat.Get_Pocket().Get_NumItems(), 0, "the pocket is empty");
        const FCk_Handle Parent = _CheeseItem.Get_ParentInventory();
        FCk_Handle Pocket = _Rat.Get_Pocket();
        Assert_True(ck::IsValid(Parent) && Parent != Pocket, "the same cheese is outside the pocket");
        Assert_True(ck::Is_NOT_Valid(Get_Slot(1).Get_Item()), "no rollback into the slot");
    }
}
