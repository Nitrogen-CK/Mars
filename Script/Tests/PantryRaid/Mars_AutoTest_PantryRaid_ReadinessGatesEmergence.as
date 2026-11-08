// R01 (den readiness and spawn). The court is complete but its nav field is never built: for 3 s the raid is not ready, no
// rat exists and both residents stay Dormant with no emergence asked. Then the field builds: the raid stamps Ready (a real
// provider route from the den's OutsideStand into its bounds) and emerges the residents one operation per slot - exactly two
// rats, on slots 0 and 1, with distinct operation ids, each slot Outside, no stale spawn, never a third body.
class UMars_AutoTest_PantryRaid_ReadinessGatesEmergence : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(624000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _BuildField = false;
        Arrange_Court(InHandle, 0);

        Add_CourtSteps();
        Add_Step_WaitSeconds("3 s with no built field", 3.0f);
        Add_Step("no readiness, no rat, no emergence; now build the field", n"Step_AssertGatedAndBuild");
        Add_Step_WaitUntil("both residents are out", n"Check_TwoRats", k_LongPolls, 0);
        Add_Step_WaitSeconds("a further 2 s (four emergence spacings)", 2.0f);
        Add_Step("two rats, one per slot, distinct operations", n"Step_AssertOnePerSlot");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_AssertGatedAndBuild(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_False(_Raid.Get_IsReady(), "no built field: not ready");
        Assert_Equals_Int(_Raid.Get_RatCount(), 0, "no rat without readiness");
        Assert_Equals_Int(_Den.Get_SlotCountIn(EMars_RatDen_SlotState::Dormant), 2, "both residents Dormant");
        Assert_Equals_Int(_Raid.Get_Fragment(FMars_Fragment_PantryRaid).PendingOperations.Num(), 0, "no emergence asked");
        RequestBuild(1);
    }

    UFUNCTION()
    private void Check_TwoRats(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_IsReady() && Get_Rats().Num() >= 2);
    }

    UFUNCTION()
    private void Step_AssertOnePerSlot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Records = _Raid.Get_Rats();
        Assert_Equals_Int(Records.Num(), 2, "exactly two rat bodies for two residents");
        Assert_True(Records[0].Slot != Records[1].Slot, "one rat per slot");
        Assert_True(Records[0].OperationId != Records[1].OperationId, "distinct operation ids");
        Assert_Equals_Int(_Raid.Get_StaleSpawns(), 0, "no stale spawn");
        Assert_Equals_Int(_Den.Get_SlotCountIn(EMars_RatDen_SlotState::Outside), 2, "both slots Outside");
        Assert_True(_Den.Get_SlotOperationId(Records[0].Slot) == Records[0].OperationId, "the den slot names its rat's operation");
    }
}
