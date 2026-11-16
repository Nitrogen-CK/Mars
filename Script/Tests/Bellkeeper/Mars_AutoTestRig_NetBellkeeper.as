// The Bellkeeper net tests' shared steps: the server spawns a real Bellkeeper panel under the replicated spawn owner,
// its phrase, rewards and channels in the spawn parameters as a placed panel has them. Each machine finds its panel by
// tag near the test's base once its lock has composed, and records from there what its lock raises (its three signals)
// and what each of its dials raises (index and angle changes), each with its frame; the client also records every
// application of the lock's ledger. The server tracks what it finds for cleanup. Nothing has a floor, so a reward is
// near by its distance in the plane.
UCLASS(Abstract)
class UMars_AutoTestRig_NetBellkeeper : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 25.0f;

    protected const int32 k_SlowPolls = 5000;
    // After the server found its panel, so that what follows is an arrival and not part of the born state.
    protected const float32 k_SettleSeconds = 1.5f;
    // What a client gives the server's last step to arrive before it asserts.
    protected const float32 k_ArriveSeconds = 1.0f;
    protected const float32 k_ServerHoldSeconds = 2.0f;
    protected const float64 k_NearCm = 300.0;

    protected FVector _Base = FVector::ZeroVector;
    protected FCk_Handle _Panel;
    protected FCk_Handle_Bellkeeper _Lock;
    protected int32 _EnsuresAtStart = 0;

    protected int32 _FoundFrame = -1;
    protected EMars_Net_InitialState _InitialAtFind = EMars_Net_InitialState::Awaited;
    protected TArray<int32> _NotifyFrames;
    protected TArray<FMars_Fragment_Bellkeeper_Net> _Notifies;
    protected TArray<int32> _FailedFrames;
    protected TArray<int32> _FailedRemaining;
    protected TArray<int32> _SolvedFrames;
    protected TArray<int32> _StateFrames;
    // One entry per dial signal: the dial's place in panel order, its payload and its frame.
    protected TArray<int32> _IndexChangeDials;
    protected TArray<int32> _IndexChangeValues;
    protected TArray<int32> _IndexChangeFrames;
    protected TArray<int32> _AngleChangeDials;
    protected TArray<float32> _AngleChangeValues;
    protected TArray<int32> _AngleChangeCrossed;
    protected TArray<int32> _AngleChangeFrames;

    protected void Begin_Rig(FVector InBase)
    {
        _Base = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
    }

    protected bool Get_IsServer()
    {
        return utils_net::Get_HasAuthority(Get_SubjectEntity());
    }

    protected int32 Get_NewEnsures() const
    {
        return utils_ensure::Get_EnsureCount() - _EnsuresAtStart;
    }

    protected int32 Get_BellFrame() const
    {
        return int32(utils_time::Get_FrameCounter());
    }

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // The panel the rows spawn: the phrase Circle, Triangle, Diamond (indices 1, 2, 3), every dial starting on Square,
    // three rewards, a commit, a vent and an output channel, a short vent pulse.
    protected FMars_Bellkeeper_EntityScript_SpawnParams Make_PanelParams()
    {
        auto Params = UMars_Bellkeeper_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.Phrase.Add(EMars_Bellkeeper_Glyph::Circle);
        Params.Phrase.Add(EMars_Bellkeeper_Glyph::Triangle);
        Params.Phrase.Add(EMars_Bellkeeper_Glyph::Diamond);
        Params.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Rock()), FTransform(FVector(0.0, -60.0, 50.0))));
        Params.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Cog()), FTransform(FVector(0.0, 0.0, 50.0))));
        Params.Rewards.Add(FMars_Bellkeeper_Reward(utils_held_item::Make_DefinitionSoft(mars_items::Ration()), FTransform(FVector(0.0, 60.0, 50.0))));
        Params.CommitChannel = GameplayTags::Mechanism_Channel_J;
        Params.VentChannel = GameplayTags::Mechanism_Channel_K;
        Params.Source.OutputChannel = GameplayTags::Mechanism_Channel_L;
        Params.VentPulseSeconds = 0.3f;
        return Params;
    }

    // Server: a panel of InClass (the real panel or a test-only leaf of it) at the base, under the spawn owner.
    protected void Spawn_ServerPanel(TSubclassOf<UCk_EntityScript_UE> InClass)
    {
        auto Owner = utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity());
        utils_entity_script::Request_SpawnEntity(Owner, InClass, Make_PanelParams());
    }

    // This machine's panel near the base, once its lock has composed; the first time, recording starts here.
    UFUNCTION()
    protected void Is_PanelFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        if (ck::IsValid(_Lock))
        {
            Result.Set(true);
            return;
        }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsBellkeeper"))
        {
            if (Get_IsNear(Candidate) == false)
            { continue; }

            auto Lock = Candidate.As_Bellkeeper(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Lock))
            { continue; }

            _Panel = Candidate;
            _Lock = Lock;
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            Begin_BellRecord();
            Result.Set(true);
            return;
        }

        Result.Set(false);
    }

    private void Begin_BellRecord()
    {
        _FoundFrame = Get_BellFrame();
        _InitialAtFind = Get_InitialState();
        if (Get_IsServer() == false)
        { _Panel.BindTo_OnRepNotify(FMars_Fragment_Bellkeeper_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnRigLedgerNotify")); }

        _Lock.BindTo_OnCommitFailed(FMars_Delegate_Bellkeeper_OnCommitFailed(this, n"OnRigCommitFailed"));
        _Lock.BindTo_OnSolved(FMars_Delegate_Bellkeeper_OnSolved(this, n"OnRigSolved"));
        _Lock.BindTo_OnStateChanged(FMars_Delegate_Bellkeeper_OnStateChanged(this, n"OnRigStateChanged"));

        auto Dials = _Lock.Get_Dials();
        for (int32 Index = 0; Index < Dials.Num(); ++Index)
        {
            auto Dial = Dials[Index];
            Dial.BindTo_OnIndexChanged(FMars_Delegate_Dial_OnIndexChanged(this, n"OnRigDialIndexChanged"));
            Dial.BindTo_OnAngleChanged(FMars_Delegate_Dial_OnAngleChanged(this, n"OnRigDialAngleChanged"));
        }
    }

    protected bool Get_IsNear(const FCk_Handle& InEntity)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - _Base;
        Offset.Z = 0.0;
        return Offset.Size() < k_NearCm;
    }

    // The lock this machine found, while it is not ending: a copy the server already destroyed is not read.
    protected bool Get_IsLockAlive() const
    {
        return ck::IsValid(_Lock)
            && utils_entity_lifetime::Get_IsPendingDestroy(_Lock, ECk_EntityLifetime_DestructionPhase::BeginDestroy) == false;
    }

    // This machine's copy's level now; Awaited while there is no mirror.
    protected EMars_Net_InitialState Get_InitialState() const
    {
        if (ck::Is_NOT_Valid(_Lock) || _Lock.Has_Fragment(FMars_Fragment_Bellkeeper_Mirror) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Lock.Get_Fragment(FMars_Fragment_Bellkeeper_Mirror).InitialState;
    }

    // The lock's ledger on this machine; the default while there is none.
    protected FMars_Fragment_Bellkeeper_Net Get_Ledger() const
    {
        if (Get_IsLockAlive() == false || _Lock.Has_Fragment(FMars_Fragment_Bellkeeper_Net) == false)
        { return FMars_Fragment_Bellkeeper_Net(); }

        return _Lock.Get_Fragment(FMars_Fragment_Bellkeeper_Net);
    }

    // Where this machine's dials point, in panel order.
    protected TArray<int32> Get_DialIndices() const
    {
        auto Indices = TArray<int32>();
        if (Get_IsLockAlive() == false)
        { return Indices; }

        const auto Dials = _Lock.Get_Dials();
        for (const auto& Dial : Dials)
        { Indices.Add(ck::IsValid(Dial) ? Dial.Get_Index() : -1); }

        return Indices;
    }

    // Whether three indices read InExpected's X, Y and Z, in panel order.
    protected bool Get_IndicesRead(const TArray<int32>& InIndices, const FIntVector& InExpected) const
    {
        return InIndices.Num() == 3 && InIndices[0] == InExpected.X && InIndices[1] == InExpected.Y
            && InIndices[2] == InExpected.Z;
    }

    protected int32 Count_LockedDials() const
    {
        auto Count = 0;
        if (Get_IsLockAlive() == false)
        { return Count; }

        const auto Dials = _Lock.Get_Dials();
        for (const auto& Dial : Dials)
        {
            if (ck::IsValid(Dial) && Dial.Get_IsLocked())
            { Count += 1; }
        }

        return Count;
    }

    // Dials whose Control may be gripped on this machine.
    protected int32 Count_DialsMayGripHere() const
    {
        auto Count = 0;
        if (Get_IsLockAlive() == false)
        { return Count; }

        const auto Dials = _Lock.Get_Dials();
        for (const auto& Dial : Dials)
        {
            const auto Control = Dial.As_Control(ECk_SanityCheck::UnChecked);
            if (ck::IsValid(Control) && Control.Get_MayGripHere())
            { Count += 1; }
        }

        return Count;
    }

    // Detents dial InDial's recorded angle changes crossed; every dial's when InDial is -1.
    protected int32 Get_CrossingsOf(int32 InDial) const
    {
        auto Total = 0;
        for (int32 Index = 0; Index < _AngleChangeDials.Num(); ++Index)
        {
            if (InDial < 0 || _AngleChangeDials[Index] == InDial)
            { Total += _AngleChangeCrossed[Index]; }
        }

        return Total;
    }

    // Index and angle changes dial InDial raised.
    protected int32 Count_DialSignalsOf(int32 InDial) const
    {
        auto Count = 0;
        for (const auto Dial : _IndexChangeDials)
        {
            if (Dial == InDial)
            { Count += 1; }
        }

        for (const auto Dial : _AngleChangeDials)
        {
            if (Dial == InDial)
            { Count += 1; }
        }

        return Count;
    }

    // The crossings of dial InDial's first recorded angle change; unset when it raised none.
    protected TOptional<int32> Get_FirstCrossingsOf(int32 InDial) const
    {
        for (int32 Index = 0; Index < _AngleChangeDials.Num(); ++Index)
        {
            if (_AngleChangeDials[Index] == InDial)
            { return TOptional<int32>(_AngleChangeCrossed[Index]); }
        }

        return TOptional<int32>();
    }

    protected int32 Count_NotifiesAfter(int32 InFrame) const
    {
        auto Count = 0;
        for (const auto Frame : _NotifyFrames)
        {
            if (Frame > InFrame)
            { Count += 1; }
        }

        return Count;
    }

    // World items near the panel on this machine.
    protected int32 Count_WorldItemsNear()
    {
        auto Count = 0;
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsWorldItem"))
        {
            if (Get_IsNear(Candidate))
            { Count += 1; }
        }

        return Count;
    }

    // The one vent near the panel on this machine; invalid while there is none or more than one.
    protected FCk_Handle Find_VentNear()
    {
        auto Found = TArray<FCk_Handle>();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsVent"))
        {
            if (Get_IsNear(Candidate))
            { Found.Add(Candidate); }
        }

        return Found.Num() == 1 ? Found[0] : FCk_Handle();
    }

    protected FString Describe_Indices(const TArray<int32>& InIndices) const
    {
        auto Text = "";
        for (int32 Index = 0; Index < InIndices.Num(); ++Index)
        { Text += Index == 0 ? f"{InIndices[Index]}" : f",{InIndices[Index]}"; }

        return f"[{Text}]";
    }

    protected FString Describe_Ledger(const FMars_Fragment_Bellkeeper_Net& InLedger) const
    {
        return f"{InLedger.FailedCommits}/{InLedger.Lock :n}/{Describe_Indices(InLedger.DialIndices)}";
    }

    // Everything this machine recorded, with frames.
    protected FString Describe_Bell()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _NotifyFrames.Num(); ++Index)
        { Notifies += f"{_NotifyFrames[Index]}:{Describe_Ledger(_Notifies[Index])} "; }

        auto Signals = "";
        for (int32 Index = 0; Index < _FailedFrames.Num(); ++Index)
        { Signals += f"F{_FailedRemaining[Index]}@{_FailedFrames[Index]} "; }

        for (const auto Frame : _SolvedFrames)
        { Signals += f"S@{Frame} "; }

        for (const auto Frame : _StateFrames)
        { Signals += f"L@{Frame} "; }

        auto DialSignals = "";
        for (int32 Index = 0; Index < _IndexChangeDials.Num(); ++Index)
        { DialSignals += f"d{_IndexChangeDials[Index]}i{_IndexChangeValues[Index]}@{_IndexChangeFrames[Index]} "; }

        for (int32 Index = 0; Index < _AngleChangeDials.Num(); ++Index)
        {
            DialSignals += f"d{_AngleChangeDials[Index]}a{_AngleChangeValues[Index]}x{_AngleChangeCrossed[Index]}@{_AngleChangeFrames[Index]} ";
        }

        return f"found@{_FoundFrame} initialAtFind={_InitialAtFind :n} initial={Get_InitialState() :n} notifies=[{Notifies}] signals=[{Signals}] dials=[{DialSignals}]";
    }

    // This machine's line for row InRow, logged and returned for the asserts' messages.
    protected FString Log_BellLine(FString InRow)
    {
        auto State = "lock=gone";
        if (Get_IsLockAlive())
        {
            State = f"failed={_Lock.Get_FailedCommits()} solved={_Lock.Get_IsSolved()} remaining={_Lock.Get_RemainingRewards()} dials={Describe_Indices(Get_DialIndices())} locked={Count_LockedDials()} ledger={Describe_Ledger(Get_Ledger())}";
        }

        const auto Machine = Get_IsServer() ? "server" : "client";
        const auto Line = f"[BellNetTest] {InRow} {Machine}: {State} frame={Get_BellFrame()} ensures={Get_NewEnsures()} {Describe_Bell()}";
        Log(Line);
        return Line;
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    // A notify can land on a lock already ending.
    UFUNCTION()
    private void OnRigLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Bellkeeper_Net) == false)
        { return; }

        _NotifyFrames.Add(Get_BellFrame());
        _Notifies.Add(InHandle.Get_Fragment(FMars_Fragment_Bellkeeper_Net));
    }

    UFUNCTION()
    private void OnRigCommitFailed(FCk_Handle_Bellkeeper InBellkeeper, int32 InRemainingRewards)
    {
        _FailedFrames.Add(Get_BellFrame());
        _FailedRemaining.Add(InRemainingRewards);
    }

    UFUNCTION()
    private void OnRigSolved(FCk_Handle_Bellkeeper InBellkeeper)
    {
        _SolvedFrames.Add(Get_BellFrame());
    }

    UFUNCTION()
    private void OnRigStateChanged(FCk_Handle_Bellkeeper InBellkeeper)
    {
        _StateFrames.Add(Get_BellFrame());
    }

    UFUNCTION()
    private void OnRigDialIndexChanged(FCk_Handle_Dial InDial, int32 InIndex)
    {
        _IndexChangeDials.Add(Get_DialPlace(InDial));
        _IndexChangeValues.Add(InIndex);
        _IndexChangeFrames.Add(Get_BellFrame());
    }

    UFUNCTION()
    private void OnRigDialAngleChanged(FCk_Handle_Dial InDial, float32 InAngle, int32 InDetentsCrossed)
    {
        _AngleChangeDials.Add(Get_DialPlace(InDial));
        _AngleChangeValues.Add(InAngle);
        _AngleChangeCrossed.Add(InDetentsCrossed);
        _AngleChangeFrames.Add(Get_BellFrame());
    }

    private int32 Get_DialPlace(const FCk_Handle_Dial& InDial) const
    {
        if (ck::Is_NOT_Valid(_Lock))
        { return -1; }

        const auto Dials = _Lock.Get_Dials();
        return Dials.FindIndex(InDial);
    }
}
