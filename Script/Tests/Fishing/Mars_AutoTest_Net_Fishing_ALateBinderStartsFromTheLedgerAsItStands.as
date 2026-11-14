// The server spawns a fishing station that engages, aims and casts as it composes; once Waiting it forces a bite and
// strikes; it holds 4 s, forces the landing and reports once its spot reads Landed. The client's copy is born into the
// engaged, aimed spot with its cast in flight: its rod is at the ledger's aim from that first application, and it
// raises the phase it was born into there, then the bite, its end, and the landing once each, never that cast. Once
// its ledger reads Reeling with one cast its bait lies within 5 cm of the ledger's and it has a line out.
// Surface: Ck.Fishing.Net.AS_Fishing_ALateBinderStartsFromTheLedgerAsItStands
class UCk_AutoTest_Net_Fishing_ALateBinderStartsFromTheLedgerAsItStands : UMars_AutoTestRig_NetFishing
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 468000.0;
    private const float32 k_HoldSeconds = 4.0f;
    private const float64 k_MaxBaitErrorCm = 5.0;
    private const float32 k_MaxAimErrorDeg = 0.01f;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_FishingRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { WaitUntil(n"Is_ClientLedgerReeling", n"OnClientLedgerReeling", k_SlowPolls); }
    }

    protected TSubclassOf<UCk_EntityScript_UE> Get_FishingStationClass() const override
    {
        return UMars_TESTONLY_NetFishingStation_BornCasting_EntityScript;
    }

    // The server can find its station before the spawn frame's drain has run: it reads its ledger.
    protected EMars_TESTONLY_NetMinigameFound On_ServerStationFound() override
    {
        Log_Minigame(f"found: {Describe_Find()} ledger[{Describe_Ledger(_Fishing.Get_Ledger())}]");
        WaitUntil(n"Is_ServerLedgerOneCast", n"OnServerLedgerOneCast", k_SlowPolls);
        return EMars_TESTONLY_NetMinigameFound::TestContinues;
    }

    UFUNCTION()
    private void Is_ServerLedgerOneCast(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Fishing.Get_Ledger().CastSerial >= 1);
    }

    UFUNCTION()
    private void OnServerLedgerOneCast(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Origin = _Fishing.Get_Ledger().CastOrigin;
        const auto Station = Get_StationLocation();
        Log_Minigame(f"cast origin={Origin} station={Station} distance={Origin.Distance(Station)} frame={utils_time::Get_FrameCounter()}");
        Await_Phase(EMars_Fishing_Phase::Waiting, n"OnServerWaiting");
    }

    UFUNCTION()
    private void OnServerWaiting(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceBite(FMars_Request_Fishing_ForceBite());
        _Fishing.Request_Hook(FMars_Request_Fishing_Hook());
        WaitSeconds(k_HoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _Fishing.Request_ForceLand(FMars_Request_Fishing_ForceLand());
        Await_Phase(EMars_Fishing_Phase::Landed, n"OnServerLanded");
    }

    UFUNCTION()
    private void OnServerLanded(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Report_Step(FMars_TESTONLY_NetMinigameStep(1));
        End_FishingServer(f"{Describe_Find()} {Describe_Record()} {Describe_Fishing()}");
    }

    // Quiet once the copy is gone: Try_FindStation only finds a live one.
    UFUNCTION()
    private void Is_ClientLedgerReeling(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Try_FindStation() == false)
        {
            Result.Set(false);
            return;
        }

        const auto Ledger = _Fishing.Get_Ledger();
        Result.Set(Ledger.Phase == EMars_Fishing_Phase::Reeling && Ledger.CastSerial == 1);
    }

    UFUNCTION()
    private void OnClientLedgerReeling(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Bait = _Fishing.Get_Bait().Position;
        const auto Expected = _Fishing.Get_Ledger().BaitPosition;
        Assert_True(Bait.Distance(Expected) <= k_MaxBaitErrorCm, f"the client's bait lies on the ledger's ({Bait} vs {Expected})");
        Assert_True(_Fishing.Get_HasLineOut(), f"the client has a line out once its ledger reads Reeling ({Describe_Fishing()})");
        Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled);
    }

    protected void On_ClientStep(int32 InStep) override
    {
        const auto First = Get_FirstNotifyLedger();
        const auto FirstFrame = Get_FirstNotifyFrame();
        const auto Ledger = _Fishing.Get_Ledger();
        const auto Snap = Describe_Snap(First, FirstFrame);
        const auto Line = f"{Describe_Find()} {Snap} {Describe_Record()} {Describe_Fishing()}";
        Assert_True(Get_FishingInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_InitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(Get_HasFirstNotify(), f"the client recorded a rep-notify of its copy's ledger ({Line})");
        Assert_True(First.CastSerial == 1 && First.Phase == EMars_Fishing_Phase::Casting
            && First.Engagement == EMars_Fishing_Engagement::Engaged && Get_IsAim(First.Aim, Get_BornAim()),
            f"the first notify carried the engaged, aimed spot and the cast it was born into ({Line})");

        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnCast), Ledger.CastSerial - First.CastSerial,
            f"the client raised only the casts after its first notify ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBite), Ledger.BiteSerial - First.BiteSerial,
            f"the client raised only the bites after its first notify ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnBiteEnded), Ledger.BiteEndSerial - First.BiteEndSerial,
            f"the client raised only the bite ends after its first notify ({Line})");
        Assert_True(_BiteEnds.Num() > 0 && _BiteEnds[0] == EMars_Fishing_BiteResult::Hooked, f"the client's bite ended Hooked ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnLanded), Ledger.LandedSerial - First.LandedSerial,
            f"the client raised only the landings after its first notify ({Line})");
        Assert_Equals_Int(Get_SignalCount(EMars_TESTONLY_NetFishingSignal::OnCollected), 0, f"the client raised no OnCollected ({Line})");

        const auto FirstPhaseFrame = Get_FirstPhaseFrame();
        Assert_True(_Phases.Num() > 0 && _Phases[0] == EMars_Fishing_Phase::Casting && FirstPhaseFrame == FirstFrame,
            f"the first phase the client raised is Casting, in its first notify's frame ({Line})");

        Assert_True(Count_SnapSamples(First, FirstFrame) > 0, f"the client sampled its aim against the first notify's ({Line})");
        Assert_Equals_Int(Count_OffSnapSamples(First, FirstFrame), 0,
            f"the client's aim stood at the ledger's from its first notify ({Line})");
        End_FishingClient(Line);
    }

    private FMars_Fishing_Aim Get_BornAim() const
    {
        auto Aim = FMars_Fishing_Aim();
        Aim.YawDeg = _FishingSpec.Launch.YawHalfAngleDeg * 0.5f;
        return Aim;
    }

    private bool Get_IsAim(FMars_Fishing_Aim InAim, FMars_Fishing_Aim InExpected) const
    {
        return Math::Abs(InAim.YawDeg - InExpected.YawDeg) <= k_MaxAimErrorDeg
            && Math::Abs(InAim.PitchDeg - InExpected.PitchDeg) <= k_MaxAimErrorDeg;
    }

    // The frame of the first OnPhaseChanged recorded; -1 when none.
    private int64 Get_FirstPhaseFrame() const
    {
        for (int32 Index = 0; Index < _Signals.Num(); ++Index)
        {
            if (_Signals[Index] == EMars_TESTONLY_NetFishingSignal::OnPhaseChanged)
            { return _SignalFrames[Index]; }
        }

        return -1;
    }

    // Samples from InFirstFrame on whose ledger aim reads InFirst's.
    private int32 Count_SnapSamples(const FMars_Fragment_Fishing_Net& InFirst, int64 InFirstFrame) const
    {
        auto Count = 0;
        for (const auto& Sample : _Samples)
        {
            if (Sample.Frame >= InFirstFrame && Get_IsAim(Sample.Ledger.Aim, InFirst.Aim))
            { ++Count; }
        }

        return Count;
    }

    // Of those, the ones whose own aim is off the ledger's.
    private int32 Count_OffSnapSamples(const FMars_Fragment_Fishing_Net& InFirst, int64 InFirstFrame) const
    {
        auto Count = 0;
        for (const auto& Sample : _Samples)
        {
            if (Sample.Frame >= InFirstFrame && Get_IsAim(Sample.Ledger.Aim, InFirst.Aim) && Get_IsAim(Sample.Aim, InFirst.Aim) == false)
            { ++Count; }
        }

        return Count;
    }

    private FString Describe_Snap(const FMars_Fragment_Fishing_Net& InFirst, int64 InFirstFrame) const
    {
        auto Off = "";
        for (const auto& Sample : _Samples)
        {
            if (Sample.Frame >= InFirstFrame && Get_IsAim(Sample.Ledger.Aim, InFirst.Aim) && Get_IsAim(Sample.Aim, InFirst.Aim) == false)
            { Off += f"{Sample.Frame}:{Sample.Aim.YawDeg} "; }
        }

        return f"snap samples={Count_SnapSamples(InFirst, InFirstFrame)} off=[{Off}] firstAim={InFirst.Aim.YawDeg}/{InFirst.Aim.PitchDeg}";
    }
}
