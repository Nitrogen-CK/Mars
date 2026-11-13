// One hit cracks the batch and the grind takes 3 s. The server engages and strikes a hit directly; once the phase is Grind
// it presses directly and counts the distinct anchors its ledger takes until the batch is Done (3 or fewer), then reports.
// The client read its pestle Grinding, its grind's progress rose over at least 20 sampled frames in a row and never passed
// 1, and at the report its batch is Done with its progress exactly 1, having raised OnBatchChanged with Done once.
// Surface: Ck.Mortar.Net.AS_Mortar_TheGrindFillsOnTheClientBetweenPublishes
class UCk_AutoTest_Net_Mortar_TheGrindFillsOnTheClientBetweenPublishes : UMars_AutoTestRig_NetMortar
{
    default _TimeoutSeconds = 25.0f;

    private const float64 k_X = 443000.0;
    private const int32 k_MaxAnchors = 3;
    private const int32 k_RisingFrames = 20;

    // Server: the anchors its ledger took since the grind's press.
    private int32 _Anchors = 0;
    private float64 _LastAnchor = 0.0;
    private bool _IsCounting = false;

    // Client.
    private bool _SawGrinding = false;
    private float32 _LastProgress = -1.0f;
    private int32 _Rising = 0;
    private int32 _LongestRising = 0;
    private float32 _HighestProgress = 0.0f;

    protected void Configure_Spec(FMars_Mortar_Spec& InOutSpec) override
    {
        InOutSpec.CrushesNeeded = 1;
        InOutSpec.GrindSeconds = 3.0f;
    }

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        Begin_MortarRig(InHandle, k_X);
        if (Get_IsServer() == false)
        { Await_Step(1, EMars_TESTONLY_NetMinigameArrival::Settled); }
    }

    protected void On_ServerStationReady() override
    {
        _Mortar.Request_Engage(FMars_Request_Mortar_Engage());
        Hit_Directly();
        WaitUntil(n"Is_ServerGrindPhase", n"OnServerGrindPhase", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerGrindPhase(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Batch().Phase == EMars_Mortar_Phase::Grind);
    }

    UFUNCTION()
    private void OnServerGrindPhase(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _LastAnchor = _Mortar.Get_Ledger().AnchorServerSeconds;
        _IsCounting = true;
        _Mortar.Request_Pestle(FMars_Request_Mortar_Pestle(EMars_Mortar_PestleVerb::Press));
        WaitUntil(n"Is_ServerDone", n"OnServerDone", k_SlowPolls);
    }

    private void Count_Anchor()
    {
        if (_IsCounting == false)
        { return; }

        const auto Anchor = _Mortar.Get_Ledger().AnchorServerSeconds;
        if (Anchor == _LastAnchor)
        { return; }

        _LastAnchor = Anchor;
        ++_Anchors;
    }

    UFUNCTION()
    private void Is_ServerDone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Count_Anchor();
        auto Result = OutResult;
        Result.Set(_Mortar.Get_Ledger().Batch.Phase == EMars_Mortar_Phase::Done);
    }

    UFUNCTION()
    private void OnServerDone(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _IsCounting = false;
        Assert_True(_Anchors <= k_MaxAnchors, f"the server's ledger took {k_MaxAnchors} anchors or fewer while grinding ({_Anchors})");
        auto Step = FMars_TESTONLY_NetMinigameStep(1);
        Step.Count = _Anchors;
        Report_Step(Step);
        End_MinigameServer(f"anchors={_Anchors} {Describe_Record()} {Describe_Mortar()}");
    }

    protected void On_Sample(float32 InDeltaSeconds) override
    {
        if (Get_IsServer())
        {
            Count_Anchor();
            return;
        }

        if (ck::Is_NOT_Valid(_Mortar))
        { return; }

        if (_Mortar.Get_Pestle() == EMars_Mortar_Pestle::Grinding)
        { _SawGrinding = true; }

        const auto Batch = _Mortar.Get_Batch();
        _HighestProgress = Math::Max(_HighestProgress, Batch.GrindProgress);
        if (Batch.Phase != EMars_Mortar_Phase::Grind)
        { return; }

        _Rising = Batch.GrindProgress > _LastProgress && _LastProgress >= 0.0f ? _Rising + 1 : 0;
        _LongestRising = Math::Max(_LongestRising, _Rising);
        _LastProgress = Batch.GrindProgress;
    }

    protected void On_ClientStep(int32 InStep) override
    {
        auto DoneBroadcasts = 0;
        for (const auto& Batch : _Batches)
        {
            if (Batch.Phase == EMars_Mortar_Phase::Done)
            { ++DoneBroadcasts; }
        }

        const auto Batch = _Mortar.Get_Batch();
        Assert_True(_SawGrinding, "the client read its pestle Grinding");
        Assert_True(_LongestRising >= k_RisingFrames, f"the client's grind rose over {k_RisingFrames} sampled frames in a row (longest {_LongestRising})");
        Assert_True(_HighestProgress <= 1.0f, f"the client's grind never passed 1 ({_HighestProgress})");
        Assert_True(Batch.Phase == EMars_Mortar_Phase::Done, f"the client's batch is Done ({Describe_Mortar()})");
        Assert_True(Batch.GrindProgress == 1.0f, f"the client's grind is exactly 1 ({Batch.GrindProgress})");
        Assert_Equals_Int(DoneBroadcasts, 1, f"the client raised OnBatchChanged with Done once ({Describe_Record()})");
        End_MinigameClient(f"serverAnchors={Get_Report().Count} longestRising={_LongestRising} highest={_HighestProgress} {Describe_Record()} {Describe_Mortar()}");
    }
}
