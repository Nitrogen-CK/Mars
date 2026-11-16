// A harness fixture: the gate whose authority, as it composes, asks itself open, so its ledger reads open in the spawn
// frame. A copy is born into an open gate.
class UMars_TESTONLY_NetGate_BornOpen_EntityScript : UMars_Gate_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        auto BornGate = InHandle.As_Gate(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(BornGate), f"[MechanismNetTest] [{InHandle.ToString()}] the born gate composed no Gate"))
        { return Flow; }

        BornGate.Request_SetPosition(FMars_Request_Gate_SetPosition(EMars_Gate_Position::Open));
        return Flow;
    }
}

// The server's gate is born open (the fixture above): the client's copy takes the open gate as it stands, announcing it
// once and showing its leaf open at once, with no swing. A later close reaches it as it arrives: announced once, and
// the leaf swings down.
// Surface: Ck.Mechanism.Net.AS_Mechanism_ACopyBornOpenShowsItsLeafOpen
class UCk_AutoTest_Net_Mechanism_ACopyBornOpenShowsItsLeafOpen : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_BgBase = FVector(4600.0, 0.0, 5000.0);
    private const float64 k_BgNearCm = 200.0;
    private const int32 k_BgSlowPolls = 5000;
    private const float32 k_BgSettleSeconds = 1.5f;
    private const float32 k_BgBeforeCloseSeconds = 3.0f;
    private const float32 k_BgClientSettleSeconds = 1.0f;
    // The client's swing down and its settled second, after the server's ledger reads closed.
    private const float32 k_BgServerWaitSeconds = 2.5f;
    private const float32 k_BgServerHoldSeconds = 4.0f;
    // The leaf's Mover is asked in the notify and moves in a later tick.
    private const int32 k_BgSnapFrames = 2;

    private FCk_Handle_Gate _BgGate;
    private int32 _BgEnsuresAtStart = 0;

    // Client: the find, each recorded notify of the ledger, each OnOpenChanged and each leaf sample, with its frame.
    private int32 _BgFoundFrame = -1;
    private EMars_Net_InitialState _BgInitialAtFind = EMars_Net_InitialState::Awaited;
    private TArray<int32> _BgNotifyFrames;
    private TArray<EMars_Gate_State> _BgNotifies;
    private TArray<int32> _BgEdgeFrames;
    private TArray<EMars_Gate_Position> _BgEdges;
    private TArray<int32> _BgSampleFrames;
    private TArray<float32> _BgSampleAlphas;
    // How many OnOpenChanged had been recorded when each sample was taken.
    private TArray<int32> _BgSampleEdges;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _BgEnsuresAtStart = utils_ensure::Get_EnsureCount();

        if (Get_BgIsServer() == false)
        {
            WaitUntil(n"Is_BornGateFound", n"OnClientFound", k_BgSlowPolls);
            return;
        }

        WaitUntil(n"Is_BgSpawnOwnerPublished", n"OnServerOwnerPublished", k_BgSlowPolls);
    }

    private bool Get_BgIsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    private int32 Get_BgNewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _BgEnsuresAtStart;
    }

    UFUNCTION()
    private void Is_BgSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // This machine's copy of the gate near the base; the first time, the client starts recording here.
    UFUNCTION()
    private void Is_BornGateFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::IsValid(_BgGate))
        {
            Result.Set(true);
            return;
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsGate"))
        {
            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            const auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - k_BgBase;
            auto Gate = Candidate.As_Gate(ECk_SanityCheck::UnChecked);
            if (Offset.Size() > k_BgNearCm || ck::Is_NOT_Valid(Gate))
            { continue; }

            _BgGate = Gate;
            if (Get_BgIsServer())
            { Track_ForCleanup(Candidate); }
            else
            { Begin_BornGateRecord(); }

            Result.Set(true);
            return;
        }

        Result.Set(false);
    }

    private void Begin_BornGateRecord()
    {
        _BgFoundFrame = int32(utils_time::Get_FrameCounter());
        _BgInitialAtFind = Get_BgInitialState();
        _BgGate.BindTo_OnRepNotify(FMars_Fragment_Gate, FCk_DynamicFragment_OnRepNotify(this, n"OnBornGateNotify"));
        _BgGate.BindTo_OnOpenChanged(FMars_Delegate_Gate_OnOpenChanged(this, n"OnBornGateOpenChanged"));
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_Gate_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_BgBase);
        Params.Gate.StartOpen = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_NetGate_BornOpen_EntityScript, Params);
        WaitUntil(n"Is_BornGateFound", n"OnServerFound", k_BgSlowPolls);
    }

    // The server finds its gate before the spawn frame's drain has run: it reads the born state a beat later.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BgSettleSeconds, n"OnServerBornSettled");
    }

    UFUNCTION()
    private void OnServerBornSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto State = _BgGate.Get_State();
        const auto Line = f"[MechanismNetTest] ACopyBornOpenShowsItsLeafOpen server: born state={State :n} alpha={_BgGate.Get_MovingNode().As_Mover().Get_Alpha()} ensures={Get_BgNewEnsures()}";
        Log(Line);
        Assert_True(State == EMars_Gate_State::Open, f"the server's gate was born open ({Line})");
        WaitSeconds(k_BgBeforeCloseSeconds, n"OnServerReadyToClose");
    }

    UFUNCTION()
    private void OnServerReadyToClose(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _BgGate.Request_SetPosition(FMars_Request_Gate_SetPosition(EMars_Gate_Position::Closed));
        WaitUntil(n"Is_BgServerClosed", n"OnServerClosed", k_BgSlowPolls);
    }

    UFUNCTION()
    private void Is_BgServerClosed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_BgGate.Get_State() == EMars_Gate_State::Closed);
    }

    UFUNCTION()
    private void OnServerClosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BgServerWaitSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_True(_BgGate.Get_State() == EMars_Gate_State::Closed, "the server's gate is closed");
        Assert_Equals_Int(Get_BgNewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_BgServerHoldSeconds, n"OnServerHeld");
    }

    UFUNCTION()
    private void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_BgClientClosedAndDown", n"OnClientClosed", k_BgSlowPolls);
    }

    // Samples the leaf every frame; true once the close was announced and the leaf is down. A copy the server already
    // destroyed is not sampled.
    UFUNCTION()
    private void Is_BgClientClosedAndDown(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_BgGate) || utils_entity_lifetime::Get_IsPendingDestroy(_BgGate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            Result.Set(false);
            return;
        }

        const auto Alpha = _BgGate.Get_MovingNode().As_Mover().Get_Alpha();
        _BgSampleFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BgSampleAlphas.Add(Alpha);
        _BgSampleEdges.Add(_BgEdges.Num());
        Result.Set(_BgEdges.Num() >= 2 && Alpha < 0.01f);
    }

    UFUNCTION()
    private void OnClientClosed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BgClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto FirstFrame = _BgNotifyFrames.Num() > 0 ? _BgNotifyFrames[0] : -1;
        const auto FirstOpen = _BgNotifies.Num() > 0 && _BgNotifies[0] == EMars_Gate_State::Open;
        const auto AlphaNow = _BgGate.Get_MovingNode().As_Mover().Get_Alpha();

        auto SnapSamples = 0;
        auto SnapLow = 2.0f;
        auto SwingSamples = 0;
        for (int32 Index = 0; Index < _BgSampleFrames.Num(); ++Index)
        {
            if (_BgSampleEdges[Index] == 1 && FirstFrame >= 0 && _BgSampleFrames[Index] >= FirstFrame + k_BgSnapFrames)
            {
                SnapSamples += 1;
                SnapLow = Math::Min(SnapLow, _BgSampleAlphas[Index]);
            }

            if (_BgSampleEdges[Index] >= 2 && _BgSampleAlphas[Index] > 0.05f && _BgSampleAlphas[Index] < 0.95f)
            { SwingSamples += 1; }
        }

        const auto Line = Describe_BornGate();
        const auto LogLine = f"[MechanismNetTest] ACopyBornOpenShowsItsLeafOpen client: snapSamples={SnapSamples} snapLow={SnapLow} swingSamples={SwingSamples} alphaNow={AlphaNow} ensures={Get_BgNewEnsures()} {Line}";
        Log(LogLine);

        Assert_True(Get_BgInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_BgInitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(_BgNotifyFrames.Num() > 0 && FirstOpen, f"the first notify carried the open gate it was born into ({Line})");
        Assert_True(_BgEdges.Num() == 2 && _BgEdges[0] == EMars_Gate_Position::Open && _BgEdges[1] == EMars_Gate_Position::Closed,
            f"the client announced the born open gate, then the close ({Line})");
        Assert_True(_BgEdgeFrames.Num() > 0 && _BgEdgeFrames[0] == FirstFrame, f"the born open gate was announced in the first notify's frame ({Line})");
        Assert_True(SnapSamples > 0 && SnapLow >= 0.99f, f"the leaf stood open from the frame after it was asked until the close ({Line})");
        Assert_True(SwingSamples > 0, f"the close swung the leaf down ({Line})");
        Assert_True(AlphaNow < 0.01f, f"the leaf is down now ({Line})");
        Assert_Equals_Int(Get_BgNewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // This machine's copy's level now; Awaited while there is none.
    private EMars_Net_InitialState Get_BgInitialState() const
    {
        if (ck::Is_NOT_Valid(_BgGate) || _BgGate.Has_Fragment(FMars_Fragment_Gate_Mirror) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _BgGate.Get_Fragment(FMars_Fragment_Gate_Mirror).InitialState;
    }

    private FString Describe_BornGate()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _BgNotifyFrames.Num(); ++Index)
        { Notifies += f"{_BgNotifyFrames[Index]}:{_BgNotifies[Index] :n} "; }

        auto Edges = "";
        for (int32 Index = 0; Index < _BgEdgeFrames.Num(); ++Index)
        { Edges += f"{_BgEdgeFrames[Index]}:{_BgEdges[Index] :n} "; }

        auto Samples = "";
        for (int32 Index = 0; Index < _BgSampleFrames.Num() && Index < 6; ++Index)
        { Samples += f"{_BgSampleFrames[Index]}:{_BgSampleAlphas[Index]} "; }

        return f"found@{_BgFoundFrame} initialAtFind={_BgInitialAtFind :n} initial={Get_BgInitialState() :n} notifies=[{Notifies}] edges=[{Edges}] firstSamples=[{Samples}]";
    }

    // A notify can land on a gate already ending.
    UFUNCTION()
    private void OnBornGateNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Gate) == false)
        { return; }

        _BgNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BgNotifies.Add(InHandle.Get_Fragment(FMars_Fragment_Gate).State);
    }

    UFUNCTION()
    private void OnBornGateOpenChanged(FCk_Handle_Gate InGate, EMars_Gate_Position InPosition)
    {
        _BgEdgeFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BgEdges.Add(InPosition);
    }
}
