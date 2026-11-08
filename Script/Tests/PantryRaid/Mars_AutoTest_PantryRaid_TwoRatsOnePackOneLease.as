// R09 (two rats one pack). Both residents raid the same unattended pack. Every frame the pack carries at most one lease and at
// most one rat holds a claim target; the second rat (whose pick is the other slot) waits outside the lease. When the first
// theft lands exactly one actual item has moved: one pocket holds the cheese, the other rat's pocket is empty and it never
// issued a claim, and the court's ingredient count is unchanged.
class UMars_AutoTest_PantryRaid_TwoRatsOnePackOneLease : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private int32 _MaxLeases = 0;
    private int32 _MaxTargets = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(656000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("both residents are out", n"Check_TwoRats", k_LongPolls, 0);
        Add_Step_WaitUntil("one theft lands", n"Check_OneLoaded", k_LongPolls, 0);
        Add_Step("one lease at a time, one item moved, no duplicate", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Raid))
        { return; }

        _MaxLeases = Math::Max(_MaxLeases, _Raid.Get_LeaseCount());
        auto Targets = 0;
        for (auto Rat : Get_Rats())
        {
            if (Rat.Get_Target().IsSet())
            { ++Targets; }
        }
        _MaxTargets = Math::Max(_MaxTargets, Targets);
    }

    UFUNCTION()
    private void Check_TwoRats(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Raid) && Get_Rats().Num() == 2);
    }

    UFUNCTION()
    private void Check_OneLoaded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Loaded = false;
        for (auto Rat : Get_Rats())
        { Loaded = Loaded || Rat.Get_HasCarryReceipt(); }

        auto Result = OutResult;
        Result.Set(Loaded);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_MaxLeases, 1, "never more than one lease on the pack");
        Assert_Equals_Int(_MaxTargets, 1, "never more than one rat holding a claim target");

        auto Pocketed = 0;
        auto Claims = 0;
        auto Thieves = 0;
        for (auto Rat : Get_Rats())
        {
            Pocketed += Rat.Get_Pocket().Get_NumItems();
            Claims += Rat.Get_ClaimTransfersIssued();
            if (Rat.Get_IsLoaded())
            {
                ++Thieves;
                Assert_True(Rat.Get_Loot() == _CheeseItem, "the thief holds the original cheese");
            }
        }

        Assert_Equals_Int(Pocketed, 1, "exactly one item moved into a pocket");
        Assert_Equals_Int(Thieves, 1, "exactly one thief");
        Assert_Equals_Int(Claims, 1, "the loser never issued a claim");
        Assert_Equals_Int(Count_CourtItems(), 2, "no duplicate: the court still holds two ingredients");
    }
}
