// A one-charge source that regrows after 0.3 s: a release exhausts it with a regrow pending, it replenishes (charge back,
// not exhausted, no regrow pending) and releases again.
class UMars_AutoTest_Forage_ExhaustedRegrows : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_Origin = FVector(-60000.0, 2000.0, -60000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddSource(InHandle, k_Origin);
        AddForage(Make_RockSpec(1, FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Regrows, 0.3f)));

        Add_Step("request a release", n"Step_Release");
        Add_Step_WaitUntil("released, exhausted, regrow pending", n"Check_ExhaustedPending");
        Add_Step_WaitUntil("replenished", n"Check_Replenished", 0, 3.0f);
        Add_Step("the charge is back and nothing is pending", n"Step_AssertReplenished");
        Add_Step("request a release again", n"Step_Release");
        Add_Step_WaitUntil("released again", n"Check_SecondRelease");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RequestRelease(EMars_Forage_ReleaseReason::Depleted);
    }

    UFUNCTION()
    private void Check_ExhaustedPending(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 1 && _Forage.Get_IsExhausted() && _Forage.Get_IsRegrowPending());
    }

    UFUNCTION()
    private void Check_Replenished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_ReplenishedCount == 1);
    }

    UFUNCTION()
    private void Step_AssertReplenished(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Forage.Get_ChargesLeft(), 1, "the charge is back");
        Assert_False(_Forage.Get_IsExhausted(), "no longer exhausted");
        Assert_False(_Forage.Get_IsRegrowPending(), "no regrow pending");
        Assert_Equals_Int(_Released.Num(), 1, "replenishing releases nothing");
    }

    UFUNCTION()
    private void Check_SecondRelease(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 2 && _ExhaustedCount == 2);
    }
}
