// F7-1 (Phase 8), the other side. The den OutsideStand is 575 cm from the armed pack and ScentRangeCm is 640 - inside the range with
// the rat's 30 cm arrival slack to spare (the court's 1150-vs-1200 case, scaled to the rig's field): a rat emerges, sees the
// pack from where it stops and never goes home with no target; nothing is logged as beyond the scent range.
class UMars_AutoTest_PantryRaid_InScentPackStillEmerges : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private int32 _WentHome = 0;
    private bool _SawTarget = false;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(748000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        _Spec.Scent.ScentRangeCm = 640.0f;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("a rat emerges and works toward the pack", n"Check_Working", k_LongPolls, 0);
        Add_Step("it emerged, saw the pack and did not go home", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Raid))
        { return; }

        for (auto Rat : Get_Rats())
        {
            const auto Phase = Rat.Get_Phase();
            if (Phase == EMars_PantryRat_Phase::ReturnEmpty)
            { ++_WentHome; }

            if (Phase == EMars_PantryRat_Phase::BoundApproach || Phase == EMars_PantryRat_Phase::Inspect
                || Phase == EMars_PantryRat_Phase::ClaimTell)
            { _SawTarget = true; }
        }
    }

    UFUNCTION()
    private void Check_Working(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_SawTarget || _WentHome > 0);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Assert_True(_Raid.Get_EmergencesRequested() >= 1, "a rat emerged for the in-range pack");
        Assert_True(_SawTarget, "the rat saw the pack (BoundApproach / Inspect / ClaimTell)");
        Assert_Equals_Int(_WentHome, 0, "it never went home with no target");
        Assert_Equals_Int(_Raid.Get_OutOfScentTargetLogs(), 0, "nothing logged as beyond the scent range");
    }
}
