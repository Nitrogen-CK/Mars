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

// One OnHealed as a machine raised it.
struct FMars_NetHealthTest_Healed
{
    UPROPERTY()
    float32 Applied = 0.0f;

    UPROPERTY()
    float32 Remaining = 0.0f;
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
    // The signals in the order this machine raised them: H healed, D damaged, X depleted.
    protected FString _Order;

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
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

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
        const auto Line = f"[HealthNetTest] {InRow} {Get_MachineName()} current={Current} attribute={Attribute} depleted={IsDepleted} invulnerable={IsInvulnerable} damaged={_Damaged.Num()} healed={_Healed.Num()} depletedSignals={_Depleted} order={_Order} ledger=[cur {Ledger.Current} d{Ledger.DamageSerial} h{Ledger.HealSerial} x{Ledger.DepletionSerial} {Ledger.Vitality :n}] ensures={Get_NewEnsures()} {InExtra}";
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
    }

    UFUNCTION()
    private void OnHealthHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining)
    {
        auto Record = FMars_NetHealthTest_Healed();
        Record.Applied = InApplied;
        Record.Remaining = InRemaining;
        _Healed.Add(Record);
        _Order += "H";
    }

    UFUNCTION()
    private void OnHealthDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _Depleted += 1;
        _Order += "X";
    }
}
