// A Persists source of 2 Rock charges releases once per request, exhausts on the second (OnExhausted once), drops a
// third request, and the first yield seeds as a World-mode Rock.
class UMars_AutoTest_Forage_ReleasesPerRequestThenExhausts : UMars_AutoTestRig_Forage
{
    default _TimeoutSeconds = 8.0f;

    private const FVector k_Origin = FVector(-60000.0, 0.0, -60000.0);

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        AddSource(InHandle, k_Origin);
        AddForage(Make_RockSpec(2, FMars_Forage_ExhaustionSpec(EMars_Forage_Exhaustion::Persists)));

        Add_Step("request a release", n"Step_Release");
        Add_Step_WaitUntil("one release, one charge left", n"Check_FirstReleased");
        Add_Step("request a second release", n"Step_Release");
        Add_Step_WaitUntil("two releases, exhausted once", n"Check_Exhausted");
        Add_Step("request a third release while exhausted", n"Step_Release");
        Add_Step_WaitSeconds("a third release would land in this window", 0.3f);
        Add_Step("still two releases", n"Step_AssertNoThirdRelease");
        Add_Step_WaitUntil("the first yield seeded as a World-mode Rock", n"Check_FirstYieldSeeded");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_Release(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        RequestRelease(EMars_Forage_ReleaseReason::Hit);
    }

    UFUNCTION()
    private void Check_FirstReleased(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 1 && _Forage.Get_ChargesLeft() == 1 && _Forage.Get_IsExhausted() == false);
    }

    UFUNCTION()
    private void Check_Exhausted(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(_Released.Num() == 2 && _Forage.Get_IsExhausted() && _ExhaustedCount == 1);
    }

    UFUNCTION()
    private void Step_AssertNoThirdRelease(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_Equals_Int(_Released.Num(), 2, "an exhausted source releases nothing");
        Assert_Equals_Int(_Forage.Get_ReleasedCount(), 2, "ReleasedCount stays at 2");
        Assert_Equals_Int(_Forage.Get_ChargesLeft(), 0, "no charges left");
        Assert_Equals_Int(_ExhaustedCount, 1, "OnExhausted fired once");
        Assert_False(_Forage.Get_IsRegrowPending(), "a Persists source never regrows");
        for (int32 Index = 0; Index < _ReleaseReasons.Num(); ++Index)
        { Assert_True(_ReleaseReasons[Index] == EMars_Forage_ReleaseReason::Hit, f"release [{Index}] carries the request's reason"); }
    }

    UFUNCTION()
    private void Check_FirstYieldSeeded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(Get_IsSeededWith(_Released[0], mars_items::Rock()));
    }
}
