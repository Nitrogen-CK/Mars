// R03 (unattended pack remains target). A chef stands 150 cm from the grounded cheese pack: it is Guarded, the emerged rat
// watches (WatchGuarded) with no lease and no claim. The chef walks away (1400 cm): after the clear dwell the pack is
// unguarded and the empty rat keeps raiding - a lease is granted on the first low pocket's cheese and the theft lands (the
// rat's pocket holds that exact item, the slot is empty, the carry receipt arrived, FleeWithLoot). Walking away is not a
// no-target condition.
class UMars_AutoTest_PantryRaid_UnattendedPackStaysTarget : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(628000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));

        Add_CourtSteps();
        Add_Step_WaitUntil("a rat is out and watching the guarded pack", n"Check_Watching", k_LongPolls, 0);
        Add_Step("guarded: no lease, no claim; the chef walks away", n"Step_AssertGuardedAndLeave");
        Add_Step_WaitUntil("a lease is granted on the unattended pack", n"Check_Leased", k_LongPolls, 0);
        Add_Step_WaitUntil("the theft lands and the thief flees", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("the rat holds the exact cheese, the slot is empty", n"Step_AssertStolen");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_Watching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        auto Result = OutResult;
        Result.Set(ck::IsValid(Rat) && Rat.Get_Phase() == EMars_PantryRat_Phase::WatchGuarded);
    }

    UFUNCTION()
    private void Step_AssertGuardedAndLeave(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        Assert_True(Record.IsSet() && Record.GetValue().Guarded, "the pack is Guarded by the chef at 150 cm");
        Assert_Equals_Int(_Raid.Get_LeasesGranted(), 0, "no lease while guarded");
        Assert_Equals_Int(Get_FirstRat().Get_ClaimTransfersIssued(), 0, "no claim while guarded");
        Move_Chef(0, _Origin + k_ChefAway);
    }

    UFUNCTION()
    private void Check_Leased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_LeasesGranted() > 0);
    }

    UFUNCTION()
    private void Step_AssertStolen(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        FCk_Handle PocketEntity = Rat.Get_Pocket();
        const FCk_Handle Parent = _CheeseItem.Get_ParentInventory();
        Assert_True(Rat.Get_Loot() == _CheeseItem, "the loot is the original cheese handle");
        Assert_True(Parent == PocketEntity, "the cheese's parent inventory is the rat's pocket");
        Assert_True(ck::Is_NOT_Valid(Get_Slot(1).Get_Item()), "slot 1 is empty");
        Assert_True(Rat.Get_LastClaimResult() == EMars_PantryRat_ClaimResult::Accepted, "the claim was Accepted");
        Assert_Equals_Int(Rat.Get_ClaimTransfersIssued(), 1, "one claim transfer");
        Assert_Equals_Int(Count_CourtItems(), 2, "the court still holds two ingredients");
    }
}
