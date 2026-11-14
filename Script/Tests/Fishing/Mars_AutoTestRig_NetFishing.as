// The fishing net tests' shared steps, on the minigame station net rig: the station is the tagged real fishing station with
// the single-machine rig's short spec (a 600 cm cast, a fast reel, no runs, one fish) except that a bite comes only when a
// test forces one. Each machine records, in order, what its copy of the spot raised from the moment it found it (or from
// Clear_Record): the seven signals a copy without authority raises, with each phase, bite end and presence they carried. A
// sampler takes the bait, the line, the aim, the fling, the presence and the ledger on every call of its tick (twice in a
// frame when the frame is ticked twice). A point (the bait, the catch point) goes out in a second test-only replicated
// report on the subject, written with the step that names it. Each signal is recorded with its frame, and a client also
// records each rep-notify of the ledger from its find. The server spawns Get_FishingStationClass. One [FishingNetTest]
// line per test per machine.

// A real fishing station that only tags its root, so each machine finds its copy.
class UMars_TESTONLY_NetFishingStation_EntityScript : UMars_FishingStation_EntityScript
{
    protected void AddVisuals(FCk_Handle_Transform& InRoot) override
    {
        Super::AddVisuals(InRoot);
        utils_entity_tag::Add(InRoot.H(), n"TAG_MarsTestNetFishingStation");
    }
}

// A harness fixture: the test fishing station whose authority, as it composes, engages, aims half its yaw range to
// one side and casts at full power, so its drain launches the cast in the spawn frame. A copy is born into an engaged,
// aimed spot with one cast in flight; the spot's tick flies it.
class UMars_TESTONLY_NetFishingStation_BornCasting_EntityScript : UMars_TESTONLY_NetFishingStation_EntityScript
{
    protected void Compose_AfterKernel(FCk_Handle& InHandle) override
    {
        Super::Compose_AfterKernel(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        auto Spot = InHandle.As_Fishing();
        Spot.Request_Engage(FMars_Request_Fishing_Engage());
        Spot.Request_Aim(FMars_Request_Fishing_Aim(Fishing.Launch.YawHalfAngleDeg * 0.5f, 0.0f));
        Spot.Request_Cast(FMars_Request_Fishing_Cast(1.0f));
    }
}

enum EMars_TESTONLY_NetFishingSignal
{
    OnCast,
    OnBite,
    OnBiteEnded,
    OnLanded,
    OnCollected,
    OnPhaseChanged,
    OnPresenceChanged
}

// The ledger's paced values and its reel, as one sample saw them.
struct FMars_TESTONLY_NetFishingLedgerSample
{
    FMars_Fishing_Line Line;
    FMars_Fishing_Aim Aim;
    EMars_Fishing_Reel Reel = EMars_Fishing_Reel::Released;
}

struct FMars_TESTONLY_NetFishingSample
{
    int64 Frame = 0;
    EMars_Fishing_Phase Phase = EMars_Fishing_Phase::Idle;
    FMars_Fishing_Bait Bait;
    FMars_Fishing_Line Line;
    FMars_Fishing_Aim Aim;
    float32 FlingAlpha = 0.0f;
    float32 PresenceAlpha = 1.0f;
    FMars_TESTONLY_NetFishingLedgerSample Ledger;
}

// Written by the server only, through Get_Fragment + Request_MarkReplicationDirty (test-only).
struct FMars_Fragment_TESTONLY_NetFishingPoint
{
    UPROPERTY()
    FVector Point;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetFishing : UMars_AutoTestRig_NetMinigameStation
{
    // The spawned station's Fishing spec, set by Begin_FishingRig.
    protected FMars_Fishing_Spec _FishingSpec;

    // This machine's copy of the spot, once found.
    protected FCk_Handle_Fishing _Fishing;

    protected TArray<EMars_TESTONLY_NetFishingSignal> _Signals;
    protected TArray<EMars_Fishing_Phase> _Phases;
    protected TArray<EMars_Fishing_BiteResult> _BiteEnds;
    protected TArray<EMars_Fishing_Presence> _Presences;
    protected TArray<FMars_TESTONLY_NetFishingSample> _Samples;
    // In parallel with _Signals: the frame counter at each.
    protected TArray<int64> _SignalFrames;
    // The copy's InitialState as this machine read it when it found the copy.
    protected EMars_Net_InitialState _InitialAtFind = EMars_Net_InitialState::Awaited;
    // Off authority: each rep-notify of the copy's ledger, its frame counter and the ledger as it then read.
    protected TArray<int64> _NotifyFrames;
    protected TArray<FMars_Fragment_Fishing_Net> _NotifyLedgers;

    // Frames a seated test gives the station's phase machine to read a phase before it moves the spot on.
    protected const int32 k_SmSettleFrames = 5;

    private FCk_Handle_Timer _FishingSampler;
    private EMars_Fishing_Phase _AwaitedPhase = EMars_Fishing_Phase::Idle;

    // Call first, on both machines.
    protected void Begin_FishingRig(FCk_Handle InTestEntity, float64 InX)
    {
        auto Spec = Make_NetSpec();
        Configure_Spec(Spec);
        _FishingSpec = Spec;

        auto Subject = Get_SubjectEntity();
        if (Subject.Has_Fragment(FMars_Fragment_TESTONLY_NetFishingPoint) == false)
        { Subject.Add_Fragment(FMars_Fragment_TESTONLY_NetFishingPoint(), ECk_Replication::Replicates); }

        _FishingSampler = utils_timer::Create_Tick(InTestEntity, FCk_Delegate_Timer(this, n"OnFishingSample"));
        Begin_MinigameRig(InTestEntity, InX);
    }

    // The single-machine rig's spec, with the bite left to the tests.
    private FMars_Fishing_Spec Make_NetSpec() const
    {
        auto Spec = FMars_Fishing_Spec();
        Spec.Launch.MaxDistanceCm = 600.0f;
        Spec.Launch.MinDistanceCm = 100.0f;
        Spec.Bite.MinWaitSeconds = 60.0f;
        Spec.Bite.MaxWaitSeconds = 60.0f;
        Spec.Bite.HookWindowSeconds = 2.0f;
        Spec.Bite.MissPenaltySeconds = 0.25f;
        Spec.Reel.ReelSpeedCmPerS = 400.0f;
        Spec.Reel.HookSetSeconds = 0.1f;
        Spec.Run.MinGapSeconds = 100.0f;
        Spec.Run.MaxGapSeconds = 100.0f;
        Spec.Run.MinRunSeconds = 0.5f;
        Spec.Run.MaxRunSeconds = 0.5f;
        Spec.Run.PullCmPerS = 0.0f;
        Spec.Fish.Table.Add(FMars_Fishing_FishEntry(mars_items::Food_MeatSlab(), 1.0f, 1.0f));
        Spec.Fish.LandFlingSeconds = 0.3f;
        Spec.Water.SurfaceZ = 0.0;
        Spec.Seed = 7;
        return Spec;
    }

    // A test's own changes to the station's Fishing spec.
    protected void Configure_Spec(FMars_Fishing_Spec& InOutSpec) {}

    protected FCk_Handle_PendingEntityScript Request_SpawnStation(FCk_Handle InOwner, FTransform InTransform) override
    {
        auto Params = UMars_FishingStation_EntityScript::Params();
        Params.SpawnTransform = InTransform;
        Params.Fishing = _FishingSpec;
        auto Owner = InOwner;
        return utils_entity_script::Request_SpawnEntity(Owner, Get_FishingStationClass(), Params);
    }

    // The station class the server spawns: the test fishing station or a subclass.
    protected TSubclassOf<UCk_EntityScript_UE> Get_FishingStationClass() const
    {
        return UMars_TESTONLY_NetFishingStation_EntityScript;
    }

    protected FName Get_StationTag() const override
    {
        return n"TAG_MarsTestNetFishingStation";
    }

    protected bool Get_IsStationComposed(FCk_Handle_Station InStation) override
    {
        FCk_Handle Entity = InStation;
        return Entity.Is_Fishing();
    }

    protected FString Get_LogTag() const override
    {
        return "FishingNetTest";
    }

    protected void On_StationFound() override
    {
        FCk_Handle Entity = _Station;
        _Fishing = Entity.As_Fishing();
        _Fishing.BindTo_OnCast(FMars_Delegate_Fishing_OnCast(this, n"OnRigCast"));
        _Fishing.BindTo_OnBite(FMars_Delegate_Fishing_OnBite(this, n"OnRigBite"));
        _Fishing.BindTo_OnBiteEnded(FMars_Delegate_Fishing_OnBiteEnded(this, n"OnRigBiteEnded"));
        _Fishing.BindTo_OnLanded(FMars_Delegate_Fishing_OnLanded(this, n"OnRigLanded"));
        _Fishing.BindTo_OnCollected(FMars_Delegate_Fishing_OnCollected(this, n"OnRigCollected"));
        _Fishing.BindTo_OnPhaseChanged(FMars_Delegate_Fishing_OnPhaseChanged(this, n"OnRigPhaseChanged"));
        _Fishing.BindTo_OnPresenceChanged(FMars_Delegate_Fishing_OnPresenceChanged(this, n"OnRigPresenceChanged"));
        _InitialAtFind = Get_FishingInitialState();
        if (Get_IsServer() == false)
        { Entity.BindTo_OnRepNotify(FMars_Fragment_Fishing_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRigLedgerNotify")); }
    }

    // This machine's copy's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_FishingInitialState()
    {
        if (ck::Is_NOT_Valid(_Fishing) || _Fishing.Has_Fragment(FMars_Fragment_Fishing_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Fishing.Get_Fragment(FMars_Fragment_Fishing_Local).InitialState;
    }

    protected bool Get_HasFirstNotify() const
    {
        return _NotifyFrames.Num() > 0;
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Fishing_Net Get_FirstNotifyLedger() const
    {
        if (_NotifyLedgers.Num() == 0)
        { return FMars_Fragment_Fishing_Net(); }

        return _NotifyLedgers[0];
    }

    protected int64 Get_FirstNotifyFrame() const
    {
        if (_NotifyFrames.Num() == 0)
        { return -1; }

        return _NotifyFrames[0];
    }

    // Signals recorded in InFrame.
    protected int32 Get_SignalsInFrame(int64 InFrame) const
    {
        auto Count = 0;
        for (const auto Frame : _SignalFrames)
        {
            if (Frame == InFrame)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_Find()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _NotifyFrames.Num(); ++Index)
        {
            const auto& Ledger = _NotifyLedgers[Index];
            Notifies += f"{_NotifyFrames[Index]}:{Ledger.CastSerial}/{Ledger.BiteSerial}/{Ledger.BiteEndSerial}/{Ledger.LandedSerial}"
                + f"/{Ledger.CollectedSerial}/{Ledger.PhaseSerial}({Ledger.Phase :n},{Ledger.Engagement :n},aim={Ledger.Aim.YawDeg}) ";
        }

        auto Signals = "";
        for (int32 Index = 0; Index < _Signals.Num(); ++Index)
        { Signals += f"{Describe_Signal(_Signals[Index])}@{_SignalFrames[Index]} "; }

        return f"found@{_StationFoundFrame} initialAtFind={_InitialAtFind :n} initial={Get_FishingInitialState() :n} "
            + f"notifies=[{Notifies}] signals=[{Signals}]";
    }

    // What this copy raised before is not counted from here on.
    protected void Clear_Record()
    {
        _Signals.Empty();
        _SignalFrames.Empty();
        _Phases.Empty();
        _BiteEnds.Empty();
        _Presences.Empty();
    }

    protected int32 Get_SignalCount(EMars_TESTONLY_NetFishingSignal InSignal) const
    {
        auto Count = 0;
        for (const auto Signal : _Signals)
        {
            if (Signal == InSignal)
            { ++Count; }
        }

        return Count;
    }

    // The index of the first InPhase in the phases raised at or after InFrom; -1 when none.
    protected int32 Find_Phase(EMars_Fishing_Phase InPhase, int32 InFrom) const
    {
        for (int32 Index = Math::Max(InFrom, 0); Index < _Phases.Num(); ++Index)
        {
            if (_Phases[Index] == InPhase)
            { return Index; }
        }

        return -1;
    }

    protected int32 Count_Phase(EMars_Fishing_Phase InPhase) const
    {
        auto Count = 0;
        for (const auto Phase : _Phases)
        {
            if (Phase == InPhase)
            { ++Count; }
        }

        return Count;
    }

    protected float64 Get_HorizontalDistance(FVector InA, FVector InB) const
    {
        return FVector(InA.X - InB.X, InA.Y - InB.Y, 0.0).Size();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The point report
    //----------------------------------------------------------------------------------------------------------------------

    // Server: InPoint out to the client; call with the step that names it.
    protected void Report_Point(FVector InPoint)
    {
        auto Subject = Get_SubjectEntity();
        Subject.Get_Fragment(FMars_Fragment_TESTONLY_NetFishingPoint).Point = InPoint;
        Subject.Request_MarkReplicationDirty(FMars_Fragment_TESTONLY_NetFishingPoint);
        Log_Minigame(f"point {InPoint}");
    }

    protected FVector Get_ReportedPoint()
    {
        return Get_SubjectEntity().Get_Fragment(FMars_Fragment_TESTONLY_NetFishingPoint).Point;
    }

    // The world items lying within InRadius of InPoint across the ground (nothing has a floor); the server tracks each one
    // it counts.
    protected int32 Count_WorldItemsNear(FVector InPoint, float64 InRadius)
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsLive(Candidate) == false || ck::Is_NOT_Valid(Candidate.As_WorldItem(ECk_SanityCheck::UnChecked)))
            { continue; }

            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            const auto Location = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation();
            if (Get_HorizontalDistance(Location, InPoint) > InRadius)
            { continue; }

            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            Count += 1;
        }

        return Count;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Waits
    //----------------------------------------------------------------------------------------------------------------------

    // InContinuation once this machine's spot reads InPhase.
    protected void Await_Phase(EMars_Fishing_Phase InPhase, FName InContinuation)
    {
        _AwaitedPhase = InPhase;
        WaitUntil(n"Is_RigPhase", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigPhase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindStation() && _Fishing.Get_Phase() == _AwaitedPhase);
    }

    // InContinuation once this machine's spot reads engaged.
    protected void Await_Engaged(FName InContinuation)
    {
        WaitUntil(n"Is_RigEngaged", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    private void Is_RigEngaged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Try_FindStation() && _Fishing.Get_IsEngaged());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Descriptions
    //----------------------------------------------------------------------------------------------------------------------

    protected FString Describe_Record()
    {
        FString Text = "signals=[";
        for (const auto Signal : _Signals)
        { Text += Describe_Signal(Signal); }

        Text += "] phases=[";
        for (const auto Phase : _Phases)
        { Text += f"{Phase :n} "; }

        Text += "] biteEnds=[";
        for (const auto BiteEnd : _BiteEnds)
        { Text += f"{BiteEnd :n} "; }

        Text += "] presences=[";
        for (const auto Presence : _Presences)
        { Text += f"{Presence :n} "; }

        return Text + f"] samples={_Samples.Num()}";
    }

    protected FString Describe_Signal(EMars_TESTONLY_NetFishingSignal InSignal) const
    {
        switch (InSignal)
        {
            case EMars_TESTONLY_NetFishingSignal::OnCast: return "C";
            case EMars_TESTONLY_NetFishingSignal::OnBite: return "B";
            case EMars_TESTONLY_NetFishingSignal::OnBiteEnded: return "E";
            case EMars_TESTONLY_NetFishingSignal::OnLanded: return "L";
            case EMars_TESTONLY_NetFishingSignal::OnCollected: return "K";
            case EMars_TESTONLY_NetFishingSignal::OnPhaseChanged: return "p";
            default: return "q";
        }

        return "q";
    }

    protected FString Describe_Ledger(const FMars_Fragment_Fishing_Net& InLedger)
    {
        return f"eng={InLedger.Engagement :n} phase={InLedger.Phase :n}/{InLedger.PhaseSerial} pres={InLedger.Presence :n}@{InLedger.PresenceAnchorServerSeconds} "
            + f"reel={InLedger.Reel :n} run={InLedger.Run :n} aim={InLedger.Aim.YawDeg}/{InLedger.Aim.PitchDeg} line={InLedger.Line.LengthCm}/{InLedger.Line.Tension} "
            + f"cast={InLedger.CastSerial} o={InLedger.CastOrigin} v={InLedger.CastVelocity} @{InLedger.CastAnchorServerSeconds} bait={InLedger.BaitPosition} "
            + f"dip={InLedger.DipCm} catch={InLedger.CatchIndex} at={InLedger.LandedAt} @{InLedger.LandedAnchorServerSeconds} tally={InLedger.Tally} "
            + f"bites={InLedger.BiteSerial} ends={InLedger.BiteEndSerial}/{InLedger.LastBiteEnd :n} landed={InLedger.LandedSerial} collected={InLedger.CollectedSerial}";
    }

    protected FString Describe_Fishing()
    {
        if (ck::Is_NOT_Valid(_Fishing))
        { return "no spot"; }

        const auto Aim = _Fishing.Get_Aim();
        return f"engaged={_Fishing.Get_IsEngaged()} phase={_Fishing.Get_Phase() :n} pres={_Fishing.Get_Presence() :n} reel={_Fishing.Get_Reel() :n} "
            + f"aim={Aim.YawDeg}/{Aim.PitchDeg} line={_Fishing.Get_LineLengthCm()}/{_Fishing.Get_Tension()} bait={_Fishing.Get_Bait().Position} "
            + f"tally={_Fishing.Get_Tally()} ledger[{Describe_Ledger(_Fishing.Get_Ledger())}]";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The sampler and the endings
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnFishingSample(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        if (Try_FindStation() == false || ck::Is_NOT_Valid(_Fishing))
        { return; }

        const auto Ledger = _Fishing.Get_Ledger();
        auto Sample = FMars_TESTONLY_NetFishingSample();
        Sample.Frame = utils_time::Get_FrameCounter();
        Sample.Phase = _Fishing.Get_Phase();
        Sample.Bait = _Fishing.Get_Bait();
        Sample.Line = _Fishing.Get_Line();
        Sample.Aim = _Fishing.Get_Aim();
        Sample.FlingAlpha = _Fishing.Get_FlingAlpha();
        Sample.PresenceAlpha = _Fishing.Get_PresenceAlpha();
        Sample.Ledger.Line = Ledger.Line;
        Sample.Ledger.Aim = Ledger.Aim;
        Sample.Ledger.Reel = Ledger.Reel;
        _Samples.Add(Sample);
    }

    private void End_FishingSampling()
    {
        if (ck::Is_NOT_Valid(_FishingSampler))
        { return; }

        utils_timer::UnbindFrom_OnUpdate(_FishingSampler, FCk_Delegate_Timer(this, n"OnFishingSample"));
        utils_entity_lifetime::Request_DestroyEntity(_FishingSampler.H());
        _FishingSampler = FCk_Handle_Timer();
    }

    protected void End_FishingServer(FString InText)
    {
        End_FishingSampling();
        End_MinigameServer(InText);
    }

    protected void End_FishingClient(FString InText)
    {
        End_FishingSampling();
        End_MinigameClient(InText);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRigCast(FCk_Handle_Fishing InFishing, FVector InLaunchVelocity)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnCast);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        Log_Minigame(f"cast frame={utils_time::Get_FrameCounter()} velocity={InLaunchVelocity}");
    }

    UFUNCTION()
    private void OnRigBite(FCk_Handle_Fishing InFishing)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnBite);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRigBiteEnded(FCk_Handle_Fishing InFishing, EMars_Fishing_BiteResult InResult)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnBiteEnded);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        _BiteEnds.Add(InResult);
    }

    UFUNCTION()
    private void OnRigLanded(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnLanded);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRigCollected(FCk_Handle_Fishing InFishing, FMars_Fishing_Catch InCatch)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnCollected);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    private void OnRigPhaseChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Phase InPhase)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnPhaseChanged);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        _Phases.Add(InPhase);
    }

    UFUNCTION()
    private void OnRigPresenceChanged(FCk_Handle_Fishing InFishing, EMars_Fishing_Presence InPresence)
    {
        _Signals.Add(EMars_TESTONLY_NetFishingSignal::OnPresenceChanged);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        _Presences.Add(InPresence);
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnRigLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Fishing_Net) == false)
        { return; }

        _NotifyFrames.Add(utils_time::Get_FrameCounter());
        _NotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Fishing_Net));
    }
}
