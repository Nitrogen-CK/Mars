// A harness fixture: the sequence node every machine tags for the test to find, and whose authority, as it composes,
// enters its first step twice, so its ledger reads one step and one rejection in the spawn frame (a wrong input does
// not reset it). A copy is born into a half-entered node that rejected an input.
class UMars_TESTONLY_NetSequenceNode_BornRejected_EntityScript : UMars_SequenceNode_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        utils_entity_tag::Add(InHandle, n"TAG_MarsTestNetSequenceNode");
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        auto BornSequence = InHandle.As_Sequence(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(BornSequence) && Sequence.Steps.Num() >= 2,
            f"[MechanismNetTest] [{InHandle.ToString()}] the born node composed no two-step Sequence"))
        { return Flow; }

        BornSequence.Request_Input(FMars_Request_Sequence_Input(Sequence.Steps[0]));
        BornSequence.Request_Input(FMars_Request_Sequence_Input(Sequence.Steps[0]));
        return Flow;
    }
}

// The server's node is born one step in with one rejection (the fixture above): the client's copy takes it as it
// stands, announcing the standing step and raising no rejection. A later wrong input, then the last step, reach it as
// they arrive: one rejection naming the server's channel, then the step and the completion.
// Surface: Ck.Mechanism.Net.AS_Mechanism_ACopyBornRejectedRaisesNoPastRejection
class UCk_AutoTest_Net_Mechanism_ACopyBornRejectedRaisesNoPastRejection : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    private const FVector k_BsBase = FVector(5600.0, 0.0, 5000.0);
    private const float64 k_BsNearCm = 200.0;
    private const int32 k_BsSlowPolls = 5000;
    private const float32 k_BsSettleSeconds = 1.5f;
    private const float32 k_BsBeforeInputSeconds = 3.0f;
    private const float32 k_BsClientSettleSeconds = 1.0f;
    // The client's settled second, after the server's node completes.
    private const float32 k_BsServerWaitSeconds = 2.0f;
    private const float32 k_BsServerHoldSeconds = 4.0f;

    private FCk_Handle_Sequence _BsSequence;
    private TArray<FGameplayTag> _BsSteps;
    private int32 _BsEnsuresAtStart = 0;

    // Client: the find, each recorded notify of the ledger and each signal, with its frame.
    private int32 _BsFoundFrame = -1;
    private EMars_Net_InitialState _BsInitialAtFind = EMars_Net_InitialState::Awaited;
    private TArray<int32> _BsNotifyFrames;
    private TArray<FMars_Fragment_Sequence> _BsNotifies;
    private TArray<int32> _BsStepFrames;
    private TArray<int32> _BsStepIndices;
    private TArray<int32> _BsRejectFrames;
    private TArray<FGameplayTag> _BsRejectChannels;
    private TArray<int32> _BsResetFrames;
    private TArray<int32> _BsCompleteFrames;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        if (ck::Is_NOT_Valid(Get_SubjectEntity()))
        { FinishFailure("subject entity not found"); return; }

        _BsEnsuresAtStart = utils_ensure::Get_EnsureCount();
        _BsSteps.Add(GameplayTags::Mechanism_Channel_G);
        _BsSteps.Add(GameplayTags::Mechanism_Channel_H);

        if (Get_BsIsServer() == false)
        {
            WaitUntil(n"Is_BornNodeFound", n"OnClientFound", k_BsSlowPolls);
            return;
        }

        WaitUntil(n"Is_BsSpawnOwnerPublished", n"OnServerOwnerPublished", k_BsSlowPolls);
    }

    private bool Get_BsIsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    private int32 Get_BsNewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _BsEnsuresAtStart;
    }

    UFUNCTION()
    private void Is_BsSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // This machine's copy of the node near the base; the first time, the client starts recording here.
    UFUNCTION()
    private void Is_BornNodeFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::IsValid(_BsSequence))
        {
            Result.Set(true);
            return;
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetSequenceNode"))
        {
            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            const auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - k_BsBase;
            auto Sequence = Candidate.As_Sequence(ECk_SanityCheck::UnChecked);
            if (Offset.Size() > k_BsNearCm || ck::Is_NOT_Valid(Sequence))
            { continue; }

            _BsSequence = Sequence;
            if (Get_BsIsServer())
            { Track_ForCleanup(Candidate); }
            else
            { Begin_BornNodeRecord(); }

            Result.Set(true);
            return;
        }

        Result.Set(false);
    }

    private void Begin_BornNodeRecord()
    {
        _BsFoundFrame = int32(utils_time::Get_FrameCounter());
        _BsInitialAtFind = Get_BsInitialState();
        _BsSequence.BindTo_OnRepNotify(FMars_Fragment_Sequence, FCk_DynamicFragment_OnRepNotify(this, n"OnBornNodeNotify"));
        _BsSequence.BindTo_OnStepAccepted(FMars_Delegate_Sequence_OnStepAccepted(this, n"OnBornNodeStepAccepted"));
        _BsSequence.BindTo_OnInputRejected(FMars_Delegate_Sequence_OnInputRejected(this, n"OnBornNodeInputRejected"));
        _BsSequence.BindTo_OnReset(FMars_Delegate_Sequence_OnReset(this, n"OnBornNodeReset"));
        _BsSequence.BindTo_OnCompleted(FMars_Delegate_Sequence_OnCompleted(this, n"OnBornNodeCompleted"));
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_SequenceNode_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_BsBase);
        Params.Sequence.Steps = _BsSteps;
        Params.Sequence.ResetOnWrongInput = false;
        Params.Sequence.Latch = true;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_NetSequenceNode_BornRejected_EntityScript, Params);
        WaitUntil(n"Is_BornNodeFound", n"OnServerFound", k_BsSlowPolls);
    }

    // The server finds its node before the spawn frame's drain has run: it reads the born state a beat later.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BsSettleSeconds, n"OnServerBornSettled");
    }

    UFUNCTION()
    private void OnServerBornSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _BsSequence.Get_Fragment(FMars_Fragment_Sequence);
        const auto Line = f"[MechanismNetTest] ACopyBornRejectedRaisesNoPastRejection server: born progress={Ledger.Progress} rejections={Ledger.Rejections} lastRejected={Ledger.LastRejectedChannel.ToString()} ensures={Get_BsNewEnsures()}";
        Log(Line);
        Assert_True(Ledger.Progress == 1 && Ledger.Rejections == 1, f"the server's node was born one step in with one rejection ({Line})");
        WaitSeconds(k_BsBeforeInputSeconds, n"OnServerReadyToReject");
    }

    // The first step again, at progress 1: wrong.
    UFUNCTION()
    private void OnServerReadyToReject(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _BsSequence.Request_Input(FMars_Request_Sequence_Input(_BsSteps[0]));
        WaitUntil(n"Is_BsServerRejectedTwice", n"OnServerRejectedTwice", k_BsSlowPolls);
    }

    UFUNCTION()
    private void Is_BsServerRejectedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_BsSequence.Get_Fragment(FMars_Fragment_Sequence).Rejections >= 2);
    }

    UFUNCTION()
    private void OnServerRejectedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BsSettleSeconds, n"OnServerReadyToComplete");
    }

    UFUNCTION()
    private void OnServerReadyToComplete(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        _BsSequence.Request_Input(FMars_Request_Sequence_Input(_BsSteps[1]));
        WaitUntil(n"Is_BsComplete", n"OnServerComplete", k_BsSlowPolls);
    }

    // A copy the server already destroyed is not read.
    UFUNCTION()
    private void Is_BsComplete(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_BsSequence) || utils_entity_lifetime::Get_IsPendingDestroy(_BsSequence, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            Result.Set(false);
            return;
        }

        Result.Set(_BsSequence.Get_IsComplete());
    }

    UFUNCTION()
    private void OnServerComplete(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BsServerWaitSeconds, n"OnServerSettled");
    }

    UFUNCTION()
    private void OnServerSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _BsSequence.Get_Fragment(FMars_Fragment_Sequence);
        Assert_True(Ledger.Progress == 2 && Ledger.Rejections == 2, "the server's node completed after its second rejection");
        Assert_Equals_Int(Get_BsNewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_BsServerHoldSeconds, n"OnServerHeld");
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
        WaitUntil(n"Is_BsComplete", n"OnClientComplete", k_BsSlowPolls);
    }

    UFUNCTION()
    private void OnClientComplete(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_BsClientSettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Ledger = _BsSequence.Get_Fragment(FMars_Fragment_Sequence);
        const auto First = _BsNotifies.Num() > 0 ? _BsNotifies[0] : FMars_Fragment_Sequence();
        const auto FirstFrame = _BsNotifyFrames.Num() > 0 ? _BsNotifyFrames[0] : -1;
        const auto Line = Describe_BornNode();
        const auto LogLine = f"[MechanismNetTest] ACopyBornRejectedRaisesNoPastRejection client: progress={Ledger.Progress} rejections={Ledger.Rejections} ensures={Get_BsNewEnsures()} {Line}";
        Log(LogLine);

        auto StepZeroFrames = 0;
        auto StepZeroInFirst = 0;
        auto StepOneCount = 0;
        auto StepOneFrame = -1;
        for (int32 Index = 0; Index < _BsStepIndices.Num(); ++Index)
        {
            if (_BsStepIndices[Index] == 0)
            {
                StepZeroFrames += 1;
                if (_BsStepFrames[Index] == FirstFrame)
                { StepZeroInFirst += 1; }
            }
            else if (_BsStepIndices[Index] == 1)
            {
                StepOneCount += 1;
                StepOneFrame = _BsStepFrames[Index];
            }
        }

        const auto RejectFrame = _BsRejectFrames.Num() > 0 ? _BsRejectFrames[0] : -1;
        const auto CompleteFrame = _BsCompleteFrames.Num() > 0 ? _BsCompleteFrames[0] : -1;

        Assert_True(Get_BsInitialState() == EMars_Net_InitialState::Taken, f"the client's copy took the state it was born into ({Line})");
        Assert_True(_BsInitialAtFind == EMars_Net_InitialState::Awaited, f"the client found its copy before its ledger's first application ({Line})");
        Assert_True(_BsNotifyFrames.Num() > 0, f"the client recorded a rep-notify of its copy's ledger ({Line})");
        Assert_True(First.Progress == 1 && First.Rejections == 1, f"the first notify carried the step and the rejection it was born into ({Line})");
        Assert_True(StepZeroFrames == 1 && StepZeroInFirst == 1, f"the standing step was announced once, in the first notify's frame ({Line})");
        Assert_Equals_Int(_BsRejectFrames.Num(), Ledger.Rejections - First.Rejections, f"the client raised only the rejections after its first notify ({Line})");
        Assert_True(_BsRejectChannels.Num() > 0 && _BsRejectChannels[0] == _BsSteps[0], f"the client's rejection names the server's channel ({Line})");
        Assert_Equals_Int(_BsResetFrames.Num(), 0, f"nothing reset the client's node ({Line})");
        Assert_True(StepOneCount == 1 && _BsCompleteFrames.Num() == 1, f"the last step and the completion were raised once ({Line})");
        Assert_True(RejectFrame >= 0 && StepOneFrame > RejectFrame && CompleteFrame > RejectFrame, f"the last step and the completion came after the rejection ({Line})");
        Assert_Equals_Int(Get_BsNewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // This machine's copy's level now; Awaited while there is none.
    private EMars_Net_InitialState Get_BsInitialState() const
    {
        if (ck::Is_NOT_Valid(_BsSequence) || _BsSequence.Has_Fragment(FMars_Fragment_Sequence_Mirror) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _BsSequence.Get_Fragment(FMars_Fragment_Sequence_Mirror).InitialState;
    }

    private FString Describe_BornNode()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _BsNotifyFrames.Num(); ++Index)
        { Notifies += f"{_BsNotifyFrames[Index]}:{_BsNotifies[Index].Progress}/{_BsNotifies[Index].Rejections} "; }

        auto Signals = "";
        for (int32 Index = 0; Index < _BsStepFrames.Num(); ++Index)
        { Signals += f"S{_BsStepIndices[Index]}@{_BsStepFrames[Index]} "; }

        for (int32 Index = 0; Index < _BsRejectFrames.Num(); ++Index)
        { Signals += f"X:{_BsRejectChannels[Index].ToString()}@{_BsRejectFrames[Index]} "; }

        for (const auto Frame : _BsResetFrames)
        { Signals += f"R@{Frame} "; }

        for (const auto Frame : _BsCompleteFrames)
        { Signals += f"C@{Frame} "; }

        return f"found@{_BsFoundFrame} initialAtFind={_BsInitialAtFind :n} initial={Get_BsInitialState() :n} notifies=[{Notifies}] signals=[{Signals}]";
    }

    // A notify can land on a node already ending.
    UFUNCTION()
    private void OnBornNodeNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Sequence) == false)
        { return; }

        _BsNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BsNotifies.Add(InHandle.Get_Fragment(FMars_Fragment_Sequence));
    }

    UFUNCTION()
    private void OnBornNodeStepAccepted(FCk_Handle_Sequence InSequence, int32 InIndex)
    {
        _BsStepFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BsStepIndices.Add(InIndex);
    }

    UFUNCTION()
    private void OnBornNodeInputRejected(FCk_Handle_Sequence InSequence, FGameplayTag InChannel)
    {
        _BsRejectFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BsRejectChannels.Add(InChannel);
    }

    UFUNCTION()
    private void OnBornNodeReset(FCk_Handle_Sequence InSequence)
    {
        _BsResetFrames.Add(int32(utils_time::Get_FrameCounter()));
    }

    UFUNCTION()
    private void OnBornNodeCompleted(FCk_Handle_Sequence InSequence)
    {
        _BsCompleteFrames.Add(int32(utils_time::Get_FrameCounter()));
    }
}
