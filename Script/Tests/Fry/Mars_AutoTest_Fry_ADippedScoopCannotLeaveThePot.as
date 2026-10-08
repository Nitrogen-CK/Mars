// The skimmer dipped at its park and a hard look right (+128 cm of target): the target stops on the pot disc's edge
// (PotRadius less the bowl and its lip) and the scoop's centre never leaves the disc (give or take the slide spring's
// overshoot), so a dipped scoop cannot cut through the rim. Carried back up clear of the rim, the same look carries it out
// of the pot, across the corridor and over the basket.
class UMars_AutoTest_Fry_ADippedScoopCannotLeaveThePot : UMars_AutoTestRig_Fry
{
    default _TimeoutSeconds = 15.0f;

    private const FVector k_HardRight = FVector(80.0, 0.0, 0.0);
    private const float32 k_WatchSeconds = 1.2f;

    private float32 _WatchStart = 0.0f;
    private float64 _MaxDippedRadius = 0.0;
    private float64 _MaxDippedTargetRadius = 0.0;
    private float64 _MaxCarriedY = -1000.0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        BuildStation(InHandle, Make_TestSpec());

        Add_Step("drive the skimmer", n"Step_Drive");
        Add_Step("dip it at its park", n"Step_Dip");
        Add_Step_WaitUntil("the scoop reached the dip", n"Check_Dipped", 0, 3.0f);
        Add_Step("look hard right while dipped", n"Step_LookHardRight");
        Add_Step_WaitUntil("the dipped scoop had time to follow", n"Check_DippedWatched", 0, k_WatchSeconds + 1.0f);
        Add_Step("it stayed in the pot; carry it up", n"Step_AssertInPotThenCarry");
        Add_Step_WaitUntil("the scoop carries, clear of the rim", n"Check_CarryingClear", 0, 4.0f);
        Add_Step("look hard right again", n"Step_LookHardRight");
        Add_Step_WaitUntil("the carried scoop had time to follow", n"Check_CarriedWatched", 0, 3.0f);
        Add_Step("it left the pot", n"Step_AssertLeftThePot");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Step_LookHardRight(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _WatchStart = Get_Now();
        Look(k_HardRight);
    }

    UFUNCTION()
    private void Check_DippedWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _MaxDippedRadius = Math::Max(_MaxDippedRadius, _Fry.Get_ScoopRoot().Size2D());
        _MaxDippedTargetRadius = Math::Max(_MaxDippedTargetRadius, _Fry.Get_SkimmerTarget().Size());
        auto Res = OutResult;
        Res.Set(Get_Now() - _WatchStart >= k_WatchSeconds);
    }

    UFUNCTION()
    private void Step_AssertInPotThenCarry(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Radius = float64(utils_fry::Get_PotReachRadius(_Spec));
        Log(f"[Mars_AutoTest_Fry_ADippedScoopCannotLeaveThePot] dipped: target {_Fry.Get_SkimmerTarget()} (max radius {_MaxDippedTargetRadius :.3}), scoop max radius {_MaxDippedRadius :.3}, pot reach radius {Radius :.2}");

        Assert_True(_Fry.Get_Skim() == EMars_Fry_Skim::Dip, "the scoop stayed dipped");
        Assert_True(_MaxDippedTargetRadius <= Radius + 0.001, f"the dipped target never left the pot disc (max radius {_MaxDippedTargetRadius :.3})");
        Assert_True(_MaxDippedRadius <= Radius + float64(utils_fry::k_ReachTolerance),
            f"the dipped scoop never left the pot disc (max radius {_MaxDippedRadius :.3} of {Radius :.2})");
        Assert_True(_Fry.Get_SkimmerTarget().Y > 20.0, "the look did move the target toward the right edge of the disc");

        Carry();
    }

    UFUNCTION()
    private void Check_CarriedWatched(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _MaxCarriedY = Math::Max(_MaxCarriedY, _Fry.Get_ScoopRoot().Y);
        auto Res = OutResult;
        Res.Set(Get_Now() - _WatchStart >= k_WatchSeconds && Get_IsSlideSettled());
    }

    UFUNCTION()
    private void Step_AssertLeftThePot(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto ScoopRoot = _Fry.Get_ScoopRoot();
        Log(f"[Mars_AutoTest_Fry_ADippedScoopCannotLeaveThePot] carried: target {_Fry.Get_SkimmerTarget()}, scoop at root {ScoopRoot}");

        Assert_True(ScoopRoot.Y > float64(_Spec.Zones.PotRadius), f"the carried scoop crossed the rim to the right (Y {ScoopRoot.Y :.2})");
        const auto& Reach = _Spec.Reach;
        Assert_True(ScoopRoot.Y > Reach.BasketCentre.Y - Reach.BasketHalfExtent.Y,
            f"the hard look carried it across the corridor over the basket's footprint (Y {ScoopRoot.Y :.2})");
    }
}
