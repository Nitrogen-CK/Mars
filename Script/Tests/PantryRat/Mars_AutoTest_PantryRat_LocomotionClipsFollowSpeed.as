// Phase 9 (locomotion that matches the mover). The assembly's clip choice, read headless (no body: the entity script chooses
// the clip and its play rate every frame anyway). The table: a Creep-speed move (100 cm/s) walks at rate 1, an Approach
// burst (240) bounds at 240 / 200 = 1.2, a loaded flee (320) bounds loaded at 320 / 280, a standing rat plays its phase's
// idle clip at rate 1, and the rate clamps to 0.7 .. 1.5. Live, one rat raids the court and flees: every frame a locomotion
// loop plays, its rate is the measured speed over that loop's design speed (clamped); mid-burst it is BoundCycle at ~1.2 and
// LoadedBound at ~1.14; a bound from standing opens with BoundStart and one that comes to rest closes with BoundStop; the
// emergence creep walks and never bounds.
class UMars_AutoTest_PantryRat_LocomotionClipsFollowSpeed : UMars_AutoTestRig_PantryRaid
{
    default _TimeoutSeconds = 60.0f;

    private FCk_Handle_PantryRat _Rat;
    private UMars_PantryRat_EntityScript _Script;
    private TArray<FName> _ClipSequence;
    private int32 _BoundSamples = 0;
    private int32 _LoadedSamples = 0;
    private int32 _EmergeWalkSamples = 0;
    private int32 _EmergeBoundSamples = 0;
    private int32 _RateMismatches = 0;
    private float64 _BoundRateSum = 0.0;
    private float64 _LoadedRateSum = 0.0;
    private FString _FirstMismatch;
    private int32 _FleePauses = 0;
    // Per moving phase: the fastest smoothed speed seen and the clips played while the speed was over k_MovingSpeed.
    private TMap<FName, float32> _MaxSpeedByPhase;
    private TMap<FName, int32> _MovingFramesByClip;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        _Origin = FVector(756000.0, -200000.0, -60000.0);
        _Spec = Make_CourtSpec();
        _Spec.Population.ResidentsPerDen = 1;
        Arrange_Court(InHandle, 0);
        utils_timer::Create_Tick(InHandle, FCk_Delegate_Timer(this, n"OnWatch"));

        Add_CourtSteps();
        Add_Step_WaitUntil("a rat is out with its assembly", n"Check_RatOut", k_LongPolls, 0);
        Add_Step("the clip table at Creep, Approach, LoadedFlee and standing speeds", n"Step_AssertTable");
        Add_Step_WaitUntil("the theft lands", n"Check_FirstRatLoaded", k_LongPolls, 0);
        Add_Step_WaitUntil("two flee pauses", n"Check_TwoFleePauses", k_LongPolls, 0);
        Add_Step("the live clips followed the measured speed", n"Step_AssertLive");
        Run_Steps(InHandle);
    }

    UFUNCTION()
    private void Check_RatOut(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Rat = Get_FirstRat();
        if (ck::IsValid(Rat) && ck::Is_NOT_Valid(_Script))
        {
            _Rat = Rat;
            _Script = Get_RatScript(Rat);
        }

        auto Result = OutResult;
        Result.Set(ck::IsValid(_Script));
    }

    private void Expect(EMars_PantryRat_Phase InPhase, float32 InSpeed, FName InClip, float32 InRate)
    {
        const auto Clip = _Script.Get_ClipFor(InPhase, InSpeed);
        const auto Rate = _Script.Get_PlayRateFor(Clip, InSpeed);
        Assert_True(Clip == InClip && Math::Abs(Rate - InRate) < 0.001f,
            f"[{InPhase :n}] at {InSpeed} cm/s plays [{InClip}] at rate {InRate} (got [{Clip}] at {Rate})");
    }

    UFUNCTION()
    private void Step_AssertTable(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        const auto Speeds = _Spec.Speeds;
        Expect(EMars_PantryRat_Phase::Emerge, Speeds.Creep, n"Walk", Speeds.Creep / 100.0f);
        Expect(EMars_PantryRat_Phase::ReturnEmpty, Speeds.Creep, n"Walk", Speeds.Creep / 100.0f);
        Expect(EMars_PantryRat_Phase::BoundApproach, Speeds.Approach, n"BoundCycle", Speeds.Approach / 200.0f);
        Expect(EMars_PantryRat_Phase::AvoidPlayer, Speeds.Approach, n"BoundCycle", Speeds.Approach / 200.0f);
        Expect(EMars_PantryRat_Phase::FleeWithLoot, Speeds.LoadedFlee, n"LoadedBound", Speeds.LoadedFlee / 280.0f);
        Expect(EMars_PantryRat_Phase::Observe, 5.0f, n"SniffGround", 1.0f);
        Expect(EMars_PantryRat_Phase::BoundApproach, 10.0f, n"IdleBreath", 1.0f);
        Expect(EMars_PantryRat_Phase::FleeWithLoot, 5.0f, n"LoadedIdle", 1.0f);
        Expect(EMars_PantryRat_Phase::BoundApproach, 400.0f, n"BoundCycle", 1.5f);
        Expect(EMars_PantryRat_Phase::FleeWithLoot, 100.0f, n"LoadedBound", 0.7f);
        Expect(EMars_PantryRat_Phase::BoundApproach, 120.0f, n"Walk", 1.2f);
    }

    UFUNCTION()
    private void OnWatch(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (IsFinished() || ck::Is_NOT_Valid(_Script) || ck::Is_NOT_Valid(_Rat))
        { return; }

        const auto Clip = _Script.Get_PlayingClip();
        if (Clip == NAME_None)
        { return; }

        if (_ClipSequence.Num() == 0 || _ClipSequence.Last() != Clip)
        {
            _ClipSequence.Add(Clip);
            if (Clip == n"LoadedLookBack")
            { ++_FleePauses; }
        }

        const auto Speed = _Script.Get_MeasuredSpeed();
        const auto Rate = _Script.Get_PlayRate();
        const auto Expected = _Script.Get_PlayRateFor(Clip, Speed);
        if (Math::Abs(Rate - Expected) > 0.001f)
        {
            ++_RateMismatches;
            if (_FirstMismatch.IsEmpty())
            { _FirstMismatch = f"[{Clip}] at {Speed} cm/s ran at {Rate}, expected {Expected}"; }
        }

        const auto Phase = _Rat.Get_Phase();
        const auto PhaseName = FName(f"{Phase :n}");
        float32 Max = 0.0f;
        _MaxSpeedByPhase.Find(PhaseName, Max);
        _MaxSpeedByPhase.Add(PhaseName, Math::Max(Max, Speed));
        if (Speed >= constants_pantry_rat_clips::k_MovingSpeed)
        {
            int32 Count = 0;
            _MovingFramesByClip.Find(Clip, Count);
            _MovingFramesByClip.Add(Clip, Count + 1);
        }

        if (Phase == EMars_PantryRat_Phase::Emerge)
        {
            if (Clip == n"Walk")
            { ++_EmergeWalkSamples; }
            if (Clip == n"BoundCycle" || Clip == n"BoundStart")
            { ++_EmergeBoundSamples; }
        }

        if (Phase == EMars_PantryRat_Phase::BoundApproach && Clip == n"BoundCycle" && Math::Abs(Speed - _Spec.Speeds.Approach) < 12.0f)
        {
            ++_BoundSamples;
            _BoundRateSum += Rate;
        }

        if (Phase == EMars_PantryRat_Phase::FleeWithLoot && Clip == n"LoadedBound" && Math::Abs(Speed - _Spec.Speeds.LoadedFlee) < 16.0f)
        {
            ++_LoadedSamples;
            _LoadedRateSum += Rate;
        }
    }

    UFUNCTION()
    private void Check_TwoFleePauses(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_FleePauses >= 2);
    }

    private bool Get_HasPair(FName InFirst, FName InThen) const
    {
        for (int32 Index = 0; Index + 1 < _ClipSequence.Num(); ++Index)
        {
            if (_ClipSequence[Index] == InFirst && _ClipSequence[Index + 1] == InThen)
            { return true; }
        }
        return false;
    }

    UFUNCTION()
    private void Step_AssertLive(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto Sequence = FString();
        for (const auto Clip : _ClipSequence)
        { Sequence += f"{Clip} "; }

        // Every assertion carries the run's numbers (the lane log shows only the first failure's message).
        auto Speeds = FString();
        for (auto Entry : _MaxSpeedByPhase)
        { Speeds += f"{Entry.Key}={Entry.Value} "; }
        auto Moving = FString();
        for (auto Entry : _MovingFramesByClip)
        { Moving += f"{Entry.Key}={Entry.Value} "; }
        Sequence = f"{Sequence}| max speed by phase: {Speeds}| moving frames by clip: {Moving}| bound {_BoundSamples}, loaded "
            + f"{_LoadedSamples}, emerge walk {_EmergeWalkSamples}";

        Assert_Equals_Int(_RateMismatches, 0, f"every frame's play rate is the measured speed over the clip's design speed ({_FirstMismatch})");
        Assert_True(_BoundSamples >= 5, f"mid-burst approach frames played BoundCycle ({_BoundSamples} frames) [{Sequence}]");
        const auto BoundRate = _BoundSamples > 0 ? _BoundRateSum / float64(_BoundSamples) : 0.0;
        Assert_True(Math::Abs(BoundRate - 1.2) < 0.07, f"the approach bound ran near 240 / 200 = 1.2 (mean {BoundRate})");
        Assert_True(_LoadedSamples >= 5, f"mid-burst flee frames played LoadedBound ({_LoadedSamples} frames) [{Sequence}]");
        const auto LoadedRate = _LoadedSamples > 0 ? _LoadedRateSum / float64(_LoadedSamples) : 0.0;
        Assert_True(Math::Abs(LoadedRate - 320.0 / 280.0) < 0.07, f"the loaded bound ran near 320 / 280 = 1.14 (mean {LoadedRate})");
        Assert_True(Get_HasPair(n"BoundStart", n"BoundCycle"), f"a bound from standing opened with BoundStart (clips: {Sequence})");
        Assert_True(Get_HasPair(n"BoundCycle", n"BoundStop"), f"a bound coming to rest closed with BoundStop (clips: {Sequence})");
        Assert_Equals_Int(_EmergeBoundSamples, 0, "the emergence creep never bounds");
        Assert_True(_EmergeWalkSamples >= 1, f"the emergence creep walks ({_EmergeWalkSamples} frames; clips: {Sequence})");
    }
}
