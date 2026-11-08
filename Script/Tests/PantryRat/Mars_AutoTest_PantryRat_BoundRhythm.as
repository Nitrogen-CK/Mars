// R28 (bound and observer rhythm). One rat with the shipped rhythm raids an unattended pack, then flees. Every approach
// burst plans 1-3 bounds and every Observe pause lasts 0.6-1.5 s; every loaded burst plans 2-3 bounds and every FleePause
// lasts 0.35-0.65 s; each burst is followed by its pause. The root is moved only by SurfaceMotion: while the rat pauses
// (Observe / FleePause, after a 0.25 s settle) its root speed stays under 20 cm/s and its navigator is not moving.
class UMars_AutoTest_PantryRat_BoundRhythm : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private TArray<int32> _ApproachBursts;
    private TArray<int32> _FleeBursts;
    private TArray<float32> _ObservePauses;
    private TArray<float32> _FleePauses;
    private TArray<EMars_PantryRat_Phase> _Sequence;
    private float64 _MaxPauseSpeed = 0.0;
    private int32 _NavMovingInPause = 0;
    private TOptional<FVector> _LastLocation;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(712000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("a rat is out", n"Check_Bound", k_LongPolls, 0);
        Add_Step_WaitUntil("the theft lands", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step_WaitUntil("two flee pauses", n"Check_TwoFleePauses", k_LongPolls, 0);
        Add_Step("the rhythm stayed in its bands", n"Step_Assert");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void OnPhaseChanged(FCk_Handle_PantryRat InRat, EMars_PantryRat_Phase InPrevious, EMars_PantryRat_Phase InNew)
    {
        _Sequence.Add(InNew);
        const auto Rhythm = InRat.Get_Rhythm();
        if (InNew == EMars_PantryRat_Phase::BoundApproach)
        { _ApproachBursts.Add(Rhythm.BurstsPlanned); }
        else if (InNew == EMars_PantryRat_Phase::FleeWithLoot)
        { _FleeBursts.Add(Rhythm.BurstsPlanned); }
        else if (InNew == EMars_PantryRat_Phase::Observe)
        { _ObservePauses.Add(Rhythm.PauseDeadline - InRat.Get_Clock()); }
        else if (InNew == EMars_PantryRat_Phase::FleePause)
        { _FleePauses.Add(Rhythm.PauseDeadline - InRat.Get_Clock()); }
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Rat))
        { return; }

        const auto Here = _Rat.Get_Location();
        const auto Delta = InDeltaT.Get_Seconds();
        const auto Phase = _Rat.Get_Phase();
        const auto Pausing = (Phase == EMars_PantryRat_Phase::Observe || Phase == EMars_PantryRat_Phase::FleePause) && _Rat.Get_PhaseAge() > 0.25f;
        if (Pausing && _LastLocation.IsSet() && Delta > 0.0)
        {
            _MaxPauseSpeed = Math::Max(_MaxPauseSpeed, (Here - _LastLocation.GetValue()).Size2D() / Delta);
            if (_Rat.Get_Navigator().Get_Status() == EMars_SurfaceNavigator_Status::Moving)
            { ++_NavMovingInPause; }
        }
        _LastLocation = Here;
    }

    UFUNCTION()
    private void Check_Bound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        if (ck::IsValid(Rat) && ck::Is_NOT_Valid(_Rat))
        {
            _Rat = Rat;
            _Rat.BindTo_OnPhaseChanged(FMars_Delegate_PantryRat_OnPhaseChanged(this, n"OnPhaseChanged"));
        }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_Rat));
    }

    UFUNCTION()
    private void Check_TwoFleePauses(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_FleePauses.Num() >= 2);
    }

    UFUNCTION()
    private void Step_Assert(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Rhythm = _Spec.Rhythm;
        Assert_True(_ApproachBursts.Num() > 0, "the rat approached in bursts");
        for (const auto Bursts : _ApproachBursts)
        { Assert_True(Bursts >= Rhythm.EmptyBoundsMin && Bursts <= Rhythm.EmptyBoundsMax, f"an approach burst of {Bursts} bounds is in 1..3"); }

        for (const auto Bursts : _FleeBursts)
        { Assert_True(Bursts >= Rhythm.LoadedBoundsMin && Bursts <= Rhythm.LoadedBoundsMax, f"a loaded burst of {Bursts} bounds is in 2..3"); }

        for (const auto Pause : _ObservePauses)
        { Assert_True(Pause >= Rhythm.ObserveMinSeconds - 0.01f && Pause <= Rhythm.ObserveMaxSeconds + 0.01f, f"an Observe pause of {Pause} s is in 0.6..1.5"); }

        for (const auto Pause : _FleePauses)
        { Assert_True(Pause >= Rhythm.FleePauseMinSeconds - 0.01f && Pause <= Rhythm.FleePauseMaxSeconds + 0.01f, f"a FleePause of {Pause} s is in 0.35..0.65"); }

        for (int32 Index = 0; Index + 1 < _Sequence.Num(); ++Index)
        {
            if (_Sequence[Index] == EMars_PantryRat_Phase::FleeWithLoot)
            {
                const auto Next = _Sequence[Index + 1];
                Assert_True(Next == EMars_PantryRat_Phase::FleePause || Next == EMars_PantryRat_Phase::FleeCornered,
                    f"a loaded burst is followed by its pause (got [{Next :n}])");
            }
        }

        Assert_True(_MaxPauseSpeed < 20.0, f"the root rests during pauses (max {_MaxPauseSpeed} cm/s)");
        Assert_Equals_Int(_NavMovingInPause, 0, "the navigator never moves the rat during a pause");
    }
}
