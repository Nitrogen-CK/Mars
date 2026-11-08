// R07 (threat hysteresis and paths). A chef guards the pack (150 cm), the rat watches. The chef then oscillates between 300 cm
// and 340 cm from the pack every 0.4 s for 6 s - across the 320 cm exit bar but never beyond it for the 1 s clear dwell. The
// pack never clears (no guard flip after the first), no lease is granted, no claim is issued, and the rat's phase changes
// at most once over the whole oscillation (no flip-flop).
class UMars_AutoTest_PantryRaid_GuardHysteresisNoJitter : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private const float32 k_HalfPeriod = 0.4f;
    private FCk_Handle_PantryRat _Rat;
    private bool _Oscillating = false;
    private bool _Far = false;
    private float32 _NextFlipAt = 0.0f;
    private int32 _FlipsBefore = 0;
    private int32 _PhaseChangesBefore = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(648000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 1);
        Move_Chef(0, Get_PackSide(150.0));
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnOscillate"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the rat is out and watching", n"Check_Watching", k_LongPolls, 0);
        Add_Step("start oscillating the chef between 300 and 340 cm", n"Step_Start");
        Add_Step_WaitSeconds("6 s of oscillation", 6.0f);
        Add_Step("no clear, no lease, no claim, at most one phase change", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnOscillate(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || _Oscillating == false || _Raid.Get_Clock() < _NextFlipAt)
        { return; }

        _NextFlipAt = _Raid.Get_Clock() + k_HalfPeriod;
        _Far = _Far == false;
        Move_Chef(0, Get_PackSide(_Far ? 340.0 : 300.0));
    }

    UFUNCTION()
    private void Check_Watching(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        _Rat = Get_FirstRat();
        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat) && _Rat.Get_Phase() == EMars_PantryRat_Phase::WatchGuarded);
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        _FlipsBefore = Record.GetValue().GuardFlips;
        _PhaseChangesBefore = _Rat.Get_PhaseChanges();
        _NextFlipAt = _Raid.Get_Clock();
        _Oscillating = true;
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Oscillating = false;
        const auto Record = _Raid.TryGet_PackRecord(_Pack);
        Assert_True(Record.GetValue().Guarded, "still Guarded after 6 s of oscillation");
        Assert_Equals_Int(Record.GetValue().GuardFlips, _FlipsBefore, "the guard never flipped during the oscillation");
        Assert_Equals_Int(_Raid.Get_LeasesGranted(), 0, "no lease");
        Assert_Equals_Int(_Rat.Get_ClaimTransfersIssued(), 0, "no claim");
        Assert_True(_Rat.Get_PhaseChanges() - _PhaseChangesBefore <= 1,
            f"at most one phase change over the oscillation (got {_Rat.Get_PhaseChanges() - _PhaseChangesBefore})");
    }
}
