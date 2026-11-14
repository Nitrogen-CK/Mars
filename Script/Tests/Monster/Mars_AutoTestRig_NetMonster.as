// The monster net tests' shared steps: the server spawns a test monster under the replicated spawn owner at the row's
// base and tracks it for cleanup; each machine finds its copy by tag near the base, takes its monster handle, counts the
// OnDied its own copy raises (keeping the last cause and the frame it was raised in) and reads its Dead attribute.
UCLASS(Abstract)
class UMars_AutoTestRig_NetMonster : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 20.0f;

    protected const int32 k_SlowPolls = 5000;
    // A client asserts once the last server step has had this long to arrive.
    protected const float32 k_SettleSeconds = 1.0f;
    // The server waits this long after it finds its monster, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    // The server holds this long after its last write before it finishes and its cleanup replicates.
    protected const float32 k_ServerHoldSeconds = 2.0f;
    protected const float64 k_NearCm = 400.0;

    protected FVector _Base = FVector::ZeroVector;
    protected FCk_Handle _Root;
    protected FCk_Handle_Monster _Monster;
    protected int32 _EnsuresAtStart = 0;

    protected int32 _Died = 0;
    protected FMars_DamageEvent _LastCause;
    protected int32 _DiedFrame = -1;

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

    // Server: a monster with InPartCount parts at the base, under the replicated spawn owner.
    protected void Spawn_ServerMonster(int32 InPartCount)
    {
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_NetCombat_Monster_EntityScript,
            FMars_NetCombat_Monster_SpawnParams(FTransform(FRotator::ZeroRotator, _Base), InPartCount));
    }

    UFUNCTION()
    protected void Is_MonsterFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound());
    }

    UFUNCTION()
    protected void Is_Dead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMonsterFound() && _Monster.Get_IsDead());
    }

    // This machine's copy of the monster near the base has composed; the first time, its OnDied is counted from here (and
    // the server tracks it).
    protected bool Get_IsMonsterFound()
    {
        if (ck::IsValid(_Monster))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsTestNetMonster"))
        {
            if (Get_IsNear(Candidate) == false)
            { continue; }

            auto Monster = Candidate.As_Monster(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Monster))
            { continue; }

            _Root = Candidate;
            _Monster = Monster;
            _Monster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnMonsterDied"));
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

    // The Dead attribute's current value on this machine's copy; -1 until the monster is found.
    protected int32 Get_DeadValue()
    {
        if (ck::Is_NOT_Valid(_Monster))
        { return -1; }

        return int32(_Monster.Get_DeadAttribute().Get_FinalValue());
    }

    // Server: a hit of InAmount Sever straight onto the body Health.
    protected void Request_ServerBodyHit(float32 InAmount)
    {
        auto BodyHealth = _Monster.Get_BodyHealth();
        BodyHealth.Request_ApplyDamage(FMars_Request_Health_ApplyDamage(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    protected void Request_BluntDie(float32 InAmount)
    {
        _Monster.Request_Die(FMars_Request_Monster_Die(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Blunt)));
    }

    protected bool Get_IsLastCause(FGameplayTag InDamageType, float32 InAmount)
    {
        return _LastCause.DamageType == InDamageType && Math::IsNearlyEqual(_LastCause.Amount, InAmount, 0.01f);
    }

    // The row's one log line on this machine: what its monster reads, what it raised, its ledger.
    protected void Log_Row(FString InRow, FString InExtra)
    {
        const auto IsFound = ck::IsValid(_Monster);
        const auto IsDead = IsFound && _Monster.Get_IsDead();
        const auto BodyCurrent = IsFound ? _Monster.Get_BodyHealth().Get_Current() : -1.0f;
        const auto IsDepleted = IsFound && _Monster.Get_BodyHealth().Get_IsDepleted();
        const auto Parts = IsFound ? _Monster.Get_Parts().Num() : -1;
        const auto Attached = IsFound ? _Monster.Get_AttachedPartCount() : -1;
        const auto HasLedger = IsFound && _Monster.Has_Fragment(FMars_Fragment_Monster_Net);
        FString LedgerText = "none";
        if (HasLedger)
        {
            const auto Ledger = _Monster.Get_Fragment(FMars_Fragment_Monster_Net);
            LedgerText = f"{Ledger.Life :n} {Ledger.DeathCause.DamageType} {Ledger.DeathCause.Amount}";
        }

        const auto Line = f"[MonsterNetTest] {InRow} {Get_MachineName()} dead={IsDead} deadAttribute={Get_DeadValue()} died={_Died} cause=[{_LastCause.DamageType} {_LastCause.Amount}] diedFrame={_DiedFrame} body={BodyCurrent} depleted={IsDepleted} parts={Parts} attached={Attached} ledger=[{LedgerText}] ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        FinishSuccess();
    }

    UFUNCTION()
    private void OnMonsterDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        ++_Died;
        _LastCause = InCause;
        _DiedFrame = int32(utils_time::Get_FrameCounter());
    }
}
