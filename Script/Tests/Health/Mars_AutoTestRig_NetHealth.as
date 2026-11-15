// One OnDamaged as a machine raised it, with the frame it was raised in.
struct FMars_NetHealthTest_Damaged
{
    UPROPERTY()
    FMars_DamageEvent Event;

    UPROPERTY()
    float32 Applied = 0.0f;

    UPROPERTY()
    float32 Remaining = 0.0f;

    UPROPERTY()
    int32 Frame = 0;
}

// One OnHealed as a machine raised it, with the frame it was raised in.
struct FMars_NetHealthTest_Healed
{
    UPROPERTY()
    float32 Applied = 0.0f;

    UPROPERTY()
    float32 Remaining = 0.0f;

    UPROPERTY()
    int32 Frame = 0;
}

// A harness fixture, not a feature: a combat target whose copy is born into the heals and hits its authority asked for
// in its construct. The Health drain applies them in the spawn frame (every heal before every hit, whatever the order
// asked), so the copy's first ledger carries them. The spawn params, by the script's ExposeOnSpawn names.
struct FMars_NetCombat_BornTarget_SpawnParams
{
    UPROPERTY()
    FTransform SpawnTransform = FTransform::Identity;

    UPROPERTY()
    float32 MaxHealth = 100.0f;

    UPROPERTY()
    ECk_Team_ID Team = ECk_Team_ID::Two;

    UPROPERTY()
    ECk_EnableDisable LimbZone = ECk_EnableDisable::Disable;

    UPROPERTY()
    TArray<float32> BornHeals;

    UPROPERTY()
    TArray<float32> BornHits;
}

class UMars_TESTONLY_NetCombat_BornTarget_EntityScript : UMars_NetCombat_Target_EntityScript
{
    // Heals asked of the authority's Health in the construct.
    UPROPERTY(ExposeOnSpawn)
    TArray<float32> BornHeals;

    // Sever hits asked of the authority's Health in the construct, each landing at the spawn place, normal up.
    UPROPERTY(ExposeOnSpawn)
    TArray<float32> BornHits;

    UFUNCTION(BlueprintOverride)
    ECk_EntityScript_ConstructionFlow DoConstruct(FCk_Handle& InHandle)
    {
        const auto Flow = Super::DoConstruct(InHandle);
        const auto HasAuthority = utils_net::Get_HasAuthority(InHandle);
        if (HasAuthority == false)
        { return Flow; }

        auto Health = InHandle.As_Health(ECk_SanityCheck::UnChecked);
        if (ck::EnsureIfNot(ck::IsValid(Health), f"[HealthNetTest] [{InHandle.ToString()}] composed no Health"))
        { return Flow; }

        for (const auto Amount : BornHeals)
        { Health.Request_Heal(FMars_Request_Health_Heal(Amount)); }

        for (const auto Amount : BornHits)
        {
            auto Event = FMars_DamageEvent(Amount, GameplayTags::DamageType_Mars_Sever);
            Event.Hit.Location = SpawnTransform.GetLocation();
            Event.Hit.Normal = FVector::UpVector;
            Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Event));
        }

        return Flow;
    }
}

// The Health net tests' shared steps: the server spawns a combat target under the replicated spawn owner at the row's
// base; each machine finds its copy by tag near the base, takes its Health and records every OnDamaged, OnHealed and
// OnDepleted its own copy raises, in order. The server tracks the target for cleanup and acts on its Health directly.
UCLASS(Abstract)
class UMars_AutoTestRig_NetHealth : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    protected const int32 k_SlowPolls = 5000;
    // A client asserts once the last server step has had this long to arrive.
    protected const float32 k_SettleSeconds = 1.0f;
    // The server waits this long after it finds its target, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    // The server holds this long after its last write before it finishes and its cleanup replicates.
    protected const float32 k_ServerHoldSeconds = 2.0f;
    protected const float64 k_NearCm = 400.0;
    protected const float32 k_MaxHealth = 100.0f;

    protected FVector _Base = FVector::ZeroVector;
    protected FCk_Handle _Target;
    protected FCk_Handle_Health _Health;
    protected int32 _EnsuresAtStart = 0;

    protected TArray<FMars_NetHealthTest_Damaged> _Damaged;
    protected TArray<FMars_NetHealthTest_Healed> _Healed;
    protected int32 _Depleted = 0;
    // The frame counter at each OnDepleted.
    protected TArray<int32> _DepletedFrames;
    // The signals in the order this machine raised them: H healed, D damaged, X depleted.
    protected FString _Order;

    // The frame counter when this machine first found its target; -1 before.
    protected int32 _TargetFoundFrame = -1;
    // The copy's InitialState as this machine read it when it found the target.
    protected EMars_Net_InitialState _TargetInitialAtFind = EMars_Net_InitialState::Awaited;
    // Off authority: each rep-notify of the copy's ledger, its frame counter and the ledger as it then read.
    protected TArray<int32> _TargetNotifyFrames;
    protected TArray<FMars_Fragment_Health_Net> _TargetNotifyLedgers;
    // The signals with their frames, in the order this machine raised them.
    private FString _TargetEventsText;

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

    protected FString Get_MachineName()
    {
        return Get_IsServer() ? "server" : "client";
    }

    UFUNCTION()
    protected void Is_ReplicatedSpawnOwnerPublished(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()));
    }

    // Server: the target at the base, under the replicated spawn owner.
    protected void Spawn_ServerTarget()
    {
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Target_EntityScript, FMars_NetCombat_Target_SpawnParams(FTransform(FRotator::ZeroRotator, _Base), k_MaxHealth));
    }

    // Server: a target at the base, under the replicated spawn owner, born into InHeals and then InHits.
    protected void Spawn_ServerBornTarget(TArray<float32> InHeals, TArray<float32> InHits)
    {
        auto Params = FMars_NetCombat_BornTarget_SpawnParams();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base);
        Params.MaxHealth = k_MaxHealth;
        Params.BornHeals = InHeals;
        Params.BornHits = InHits;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_TESTONLY_NetCombat_BornTarget_EntityScript, Params);
    }

    UFUNCTION()
    protected void Is_TargetFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsTargetFound());
    }

    // This machine's copy of the target near the base has composed its Health; the first time, its signals are recorded
    // from here (and the server tracks it).
    protected bool Get_IsTargetFound()
    {
        if (ck::IsValid(_Health))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetCombatTarget"))
        {
            if (Get_IsNear(Candidate) == false)
            { continue; }

            auto Health = Candidate.As_Health(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Health))
            { continue; }

            _Target = Candidate;
            _Health = Health;
            _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnHealthDamaged"));
            _Health.BindTo_OnHealed(FMars_Delegate_Health_OnHealed(this, n"OnHealthHealed"));
            _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnHealthDepleted"));
            _TargetFoundFrame = int32(utils_time::Get_FrameCounter());
            _TargetInitialAtFind = Get_TargetInitialState();
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }
            else
            { _Target.BindTo_OnRepNotify(FMars_Fragment_Health_Net, FCk_DynamicFragment_OnRepNotify(this, n"OnTargetLedgerNotify")); }

            return true;
        }

        return false;
    }

    protected bool Get_IsNear(FCk_Handle InEntity)
    {
        const auto Transform = InEntity.As_Transform(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Transform))
        { return false; }

        auto Offset = utils_transform::Get_EntityCurrentTransform(Transform).GetLocation() - _Base;
        Offset.Z = 0.0;
        return Offset.Size() < k_NearCm;
    }

    // This machine's ledger; a default one until its target is found.
    protected FMars_Fragment_Health_Net Get_Ledger()
    {
        if (ck::Is_NOT_Valid(_Health))
        { return FMars_Fragment_Health_Net(); }

        return _Health.Get_Fragment(FMars_Fragment_Health_Net);
    }

    protected bool Get_IsCurrent(float32 InExpected)
    {
        return ck::IsValid(_Health) && Math::IsNearlyEqual(_Health.Get_Current(), InExpected, 0.01f);
    }

    // Server: a hit of InAmount Sever straight onto its Health, landing at InLocation with InNormal.
    protected void Request_ServerHit(float32 InAmount, FVector InLocation, FVector InNormal)
    {
        auto Event = FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever);
        Event.Hit.Location = InLocation;
        Event.Hit.Normal = InNormal;
        _Health.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(Event));
    }

    // This machine's copy's level now; Awaited while there is none.
    protected EMars_Net_InitialState Get_TargetInitialState()
    {
        if (ck::Is_NOT_Valid(_Health) || _Health.Has_Fragment(FMars_Fragment_Health_Local) == false)
        { return EMars_Net_InitialState::Awaited; }

        return _Health.Get_Fragment(FMars_Fragment_Health_Local).InitialState;
    }

    // The ledger the first recorded rep-notify read; the composed default while none is recorded.
    protected FMars_Fragment_Health_Net Get_TargetFirstNotifyLedger() const
    {
        if (_TargetNotifyLedgers.Num() == 0)
        { return FMars_Fragment_Health_Net(); }

        return _TargetNotifyLedgers[0];
    }

    protected int32 Get_TargetFirstNotifyFrame() const
    {
        if (_TargetNotifyFrames.Num() == 0)
        { return -1; }

        return _TargetNotifyFrames[0];
    }

    // OnDamaged this machine raised after InFrame.
    protected int32 Count_DamagedAfter(int32 InFrame) const
    {
        auto Count = 0;
        for (const auto& Record : _Damaged)
        {
            if (Record.Frame > InFrame)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_TargetFind()
    {
        auto Notifies = "";
        for (int32 Index = 0; Index < _TargetNotifyFrames.Num(); ++Index)
        {
            const auto& Ledger = _TargetNotifyLedgers[Index];
            Notifies += f"{_TargetNotifyFrames[Index]}:{Ledger.Current}/d{Ledger.DamageSerial}/h{Ledger.HealSerial}/x{Ledger.DepletionSerial}/{Ledger.Vitality :n} ";
        }

        return f"found@{_TargetFoundFrame} initialAtFind={_TargetInitialAtFind :n} initial={Get_TargetInitialState() :n} "
            + f"notifies=[{Notifies}] events=[{_TargetEventsText}]";
    }

    // The row's one log line on this machine: what its Health reads (and its local attribute), what it raised, its ledger.
    protected void Log_Row(FString InRow, FString InExtra)
    {
        const auto Ledger = Get_Ledger();
        const auto IsFound = ck::IsValid(_Health);
        const auto Current = IsFound ? _Health.Get_Current() : -1.0f;
        const auto Attribute = IsFound
            ? utils_float_attribute::Get_FinalValue(_Health.Get_Fragment(FMars_Fragment_Health).Attribute, ECk_MinMaxCurrent::Current) : -1.0f;
        const auto IsDepleted = IsFound && _Health.Get_IsDepleted();
        const auto IsInvulnerable = IsFound && _Health.Get_IsInvulnerable();
        const auto Line = f"[HealthNetTest] {InRow} {Get_MachineName()} current={Current} attribute={Attribute} depleted={IsDepleted} invulnerable={IsInvulnerable} damaged={_Damaged.Num()} healed={_Healed.Num()} depletedSignals={_Depleted} order={_Order} ledger=[cur {Ledger.Current} d{Ledger.DamageSerial} h{Ledger.HealSerial} x{Ledger.DepletionSerial} {Ledger.Vitality :n}] ensures={Get_NewEnsures()} {InExtra} {Describe_TargetFind()}";
        Log(Line);
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void OnHealthDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        auto Record = FMars_NetHealthTest_Damaged();
        Record.Event = InEvent;
        Record.Applied = InApplied;
        Record.Remaining = InRemaining;
        Record.Frame = int32(utils_time::Get_FrameCounter());
        _Damaged.Add(Record);
        _Order += "D";
        _TargetEventsText += f"D@{Record.Frame} ";
    }

    UFUNCTION()
    private void OnHealthHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining)
    {
        auto Record = FMars_NetHealthTest_Healed();
        Record.Applied = InApplied;
        Record.Remaining = InRemaining;
        Record.Frame = int32(utils_time::Get_FrameCounter());
        _Healed.Add(Record);
        _Order += "H";
        _TargetEventsText += f"H@{Record.Frame} ";
    }

    UFUNCTION()
    private void OnHealthDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        const auto Frame = int32(utils_time::Get_FrameCounter());
        _Depleted += 1;
        _DepletedFrames.Add(Frame);
        _Order += "X";
        _TargetEventsText += f"X@{Frame} ";
    }

    // A notify can land on a target already ending.
    UFUNCTION()
    private void OnTargetLedgerNotify(FCk_Handle InHandle, FCk_DynamicFragment_RepNotifyInfo InInfo)
    {
        if (ck::Is_NOT_Valid(InHandle) || InHandle.Has_Fragment(FMars_Fragment_Health_Net) == false)
        { return; }

        _TargetNotifyFrames.Add(int32(utils_time::Get_FrameCounter()));
        _TargetNotifyLedgers.Add(InHandle.Get_Fragment(FMars_Fragment_Health_Net));
    }
}
