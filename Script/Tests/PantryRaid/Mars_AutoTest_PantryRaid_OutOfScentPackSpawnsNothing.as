// F7-1 (Phase 8). The court's den OutsideStand is 575 cm from the armed, reachable pack and the raid's ScentRangeCm is 525 - the
// court's 1250-vs-1200 case, scaled to the rig's field (+-600 cm): the den is 50 cm farther from the pack than a rat can smell.
// The rat's own target view (utils_pantry_raid::TryGet_Target) would never see the pack from the stand, so the raid must not emerge
// a rat for it: 10 s of raid clock after the pack armed, no emergence request, no rat, no rat ever in ReturnEmpty, and the
// "beyond the scent range" line logged exactly once for the pack.
class UMars_AutoTest_PantryRaid_OutOfScentPackSpawnsNothing : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private float32 _ArmedAt = -1.0f;
    private TArray<FCk_Handle> _RatsSeen;
    private int32 _WentHome = 0;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(744000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Scent.ScentRangeCm = 525.0f;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("the raid is ready and the pack armed", n"Check_Armed", k_LongPolls, 0);
        Add_Step_WaitUntil("10 s of raid clock with the pack armed", n"Check_TenSeconds", k_LongPolls, 0);
        Add_Step("no emergence for a pack beyond the scent range; logged once", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Raid))
        { return; }

        for (auto Rat : Get_Rats())
        {
            FCk_Handle RatEntity = Rat;
            if (_RatsSeen.Contains(RatEntity) == false)
            { _RatsSeen.Add(RatEntity); }

            if (Rat.Get_Phase() == EMars_PantryRat_Phase::ReturnEmpty)
            { ++_WentHome; }
        }
    }

    UFUNCTION()
    private void Check_Armed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Armed = false;
        if (ck::IsValid(_Raid) && _Raid.Get_IsReady())
        {
            const auto Record = _Raid.TryGet_PackRecord(_Pack);
            Armed = Record.IsSet() && Record.GetValue().ScentArmed && Record.GetValue().EligibleSlots.Num() > 0;
        }

        if (Armed && _ArmedAt < 0.0f)
        { _ArmedAt = _Raid.Get_Clock(); }

        auto Result = OutResult;
        Result.Set(Armed);
    }

    UFUNCTION()
    private void Check_TenSeconds(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Raid.Get_Clock() - _ArmedAt >= 10.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Raid.Get_EmergencesRequested() == 0 && _RatsSeen.Num() == 0,
            f"no rat emerges for a pack beyond the scent range (emergences requested [{_Raid.Get_EmergencesRequested()}], "
            + f"rats seen [{_RatsSeen.Num()}], frames a rat spent in ReturnEmpty [{_WentHome}])");
        Assert_Equals_Int(_WentHome, 0, "no rat went home with no target");
        Assert_Equals_Int(_Raid.Get_OutOfScentTargetLogs(), 1, "the beyond-the-scent-range line was logged exactly once");
    }
}
