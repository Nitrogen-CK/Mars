// R13 (loaded rat cannot return). One resident steals the cheese; no chef exists and the pack holds no cheese any more, so
// nothing is of interest. For 20 s of the rat's own clock (time dilation 4) the loaded thief stays active and in its flee
// phases (FleeWithLoot / FleePause / FleeCornered): it is never ReturnEmpty, DenEnter or Dormant, its den slot stays Outside,
// the raid keeps it, and it still holds the same cheese. No timeout, no cull.
class UMars_AutoTest_PantryRat_LoadedRatNeverReturns : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private const float32 k_Dilation = 4.0f;
    private float32 _OriginalDilation = 1.0f;
    private bool _Watching = false;
    private FCk_Handle_PantryRat _Thief;
    private float32 _StartedAt = 0.0f;
    private TArray<EMars_PantryRat_Phase> _Seen;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(672000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);

        Add_CourtSteps();
        Add_Step_WaitUntil("the cheese is stolen", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step("watch the thief for 20 s of its clock", n"Step_Start");
        Add_Step_WaitUntil("20 s passed", n"Check_Done", k_LongPolls, 50.0f);
        Add_Step("it never went home", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        if (_Watching)
        { _Seen.AddUnique(InNew); }
    }

    UFUNCTION()
    private void Step_Start(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        _Thief = Get_FirstRat();
        _Thief.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnPhaseChanged"));
        _StartedAt = _Thief.Get_Clock();
        _OriginalDilation = Gameplay::GetGlobalTimeDilation();
        Gameplay::SetGlobalTimeDilation(k_Dilation);
        _Watching = true;
    }

    UFUNCTION()
    private void Check_Done(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Thief.Get_Clock() - _StartedAt >= 20.0f);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        Gameplay::SetGlobalTimeDilation(_OriginalDilation);
        _Watching = false;

        for (const auto Phase : _Seen)
        { Assert_True(utils_pantry_rat::Get_IsLoadedPhase(Phase), f"only flee phases (saw [{Phase :n}])"); }

        Assert_False(_Seen.Contains(EMars_PantryRat_Phase::ReturnEmpty) || _Seen.Contains(EMars_PantryRat_Phase::DenEnter),
            "never ReturnEmpty or DenEnter");
        Assert_True(utils_pantry_rat::Get_IsLoadedPhase(_Thief.Get_Phase()), "still fleeing");
        Assert_True(_Thief.Get_Loot() == _CheeseItem, "still the same cheese");
        Assert_True(_Den.Get_SlotState(0) == EMars_RatDen_SlotState::Outside, "its den slot is still Outside");
        Assert_Equals_Int(_Raid.Get_RatCount(), 1, "the raid keeps it");
        Assert_True(_Seen.Contains(EMars_PantryRat_Phase::FleePause), "it paused between bursts (it kept moving)");
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        if (_Watching)
        { Gameplay::SetGlobalTimeDilation(_OriginalDilation); }

        Super::DoEndPlay(InHandle);
    }
}
