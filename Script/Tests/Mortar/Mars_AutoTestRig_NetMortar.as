// The mortar net tests' shared steps, on the minigame station net rig: the station is the tagged real mortar station with
// the test's Mortar spec (CrushesNeeded 2, GrindSeconds 1.0 and the default timing unless a test says), and each machine
// records, in order, what its copy of the mortar raised from the moment it found it (or from Clear_Record): each signal
// with its frame, each landing's timing, each batch broadcast, and whether its own window was on the marker as each
// strike started; a client also records each rep-notify of the ledger from its find. The server spawns
// Get_MortarStationClass. A hit is a press whose observed sweep puts the window's centre on the marker; a miss one
// whose observed sweep is 0. One [MortarNetTest] line per test per machine.

enum EMars_TESTONLY_NetMortarSignal
{
    StrikeStarted,
    StrikeLanded,
    BatchChanged
}

// A harness fixture: the test mortar station whose authority, as it composes, engages and strikes a hit, so its drain
// starts the strike in the spawn frame. A copy is born into an engaged mortar with one strike started and none landed;
// the mortar's tick lands it a strike's length later.
class UMars_TESTONLY_NetMortarStation_BornStriking_EntityScript : UMars_TESTONLY_NetMortarStation_EntityScript
{
    protected void Compose_AfterKernel(FCk_Handle& InHandle) override
    {
        Super::Compose_AfterKernel(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return; }

        // The sweep that puts the window's centre on the marker.
        const auto Timing = Mortar.Timing;
        const auto HitSweep = Timing.SweepSeconds * (Timing.Marker + Timing.WindowHalfWidth) / (1.0f + 2.0f * Timing.WindowHalfWidth);
        auto MortarHandle = InHandle.As_Mortar();
        MortarHandle.Request_Engage(FMars_Request_Mortar_Engage());
        MortarHandle.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Press, HitSweep));
        MortarHandle.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Release));
    }
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetMortar : UMars_AutoTestRig_NetMinigameStation
{
    // The spawned station's Mortar spec, set by Begin_MortarRig.
    protected FMars_Mortar_Spec _MortarSpec;

    // This machine's copy of the mortar, once found.
    protected FCk_Handle_Mortar _Mortar;

    protected TArray<EMars_TESTONLY_NetMortarSignal> _Signals;
    protected TArray<EMars_Mortar_Strike> _Landings;
    protected TArray<FMars_Mortar_Batch> _Batches;
    protected TArray<bool> _OnMarkerAtStart;
    // In parallel with _Signals: the frame counter at each.
    protected TArray<int64> _SignalFrames;
    // The copy's InitialState as this machine read it when it found the copy.
    protected EMars_Net_InitialState _InitialAtFind = EMars_Net_InitialState::Awaited;
    // Off authority: each rep-notify of the copy's ledger, its frame counter and the ledger as it then read.
    protected TArray<int64> _NotifyFrames;
    protected TArray<FMars_Fragment_Mortar_Net> _NotifyLedgers;

    private int32 _PestleSequence = 0;

    // Call first, on both machines.
    protected void Begin_MortarRig(FCk_Handle InTestEntity, float64 InX)
    {
        auto Spec = FMars_Mortar_Spec();
        Spec.CrushesNeeded = 2;
        Spec.GrindSeconds = 1.0f;
        Configure_Spec(Spec);
        _MortarSpec = Spec;
        Begin_MinigameRig(InTestEntity, InX);
    }

    // A test's own changes to the station's Mortar spec.
    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) {}

    protected FCk_Handle_PendingEntityScript Request_SpawnStation(FCk_Handle InOwner, FTransform InTransform) override
    {
        auto Params = UMars_MortarStation_EntityScript::Params();
        Params.SpawnTransform = InTransform;
        Params.Mortar = _MortarSpec;
        auto Owner = InOwner;
        return utils_entity_script::Request_SpawnEntity(Owner, Get_MortarStationClass(), Params);
    }

    // The station class the server spawns: the test mortar station or a subclass.
    protected TSubclassOf<UCk_EntityScript_UE> Get_MortarStationClass() const
    {
        return UMars_TESTONLY_NetMortarStation_EntityScript;
    }

    protected FName Get_StationTag() const override
    {
        return n"TAG_MarsTestNetMortarStation";
    }

    protected bool Get_IsStationComposed(FCk_Handle_Station InStation) override
    {
        FCk_Handle Entity = InStation;
        return Entity.Is_Mortar();
    }

    protected FString Get_LogTag() const override
    {
        return "MortarNetTest";
    }

    protected void On_StationFound() override
    {
        FCk_Handle Entity = _Station;
        _Mortar = Entity.As_Mortar();
        _Mortar.BindTo_OnStrikeStarted(FMars_Delegate_Mortar_OnStrikeStarted(this, n"OnRigStrikeStarted"));
        _Mortar.BindTo_OnStrikeLanded(FMars_Delegate_Mortar_OnStrikeLanded(this, n"OnRigStrikeLanded"));
        _Mortar.BindTo_OnBatchChanged(FMars_Delegate_Mortar_OnBatchChanged(this, n"OnRigBatchChanged"));
        _InitialAtFind = Get_MortarInitialState();
        if (Get_IsServer() == false)
        { Entity.BindTo_OnRepNotify(FMars_Fragment_Mortar_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRigLedgerNotify")); }
    }

    // This machine's copy's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_MortarInitialState()
    {
        if (ck::Is_NOT_Valid(_Mortar) || _Mortar.Has_Fragment(FMars_Fragment_Mortar_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Mortar.Get_Fragment(FMars_Fragment_Mortar_Local).InitialState;
    }

    protected bool Get_HasFirstNotify() const
    {
        return _NotifyFrames.Num() > 0;
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Mortar_Net Get_FirstNotifyLedger() const
    {
        if (_NotifyLedgers.Num() == 0)
        { return FMars_Fragment_Mortar_Net(); }

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
            Notifies += f"{_NotifyFrames[Index]}:{Ledger.StrikeSerial}/{Ledger.LandedSerial}/{Ledger.Engagement :n} ";
        }

        auto Signals = "";
        for (int32 Index = 0; Index < _Signals.Num(); ++Index)
        {
            const auto Signal = _Signals[Index];
            const auto Letter = Signal == EMars_TESTONLY_NetMortarSignal::StrikeStarted ? "S"
                : (Signal == EMars_TESTONLY_NetMortarSignal::StrikeLanded ? "L" : "B");
            Signals += f"{Letter}@{_SignalFrames[Index]} ";
        }

        return f"found@{_StationFoundFrame} initialAtFind={_InitialAtFind :n} initial={Get_MortarInitialState() :n} "
            + f"notifies=[{Notifies}] signals=[{Signals}]";
    }

    // What this copy raised before is not counted from here on.
    protected void Clear_Record()
    {
        _Signals.Empty();
        _SignalFrames.Empty();
        _Landings.Empty();
        _Batches.Empty();
        _OnMarkerAtStart.Empty();
    }

    protected int32 Get_SignalCount(EMars_TESTONLY_NetMortarSignal InSignal) const
    {
        auto Count = 0;
        for (const auto Signal : _Signals)
        {
            if (Signal == InSignal)
            { ++Count; }
        }

        return Count;
    }

    // The sweep a press must have seen to put the window's centre on the marker.
    protected float32 Get_HitSweep() const
    {
        const auto Timing = _MortarSpec.Timing;
        return Timing.SweepSeconds * (Timing.Marker + Timing.WindowHalfWidth) / (1.0f + 2.0f * Timing.WindowHalfWidth);
    }

    protected float32 Get_MissSweep() const
    {
        return 0.0f;
    }

    protected bool Get_IsWindowOnMarker()
    {
        return utils_mortar::Get_IsOnMarker(_Mortar.Get_Window());
    }

    // How far this machine's window's centre stands from the marker, in bar lengths.
    protected float32 Get_WindowOffMarker()
    {
        const auto Window = _Mortar.Get_Window();
        return Math::Abs(Window.Centre - Window.Marker);
    }

    // The server presses directly on its own copy: a hit is a press at the hit's sweep and a release in one frame.
    protected void Hit_Directly()
    {
        _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Press, Get_HitSweep()));
        _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Release));
    }

    // The subject's edge of the pestle through the station's helper, with the next of this machine's count.
    protected void Pestle_For(EMars_Mortar_PestleVerb InVerb, float32 InSweepSeconds)
    {
        ++_PestleSequence;
        Pestle_ForWithSequence(InVerb, InSweepSeconds, _PestleSequence);
    }

    // The subject's edge of the pestle through the station's helper, with InSequence.
    protected void Pestle_ForWithSequence(EMars_Mortar_PestleVerb InVerb, float32 InSweepSeconds, int32 InSequence)
    {
        utils_mortar::Request_PestleFor(_Mortar, FMars_Mortar_PestleAct(Get_SubjectEntity(), InVerb, InSweepSeconds, InSequence));
    }

    protected FString Get_Label()
    {
        return _Station.Get_ShownLabel().Replace("\n", " / ");
    }

    protected FString Describe_Record()
    {
        FString Text = "signals=[";
        for (const auto Signal : _Signals)
        {
            if (Signal == EMars_TESTONLY_NetMortarSignal::StrikeStarted)
            { Text += "S"; }
            else if (Signal == EMars_TESTONLY_NetMortarSignal::StrikeLanded)
            { Text += "L"; }
            else
            { Text += "B"; }
        }

        Text += "] landings=[";
        for (const auto Landing : _Landings)
        { Text += Landing == EMars_Mortar_Strike::Hit ? "H" : "M"; }

        Text += "] batches=[";
        for (const auto& Batch : _Batches)
        { Text += f"{int32(Batch.Seasoning)}/{int32(Batch.Phase)}/{Batch.CrushHits} "; }

        return Text + "]";
    }

    protected FString Describe_Ledger(const FMars_Fragment_Mortar_Net& InLedger)
    {
        return f"eng={int32(InLedger.Engagement)} seas={int32(InLedger.Batch.Seasoning)} phase={int32(InLedger.Batch.Phase)} hits={InLedger.Batch.CrushHits} "
            + f"grind={InLedger.Batch.GrindProgress} motion={int32(InLedger.Motion)} sweepSerial={InLedger.SweepSerial} anchor={InLedger.AnchorServerSeconds} "
            + f"sweepAt={InLedger.SweepAtAnchor} strikes={InLedger.StrikeSerial} landed={InLedger.LandedSerial} last={int32(InLedger.LastLanded)}";
    }

    protected FString Describe_Mortar()
    {
        if (ck::Is_NOT_Valid(_Mortar))
        { return "no mortar"; }

        const auto Batch = _Mortar.Get_Batch();
        return f"engaged={_Mortar.Get_IsEngaged()} seas={int32(Batch.Seasoning)} phase={int32(Batch.Phase)} hits={Batch.CrushHits} "
            + f"grind={Batch.GrindProgress} pestle={int32(_Mortar.Get_Pestle())} sweep={_Mortar.Get_SweepSeconds()} label='{Get_Label()}' "
            + f"ledger[{Describe_Ledger(_Mortar.Get_Ledger())}]";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Handlers
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnRigStrikeStarted(FCk_Handle_Mortar InMortar)
    {
        _Signals.Add(EMars_TESTONLY_NetMortarSignal::StrikeStarted);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        _OnMarkerAtStart.Add(Get_IsWindowOnMarker());
        Log_Minigame(f"strike started frame={utils_time::Get_FrameCounter()} onMarker={Get_IsWindowOnMarker()}");
    }

    UFUNCTION()
    private void OnRigStrikeLanded(FCk_Handle_Mortar InMortar, EMars_Mortar_Strike InStrike)
    {
        _Signals.Add(EMars_TESTONLY_NetMortarSignal::StrikeLanded);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        _Landings.Add(InStrike);
    }

    UFUNCTION()
    private void OnRigBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch)
    {
        _Signals.Add(EMars_TESTONLY_NetMortarSignal::BatchChanged);
        _SignalFrames.Add(utils_time::Get_FrameCounter());
        _Batches.Add(InBatch);
    }

    // A notify can land on a station already ending.
    UFUNCTION()
    private void OnRigLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Mortar_Net) == false)
        { return; }

        _NotifyFrames.Add(utils_time::Get_FrameCounter());
        _NotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Mortar_Net));
    }
}
