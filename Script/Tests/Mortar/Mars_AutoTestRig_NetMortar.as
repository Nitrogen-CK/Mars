// The mortar net tests' shared steps, on the minigame station net rig: the station is the tagged real mortar station with
// the test's Mortar spec (CrushesNeeded 2, GrindSeconds 1.0 and the default timing unless a test says), and each machine
// records, in order, what its copy of the mortar raised from the moment it found it (or from Clear_Record): each signal,
// each landing's timing, each batch broadcast, and whether its own window was on the marker as each strike started. A hit
// is a press whose observed sweep puts the window's centre on the marker; a miss one whose observed sweep is 0. One
// [MortarNetTest] line per test per machine.

enum EMars_TESTONLY_NetMortarSignal
{
    StrikeStarted,
    StrikeLanded,
    BatchChanged
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
        return utils_entity_script::Request_SpawnEntity(Owner, UMars_TESTONLY_NetMortarStation_EntityScript, Params);
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
    }

    // What this copy raised before is not counted from here on.
    protected void Clear_Record()
    {
        _Signals.Empty();
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
        _OnMarkerAtStart.Add(Get_IsWindowOnMarker());
        Log_Minigame(f"strike started frame={utils_time::Get_FrameCounter()} onMarker={Get_IsWindowOnMarker()}");
    }

    UFUNCTION()
    private void OnRigStrikeLanded(FCk_Handle_Mortar InMortar, EMars_Mortar_Strike InStrike)
    {
        _Signals.Add(EMars_TESTONLY_NetMortarSignal::StrikeLanded);
        _Landings.Add(InStrike);
    }

    UFUNCTION()
    private void OnRigBatchChanged(FCk_Handle_Mortar InMortar, FMars_Mortar_Batch InBatch)
    {
        _Signals.Add(EMars_TESTONLY_NetMortarSignal::BatchChanged);
        _Batches.Add(InBatch);
    }
}
