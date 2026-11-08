// R06 (all-player guarding). Two chefs. Chef A guards the pack at 150 cm; the rat watches. In one step A walks away and chef
// B steps in at 180 cm: the pack never clears (every frame for 3 s it stays Guarded, its guard chef is now B) and no lease is
// granted - the second chef is respected, not only the first. Then both chefs close on the rat itself, A at 280 cm and B at
// 200 cm: the rat's threat is the nearer chef, B, whichever came first.
class UMars_AutoTest_PantryRaid_ClosestValidThreatWins : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private bool _Watching = false;
    private int32 _UnguardedFrames = 0;
    private FCk_Handle_PantryRat _Rat;
    private FVector _RatAt;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(644000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 2);
        Move_Chef(0, Get_PackSide(150.0));
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat is out and watching", n"Check_Watching", k_LongPolls, 0);
        Add_Step("A walks away while B steps in", n"Step_Swap");
        Add_Step_WaitSeconds("3 s across the swap", 3.0f);
        Add_Step("the pack stayed Guarded by B; now both chefs close on the rat", n"Step_AssertSwapAndClose");
        Add_Step_WaitUntil("the rat sees a threat", n"Check_Threat", k_SlowPolls, 0);
        Add_Step("the nearer chef is the threat", n"Step_AssertNearest");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Watching == false)
        { return; }

        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        if (Record.IsSet() == false || Record.GetValue().Guarded == false)
        { ++_UnguardedFrames; }
    }

    UFUNCTION()
    private void Check_Watching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_Phase() == EMars_PantryRat_Phase::WatchGuarded);
    }

    UFUNCTION()
    private void Step_Swap(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Watching = true;
        Move_Chef(0, _Origin + k_ChefAway);
        Move_Chef(1, Get_PackSide(180.0));
    }

    UFUNCTION()
    private void Step_AssertSwapAndClose(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Watching = false;
        Assert_Equals_Int(_UnguardedFrames, 0, "the pack never cleared across the swap");
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        Assert_True(Record.IsSet() && Record.GetValue().GuardChef == _Chefs[1], "chef B is the pack's guard now");
        Assert_Equals_Int(_Raid.Get_LeasesGranted(), 0, "no lease across the swap");

        _RatAt = _Rat.Get_Location();
        Move_Chef(0, FVector(_RatAt.X, _RatAt.Y + 280.0, _Origin.Z));
        Move_Chef(1, FVector(_RatAt.X, _RatAt.Y - 200.0, _Origin.Z));
    }

    UFUNCTION()
    private void Check_Threat(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Rat.Get_Threat().Active);
    }

    UFUNCTION()
    private void Step_AssertNearest(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Rat.Get_Threat().Chef == _Chefs[1], "the threat is chef B, the nearer");
        const auto Nearest = utils_pantry_raid::Get_NearestChef(_Raid.Get_Chefs(), _RatAt, _Spec.Guard.SameFloorCm);
        Assert_True(Nearest.Root == _Chefs[1], "the raid's snapshots agree: B is nearest");
    }
}
