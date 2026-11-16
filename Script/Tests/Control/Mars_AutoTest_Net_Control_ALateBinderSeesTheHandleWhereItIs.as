// A harness fixture: the lever whose authority, as it composes, asks to engage it, grants the first of two live test
// grippers its grip, refuses the second and applies the holder's report of half, in that order. A copy is born into an
// active lever with one engagement, held at half by another machine, with one refusal.
class UMars_TESTONLY_NetLever_BornHeldAndRefused_EntityScript : UMars_Lever_EntityScript
{
    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        if (utils_net::Get_HasAuthority(InHandle) == false)
        { return Flow; }

        // A rejected control already ensured in utils_control::Add.
        auto Control = InHandle.As_Control(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Control))
        { return Flow; }

        auto Grippers = TArray<FCk_Handle>();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(InHandle, n"TAG_MarsTestNetGripper"))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
            { continue; }

            Grippers.Add(Candidate);
        }

        if (ck::EnsureIfNot(Grippers.Num() >= 2, f"[ControlNetTest] the born lever found {Grippers.Num()} live test grippers, not two"))
        { return Flow; }

        Control.Request_Engage(FMars_Request_Control_Engage());
        Control.Request_Grip(FMars_Request_Control_Grip(Grippers[0], EMars_Control_GripVerb::Begin));
        Control.Request_Grip(FMars_Request_Control_Grip(Grippers[1], EMars_Control_GripVerb::Begin));
        Control.Request_ReportPull(FMars_Request_Control_ReportPull(Grippers[0], 0.5f));
        return Flow;
    }
}

// One frame of what the client shows of the born lever's handle.
struct FMars_AutoTestHelper_BornLeverSample
{
    int32 Frame = 0;
    float32 Shown = 0.0f;
    float32 Mover = 0.0f;
    bool Claimed = false;
}

// The server's lever is born active with one engagement, held at half by a stand-in, with the other stand-in refused
// (the fixture above): the client's copy takes all of it as it stands, raising no engagement and no refusal, and shows
// the handle at the held pull from the frame its grip arrives. The refused stand-in's second claim, then the holder's
// crossing, reach it as one refusal and one engagement, and the handle goes home.
// Surface: Ck.Control.Net.AS_Control_ALateBinderSeesTheHandleWhereItIs
class UCk_AutoTest_Net_Control_ALateBinderSeesTheHandleWhereItIs : UMars_AutoTestRig_NetControl
{
    default _TimeoutSeconds = 25.0f;

    private const FVector k_Location = FVector(147000.0, 0.0, 5000.0);
    private const float32 k_BlReclaimAfterSeconds = 3.0f;
    private const float32 k_BlServerHoldSeconds = 3.0f;

    // Server: the stand-ins it spawned, then which of them holds the born grip and which was refused.
    private TArray<FCk_Handle> _BlGrippers;
    private FCk_Handle _BlHolder;
    private FCk_Handle _BlRefused;

    // Client: the find, each recorded notify of the two ledgers and each signal, with its frame.
    private int32 _BlFoundFrame = -1;
    private EMars_Net_InitialState _BlEngageInitialAtFind = EMars_Net_InitialState::Awaited;
    private EMars_Net_InitialState _BlGripInitialAtFind = EMars_Net_InitialState::Awaited;
    private TArray<int32> _BlEngageNotifyFrames;
    private TArray<FMars_Fragment_Control> _BlEngageNotifies;
    private TArray<int32> _BlGripNotifyFrames;
    private TArray<FMars_Fragment_Control_Grip> _BlGripNotifies;
    private TArray<int32> _BlEngagedFrames;
    private TArray<EMars_Control_Activation> _BlActivations;
    private TArray<int32> _BlActivationFrames;
    private TArray<FCk_Handle> _BlRefusals;
    private TArray<int32> _BlRefusalFrames;
    private TArray<EMars_Control_GripHolder> _BlHolderFrom;
    private TArray<EMars_Control_GripHolder> _BlHolderTo;
    private TArray<int32> _BlHolderFrames;
    private TArray<FMars_AutoTestHelper_BornLeverSample> _BlSamples;

    UFUNCTION(BlueprintOverride)
    void DoBeginPlay(FCk_Handle InHandle)
    {
        auto Subject = Get_SubjectEntity();
        if (ck::Is_NOT_Valid(Subject))
        { FinishFailure("subject entity not found"); return; }

        Begin_NetControlTest();

        if (Get_IsServer() == false)
        {
            WaitUntil(n"Is_BornLeverFound", n"OnClientFound", k_SlowPolls);
            return;
        }

        WaitUntil(n"Is_ReplicatedSpawnOwnerPublished", n"OnServerOwnerPublished", k_SlowPolls);
    }

    //------------------------------------------------------------------------------------------------------------------
    // Server
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnServerOwnerPublished(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Spawn_ServerStandIn();
        Spawn_ServerStandIn();
        WaitUntil(n"Is_BothStandInsFound", n"OnServerStandInsFound", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_BothStandInsFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetGripper"))
        {
            if (utils_entity_lifetime::Get_IsPendingDestroy(Candidate, ECk_EntityLifetime_DestructionPhase::BeginDestroy)
                || _BlGrippers.Contains(Candidate))
            { continue; }

            _BlGrippers.Add(Candidate);
            Track_ForCleanup(Candidate);
        }

        auto Result = OutResult;
        Result.Set(_BlGrippers.Num() >= 2);
    }

    // Both stand-ins reach the client before the lever that names them.
    UFUNCTION()
    private void OnServerStandInsFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerReadyToSpawn");
    }

    UFUNCTION()
    private void OnServerReadyToSpawn(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        auto Params = UMars_Lever_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, k_Location);
        Params.Control.Interaction = ECk_Interaction_CompletionPolicy::ManuallyCompleted;
        Params.Control.StartActive = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_NetLever_BornHeldAndRefused_EntityScript, Params);
        WaitUntil(n"Is_LeverFound", n"OnServerFound", k_SlowPolls);
    }

    // The server finds its lever before the spawn frame's drain has run: it reads the born state a beat later.
    UFUNCTION()
    private void OnServerFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerBornSettled");
    }

    UFUNCTION()
    private void OnServerBornSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Engage = _Control.Get_Fragment(FMars_Fragment_Control);
        const auto Grip = _Control.Get_Fragment(FMars_Fragment_Control_Grip);
        _BlHolder = _Control.Get_Gripper();
        _BlRefused = Grip.LastRefused;
        const auto Line = f"[ControlNetTest] ALateBinderSeesTheHandleWhereItIs server: born active {Engage.IsActive}, engagements {Engage.Engagements}, pull {Grip.Pull :.3}, {Get_GripText(_Control)}, grippers {_BlGrippers.Num()}, ensures {Get_NewEnsures()}";
        Log(Line);
        Assert_True(Engage.IsActive && Engage.Engagements == 1, f"the server's lever was born active with one engagement ({Line})");
        Assert_True(Grip.Grip == EMars_Control_Grip::Gripped && _BlGrippers.Contains(_BlHolder), f"the server's lever was born held by a stand-in ({Line})");
        Assert_True(Grip.RefusalSerial == 1 && _BlGrippers.Contains(_BlRefused) && _BlRefused != _BlHolder, f"the server's lever was born with the other stand-in refused ({Line})");
        Assert_Equals_Float(Grip.Pull, k_HalfPull, 0.0001f, f"the server's lever was born pulled to half ({Line})");
        WaitSeconds(k_BlReclaimAfterSeconds, n"OnServerReadyToReclaim");
    }

    UFUNCTION()
    private void OnServerReadyToReclaim(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_BlRefused, EMars_Control_GripVerb::Begin);
        WaitUntil(n"Is_ServerRefusedTwice", n"OnServerRefusedTwice", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerRefusedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(_Control.Get_RefusalSerial() >= 2);
    }

    UFUNCTION()
    private void OnServerRefusedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnServerReadyToCross");
    }

    UFUNCTION()
    private void OnServerReadyToCross(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Request_ServerGrip(_BlHolder, EMars_Control_GripVerb::Cross);
        WaitUntil(n"Is_ServerCrossed", n"OnServerCrossed", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ServerCrossed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        const auto Grip = _Control.Get_Fragment(FMars_Fragment_Control_Grip);
        auto Result = OutResult;
        Result.Set(Grip.Grip == EMars_Control_Grip::Released && Grip.LastRelease == EMars_Control_GripRelease::Crossed
            && Get_Engagements() >= 2 && _Control.Get_IsActive() == false);
    }

    UFUNCTION()
    private void OnServerCrossed(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        Assert_Equals_Int(Get_Engagements(), 2, "the server's lever counts two engagements");
        Assert_Equals_Int(_Control.Get_RefusalSerial(), 2, "the server's lever counts two refusals");
        Assert_False(_Control.Get_IsActive(), "the server's lever is inactive after the crossing");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_BlServerHoldSeconds, n"OnServerHeld");
    }

    //------------------------------------------------------------------------------------------------------------------
    // Client
    //------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void Is_BornLeverFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (Get_IsControlFound(n"TAG_MarsLever") == false)
        {
            Result.Set(false);
            return;
        }

        if (_BlFoundFrame < 0)
        { Begin_BornLeverRecord(); }

        Result.Set(true);
    }

    private void Begin_BornLeverRecord()
    {
        _BlFoundFrame = int32(utils_time::Get_FrameCounter());
        _BlEngageInitialAtFind = Get_BlEngageInitialState();
        _BlGripInitialAtFind = Get_BlGripInitialState();
        _Control.BindTo_OnRepNotify(FMars_Fragment_Control, FCk_DynamicFragment_OnRepNotify(this, n"OnBornLeverEngageNotify"));
        _Control.BindTo_OnRepNotify(FMars_Fragment_Control_Grip, FCk_DynamicFragment_OnRepNotify(this, n"OnBornLeverGripNotify"));
        _Control.BindTo_OnEngaged(FMars_Delegate_Control_OnEngaged(this, n"OnBornLeverEngaged"));
        _Control.BindTo_OnActiveChanged(FMars_Delegate_Control_OnActiveChanged(this, n"OnBornLeverActiveChanged"));
        _Control.BindTo_OnGripRefused(FMars_Delegate_Control_OnGripRefused(this, n"OnBornLeverGripRefused"));
        _Control.BindTo_OnGripHolderChanged(FMars_Delegate_Control_OnGripHolderChanged(this, n"OnBornLeverHolderChanged"));
    }

    UFUNCTION()
    private void OnClientFound(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitUntil(n"Is_ClientRefusedTwice", n"OnClientRefusedTwice", k_SlowPolls);
    }

    // Samples the shown handle every frame after the first grip notify's, until the second refusal arrives.
    UFUNCTION()
    private void Is_ClientRefusedTwice(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Control) || utils_entity_lifetime::Get_IsPendingDestroy(_Control, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            Result.Set(false);
            return;
        }

        if (_Control.Get_RefusalSerial() >= 2)
        {
            Result.Set(true);
            return;
        }

        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_BlGripNotifyFrames.Num() > 0 && Frame > _BlGripNotifyFrames[0])
        {
            auto Sample = FMars_AutoTestHelper_BornLeverSample();
            Sample.Frame = Frame;
            Sample.Shown = Get_ShownAlpha();
            Sample.Mover = ck::IsValid(_Mover) ? _Mover.Get_Alpha() : -1.0f;
            Sample.Claimed = Get_IsClaimed();
            _BlSamples.Add(Sample);
        }

        Result.Set(false);
    }

    UFUNCTION()
    private void OnClientRefusedTwice(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto First = Get_BlFirstGrip();
        const auto FirstFrame = _BlGripNotifyFrames.Num() > 0 ? _BlGripNotifyFrames[0] : -1;
        const auto Line = Describe_BornLever();
        Assert_Equals_Int(_BlRefusals.Num(), 1, f"the client raised one OnGripRefused by the second refusal ({Line})");
        if (_BlRefusals.Num() > 0)
        {
            Assert_True(_BlRefusals[0] == First.LastRefused, f"the client's refusal names the refused stand-in ({Line})");
            Assert_True(_BlRefusalFrames[0] > FirstFrame, f"the client's refusal came after its first grip notify ({Line})");
        }

        WaitUntil(n"Is_ClientCrossedHome", n"OnClientCrossedHome", k_SlowPolls);
    }

    UFUNCTION()
    private void Is_ClientCrossedHome(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::Is_NOT_Valid(_Control) || utils_entity_lifetime::Get_IsPendingDestroy(_Control, ECk_EntityLifetime_DestructionPhase::BeginDestroy))
        {
            Result.Set(false);
            return;
        }

        Result.Set(Get_Engagements() >= 2 && ck::IsValid(_Mover) && _Mover.Get_Alpha() < 0.01f);
    }

    UFUNCTION()
    private void OnClientCrossedHome(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        WaitSeconds(k_SettleSeconds, n"OnClientSettled");
    }

    UFUNCTION()
    private void OnClientSettled(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        const auto Engage = _Control.Get_Fragment(FMars_Fragment_Control);
        const auto Grip = _Control.Get_Fragment(FMars_Fragment_Control_Grip);
        const auto FirstEngage = Get_BlFirstEngage();
        const auto FirstGrip = Get_BlFirstGrip();
        const auto FirstEngageFrame = _BlEngageNotifyFrames.Num() > 0 ? _BlEngageNotifyFrames[0] : -1;
        const auto FirstGripFrame = _BlGripNotifyFrames.Num() > 0 ? _BlGripNotifyFrames[0] : -1;
        const auto Line = Describe_BornLever();
        const auto LogLine = f"[ControlNetTest] ALateBinderSeesTheHandleWhereItIs client: {Line}, {Get_PullText()}, {Get_GripText(_Control)}, ensures {Get_NewEnsures()}";
        Log(LogLine);

        Assert_True(Get_BlEngageInitialState() == EMars_Net_InitialState::Taken && Get_BlGripInitialState() == EMars_Net_InitialState::Taken,
            f"the client's copy took the engage and grip state it was born into ({Line})");
        Assert_True(_BlEngageInitialAtFind == EMars_Net_InitialState::Awaited && _BlGripInitialAtFind == EMars_Net_InitialState::Awaited,
            f"the client found its copy before either ledger's first application ({Line})");
        Assert_True(_BlEngageNotifyFrames.Num() > 0 && _BlGripNotifyFrames.Num() > 0, f"the client recorded a notify of each ledger ({Line})");
        Assert_True(FirstEngage.IsActive && FirstEngage.Engagements == 1, f"the first engage notify carried the active lever and its engagement ({Line})");
        Assert_True(FirstGrip.Grip == EMars_Control_Grip::Gripped && ck::IsValid(FirstGrip.Gripper) && FirstGrip.GripSerial == 1
            && FirstGrip.RefusalSerial == 1 && Math::Abs(FirstGrip.Pull - k_HalfPull) < 0.0001f, f"the first grip notify carried the held grip, its refusal and its pull ({Line})");

        Assert_Equals_Int(_BlEngagedFrames.Num(), Engage.Engagements - FirstEngage.Engagements, f"the client engaged only after its first notify ({Line})");
        Assert_Equals_Int(_BlActivations.Num(), 2, f"the client announced two activations ({Line})");
        if (_BlActivations.Num() == 2)
        {
            Assert_True(_BlActivations[0] == EMars_Control_Activation::Active && _BlActivations[1] == EMars_Control_Activation::Inactive,
                f"the client announced Active then Inactive ({Line})");
            Assert_Equals_Int(_BlActivationFrames[0], FirstEngageFrame, f"the standing activation was announced in the first engage notify's frame ({Line})");
        }

        Assert_Equals_Int(_BlRefusals.Num(), Grip.RefusalSerial - FirstGrip.RefusalSerial, f"the client was refused only after its first notify ({Line})");
        Assert_Equals_Int(_BlHolderFrom.Num(), 2, f"the client announced two holder changes ({Line})");
        if (_BlHolderFrom.Num() == 2)
        {
            Assert_True(_BlHolderFrom[0] == EMars_Control_GripHolder::Nobody && _BlHolderTo[0] == EMars_Control_GripHolder::AnotherMachine
                && _BlHolderFrom[1] == EMars_Control_GripHolder::AnotherMachine && _BlHolderTo[1] == EMars_Control_GripHolder::Nobody,
                f"the client announced Nobody>AnotherMachine then AnotherMachine>Nobody ({Line})");
            Assert_Equals_Int(_BlHolderFrames[0], FirstGripFrame, f"the standing holder was announced in the first grip notify's frame ({Line})");
        }

        Assert_True(_BlSamples.Num() > 0, f"the client sampled the shown handle after its first grip notify ({Line})");
        auto Worst = 0.0f;
        auto ClaimedThrough = true;
        for (const auto& Sample : _BlSamples)
        {
            Worst = Math::Max(Worst, Math::Abs(Sample.Shown - k_HalfPull));
            ClaimedThrough = ClaimedThrough && Sample.Claimed;
        }

        Assert_True(Worst < k_FollowTolerance, f"the shown handle stood at the held pull from the frame after its grip arrived (worst off {Worst}) ({Line})");
        if (_BlSamples.Num() > 0)
        {
            const auto LastMover = _BlSamples[_BlSamples.Num() - 1].Mover;
            Assert_True(Math::Abs(LastMover - k_HalfPull) < k_FollowTolerance, f"the Mover stood at the held pull at the last sample (got {LastMover}) ({Line})");
        }

        Assert_True(ClaimedThrough, f"the interactable held the Operated claim through the samples ({Line})");
        Assert_False(Get_IsClaimed(), f"the interactable holds no claim now ({Line})");
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the client");
        FinishSuccess();
    }

    // This machine's copy's levels now; Awaited while there is none.
    private EMars_Net_InitialState Get_BlEngageInitialState() const
    {
        if (ck::Is_NOT_Valid(_Control) || _Control.Has_Fragment(FMars_Fragment_Control_Mirror) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Control.Get_Fragment(FMars_Fragment_Control_Mirror).InitialState;
    }

    private EMars_Net_InitialState Get_BlGripInitialState() const
    {
        if (ck::Is_NOT_Valid(_Control) || _Control.Has_Fragment(FMars_Fragment_Control_GripMirror) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Control.Get_Fragment(FMars_Fragment_Control_GripMirror).InitialState;
    }

    private FMars_Fragment_Control Get_BlFirstEngage() const
    {
        if (_BlEngageNotifies.Num() == 0)
        { return FMars_Fragment_Control(); }

        return _BlEngageNotifies[0];
    }

    private FMars_Fragment_Control_Grip Get_BlFirstGrip() const
    {
        if (_BlGripNotifies.Num() == 0)
        { return FMars_Fragment_Control_Grip(); }

        return _BlGripNotifies[0];
    }

    private FString Describe_BornLever()
    {
        auto Engages = "";
        for (int32 Index = 0; Index < _BlEngageNotifyFrames.Num(); ++Index)
        { Engages += f"{_BlEngageNotifyFrames[Index]}:{_BlEngageNotifies[Index].IsActive}/{_BlEngageNotifies[Index].Engagements} "; }

        auto Grips = "";
        for (int32 Index = 0; Index < _BlGripNotifyFrames.Num(); ++Index)
        {
            const auto& Ledger = _BlGripNotifies[Index];
            Grips += f"{_BlGripNotifyFrames[Index]}:{Ledger.Grip :n}/{Get_WhoText(Ledger.Gripper)}/s{Ledger.GripSerial}/r{Ledger.RefusalSerial}/p{Ledger.Pull :.2} ";
        }

        auto Events = "";
        for (const auto Frame : _BlEngagedFrames)
        { Events += f"E@{Frame} "; }

        for (int32 Index = 0; Index < _BlActivations.Num(); ++Index)
        { Events += f"A{_BlActivations[Index] :n}@{_BlActivationFrames[Index]} "; }

        for (int32 Index = 0; Index < _BlRefusals.Num(); ++Index)
        { Events += f"R@{_BlRefusalFrames[Index]} "; }

        for (int32 Index = 0; Index < _BlHolderFrom.Num(); ++Index)
        { Events += f"H{_BlHolderFrom[Index] :n}>{_BlHolderTo[Index] :n}@{_BlHolderFrames[Index]} "; }

        auto Samples = "none";
        if (_BlSamples.Num() > 0)
        {
            const auto& FirstSample = _BlSamples[0];
            const auto& LastSample = _BlSamples[_BlSamples.Num() - 1];
            auto Lowest = FirstSample.Shown;
            for (const auto& Sample : _BlSamples)
            { Lowest = Math::Min(Lowest, Sample.Shown); }

            Samples = f"{_BlSamples.Num()} first {FirstSample.Frame}:{FirstSample.Shown :.3}/{FirstSample.Mover :.3} last {LastSample.Frame}:{LastSample.Shown :.3}/{LastSample.Mover :.3} lowest {Lowest :.3}";
        }

        return f"found@{_BlFoundFrame} initialAtFind={_BlEngageInitialAtFind :n}/{_BlGripInitialAtFind :n} "
            + f"initial={Get_BlEngageInitialState() :n}/{Get_BlGripInitialState() :n} engage=[{Engages}] grip=[{Grips}] events=[{Events}] samples=[{Samples}]";
    }

    // A notify can land on a lever already ending.
    UFUNCTION()
    private void OnBornLeverEngageNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Control) == false)
        { return; }

        _BlEngageNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BlEngageNotifies.Add(InHandle.Get_Fragment(FMars_Fragment_Control));
    }

    // A notify can land on a lever already ending.
    UFUNCTION()
    private void OnBornLeverGripNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Control_Grip) == false)
        { return; }

        _BlGripNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _BlGripNotifies.Add(InHandle.Get_Fragment(FMars_Fragment_Control_Grip));
    }

    UFUNCTION()
    private void OnBornLeverEngaged(FCk_Handle_Control InControl)
    {
        _BlEngagedFrames.Add(int32(utils_time::Get_FrameCounter()));
    }

    UFUNCTION()
    private void OnBornLeverActiveChanged(FCk_Handle_Control InControl, EMars_Control_Activation InActivation)
    {
        _BlActivations.Add(InActivation);
        _BlActivationFrames.Add(int32(utils_time::Get_FrameCounter()));
    }

    UFUNCTION()
    private void OnBornLeverGripRefused(FCk_Handle_Control InControl, FCk_Handle InRefused)
    {
        _BlRefusals.Add(InRefused);
        _BlRefusalFrames.Add(int32(utils_time::Get_FrameCounter()));
    }

    UFUNCTION()
    private void OnBornLeverHolderChanged(FCk_Handle_Control InControl, EMars_Control_GripHolder InPrevious, EMars_Control_GripHolder InHolder)
    {
        _BlHolderFrom.Add(InPrevious);
        _BlHolderTo.Add(InHolder);
        _BlHolderFrames.Add(int32(utils_time::Get_FrameCounter()));
    }
}
