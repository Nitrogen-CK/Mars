// The batter station's control layer on the operator's own keys. The operator rig's carrier holds Interact_Primary before
// it takes the real batter station through its Use interaction: once the station's dip row is on the carrier's legend
// (the Operated tasks entered), the bowl still rests, as a hold from before the take is no press. Released, then pressed:
// the bowl dips and the row says "release to lift"; released: it rests again and the row says "hold to dip". Pressed once
// more and left with Back while dipped: the station goes Idle and leaving lifts the bowl. Isolated origin (203000, -82000,
// -30000).
class UMars_AutoTest_BatterStation_TheOperatorsPrimaryDipsAndLiftsTheBowl : UMars_AutoTestRig_HeatOperator
{
    private const FVector k_Origin = FVector(203000.0, -82000.0, -30000.0);
    // Behind the stand, facing the bowl.
    private const FVector k_CarrierLocal = FVector(-100.0, 0.0, 0.0);
    // A poll budget, not a ceiling: the station composes over a few frames.
    private const int32 k_SlowPolls = 900;
    private const FString k_DipText = "hold to dip in the batter";
    private const FString k_LiftText = "release to lift";

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        Build_HeatOperator(InHandle, EMars_AutoTest_HeatStation::Batter, k_Origin, k_CarrierLocal);

        Add_Steps_UntilReady();
        Add_Step_WaitUntil("the station composed its Batter, feed and docks", n"Check_HeatStationReady", k_SlowPolls, 0);
        Add_Step("hold Interact_Primary before taking the station", n"Step_PressPrimary");
        Add_Step_WaitUntil("Interact_Primary is held", n"Check_PrimaryHeld", 0, 0);
        Add_Steps_TakeTheStationThroughUse();
        Add_Step_WaitUntil("the station is Operated and the dip row is on the legend", n"Check_OperatedWithTheDipRow", 0, 0);
        Add_Step("the hold from before the take did not dip", n"Step_AssertResting");
        Add_Step("release Interact_Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("Interact_Primary is released and the bowl rests", n"Check_ReleasedAndResting", 0, 0);
        Add_Step("press Interact_Primary", n"Step_PressPrimary");
        Add_Step_WaitUntil("the bowl dips and the row says release to lift", n"Check_DippedWithTheLiftRow", 0, 0);
        Add_Step("release Interact_Primary", n"Step_ReleasePrimary");
        Add_Step_WaitUntil("the bowl rests and the row says hold to dip", n"Check_RestingWithTheDipRow", 0, 0);
        Add_Step("press Interact_Primary", n"Step_PressPrimary");
        Add_Step_WaitUntil("the bowl dips", n"Check_Dipped", 0, 0);
        Add_Step("leave with Back while dipped", n"Step_PressBack");
        Add_Step_WaitUntil("the station is Idle, leaving lifted the bowl and the dip row left the legend", n"Check_IdleAndResting", k_SlowPolls, 0);
        Add_Step("release both keys", n"Step_ReleaseKeys");
        Add_Step("the bowl rests and nobody operates the station", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_PressPrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_ReleasePrimary(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
    }

    UFUNCTION()
    private void Step_PressBack(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Press_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Step_ReleaseKeys(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Release_Row(GameplayTags::Mars_Intent_Interact_Primary);
        Release_Row(GameplayTags::Mars_Intent_Back);
    }

    UFUNCTION()
    private void Check_PrimaryHeld(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary));
    }

    UFUNCTION()
    private void Check_OperatedWithTheDipRow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationOperated() && Get_HasHint(k_DipText));
    }

    UFUNCTION()
    private void Step_AssertResting(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary), "Interact_Primary is still held");
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, "the bowl rests");
    }

    UFUNCTION()
    private void Check_ReleasedAndResting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsRowHeld(GameplayTags::Mars_Intent_Interact_Primary) == false && _Batter.Get_Bowl() == EMars_Batter_Bowl::Resting);
    }

    UFUNCTION()
    private void Check_DippedWithTheLiftRow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped && Get_HasHint(k_LiftText) && Get_HasHint(k_DipText) == false);
    }

    UFUNCTION()
    private void Check_RestingWithTheDipRow(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting && Get_HasHint(k_DipText) && Get_HasHint(k_LiftText) == false);
    }

    UFUNCTION()
    private void Check_Dipped(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Batter.Get_Bowl() == EMars_Batter_Bowl::Dipped);
    }

    UFUNCTION()
    private void Check_IdleAndResting(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsStationIdle() && _Batter.Get_Bowl() == EMars_Batter_Bowl::Resting
            && Get_HasHint(k_DipText) == false && Get_HasHint(k_LiftText) == false);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Batter.Get_Bowl() == EMars_Batter_Bowl::Resting, "the bowl rests");
        Assert_False(_Station.Get_IsOperated(), "nobody operates the station");
        Assert_False(Get_HasHint(k_DipText) || Get_HasHint(k_LiftText), "the dip row left the legend with the operator");
    }
}
