// The Root Maw net tests' shared steps, on top of the strike rig (whose striker only the strike row composes): the
// server lays a static floor owned by the subject, spawns a Maw through its real entity script under the replicated
// spawn owner (its root Clearance above the floor, facing +X, without visuals) and, when a row needs one, a prey
// stand-in owned by the subject (so it exists on the server only). Each machine finds its copy by tag near the base,
// takes its Maw, its monster's body Health and body zone, counts the OnStance and the OnDied its own copy raises and
// the OnDamaged of its body Health, records the OnActionPhase (with its frame) and counts the OnBlowLanded its copy
// raises, and samples it from the row's polled predicates: the largest distance the root moved between two samples,
// the highest Emerge, the first frame its ledger read Emerged, the widest jaw while its action read Windup, the lowest
// while it read Recover, the widest since its flinch count last changed, and whether it ever read flinching.
struct FMars_NetRootMawTest_Phase
{
    UPROPERTY()
    EMars_RootMaw_Action Action = EMars_RootMaw_Action::None;

    UPROPERTY()
    EMars_RootMaw_ActionPhase Phase = EMars_RootMaw_ActionPhase::None;

    UPROPERTY()
    int32 Frame = -1;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetRootMaw : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    // The server waits this long once its Maw reads grounded before a row's next step.
    protected const float32 k_StandSeconds = 2.0f;
    protected const FVector k_FloorHalfExtents = FVector(1500.0, 1500.0, 10.0);
    protected const float64 k_BodyDropBuried = 108.0;
    protected const float64 k_BodyDropEmerged = 30.0;

    protected FCk_Handle_RootMaw _Maw;
    protected FCk_Handle_Monster _MawMonster;
    protected FCk_Handle_Transform _PreyRoot;

    protected int32 _MawEmergedStances = 0;
    protected int32 _MawBuriedStances = 0;
    protected int32 _MawEmergedFrame = -1;
    protected int32 _MawDied = 0;
    protected int32 _MawDamaged = 0;
    protected int32 _MawLedgerEmergedFrame = -1;
    protected float64 _MawLargestStep = 0.0;
    protected float32 _MawHighestEmerge = 0.0f;
    protected FVector _MawFoundAt = FVector::ZeroVector;
    protected FCk_Handle_Health _PreyHealth;
    protected TArray<FMars_NetRootMawTest_Phase> _MawPhases;
    protected int32 _MawBlows = 0;
    protected float32 _MawWidestInWindup = -1.0f;
    protected float32 _MawLowestInRecover = 2.0f;
    protected float32 _MawWidestSinceFlinch = -1.0f;
    protected bool _MawEverFlinched = false;
    private int32 _MawFlinchCountSeen = 0;
    private TOptional<FVector> _MawLastSample;
    private float64 _MawSampleUntil = 0.0;

    // A row without the striker: the base, the target point and the ensure count, nothing composed.
    protected void Begin_MawRow(FVector InBase)
    {
        _Base = InBase;
        _TargetAt = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the floor, the Maw, the prey
    //----------------------------------------------------------------------------------------------------------------------

    // A static Jolt box whose top face is at the base's Z, owned by the subject (it dies with the test).
    protected void Spawn_ServerMawFloor()
    {
        auto Subject = Get_SubjectEntity();
        auto Box = utils_entity_lifetime::Request_CreateEntity(Subject);
        utils_transform::Add(Box, FTransform(FRotator::ZeroRotator, _Base - FVector(0.0, 0.0, k_FloorHalfExtents.Z)),
            ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_FloorHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
    }

    // The Maw under the replicated spawn owner, its root Clearance above the base, facing +X.
    protected void Spawn_ServerMaw(FMars_RootMaw_Spec InSpec)
    {
        auto Params = UMars_RootMaw_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + FVector(0.0, 0.0, utils_root_maw::Clearance));
        Params.Spec = InSpec;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_RootMaw_EntityScript, Params);
    }

    // The single-machine rig's prey stand-in at InOffset from the base (its root 90 up), owned by the subject: team One
    // (Hostile to the Maw), Health 100, a flesh body zone with one box hurtbox, TAG_MarsCombatTarget last.
    protected void Spawn_ServerPrey(FVector InOffset)
    {
        auto Subject = Get_SubjectEntity();
        auto Entity = utils_entity_lifetime::Request_CreateEntity(Subject);
        _PreyRoot = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, Get_PreyLocation(InOffset)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Entity, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _PreyHealth = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Entity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        utils_hit_zone::AddHurtbox_Box(Zone, _PreyRoot, FMars_HitZone_Hurtbox(FVector(35.0, 35.0, 90.0), FTransform::Identity));
        utils_entity_tag::Add(Entity, n"TAG_MarsCombatTarget");
    }

    protected void Move_ServerPrey(FVector InOffset)
    {
        utils_transform::Request_SetLocation(_PreyRoot, FCk_Request_Transform_SetLocation(Get_PreyLocation(InOffset)));
    }

    protected FVector Get_PreyLocation(FVector InOffset) const
    {
        return _Base + InOffset + FVector(0.0, 0.0, 90.0);
    }

    // A Sever hit of InAmount on this machine's copy of the body zone, with no instigator.
    protected void Hit_MawZone(float32 InAmount)
    {
        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_MawFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMawFound());
    }

    // This machine's copy near the base has composed; the first time, its signals are counted from here (and the server
    // tracks it).
    protected bool Get_IsMawFound()
    {
        if (ck::IsValid(_Maw))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsRootMaw"))
        {
            if (Get_IsNear(Candidate, _Base) == false)
            { continue; }

            auto Maw = Candidate.As_RootMaw(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Maw))
            { continue; }

            _Maw = Maw;
            _MawMonster = Maw.Get_Monster();
            _Target = Candidate;
            _Health = _MawMonster.Get_BodyHealth();
            _Zone = _MawMonster.Get_BodyZone();
            _MawFoundAt = Maw.Get_Location();
            _Maw.BindTo_OnStance(FMars_Delegate_RootMaw_OnStance(this, n"OnMawStance"));
            _MawMonster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnMawDied"));
            _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnMawDamaged"));
            _Maw.BindTo_OnActionPhase(FMars_Delegate_RootMaw_OnActionPhase(this, n"OnMawActionPhase"));
            _Maw.BindTo_OnBlowLanded(FMars_Delegate_RootMaw_OnBlowLanded(this, n"OnMawBlowLanded"));
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            Sample_Maw();
            return true;
        }

        return false;
    }

    UFUNCTION()
    protected void Is_MawStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && _Maw.Get_IsGrounded());
    }

    UFUNCTION()
    protected void Is_MawEmerged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && _Maw.Get_IsEmerged());
    }

    UFUNCTION()
    protected void Is_MawDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && _Maw.Get_IsDead());
    }

    UFUNCTION()
    protected void Is_MawGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMawGone());
    }

    protected bool Get_IsMawGone()
    {
        FCk_Handle Entity = _Maw;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    // The root's distance past the base along X (-1 until found).
    protected float64 Get_MawPastBase()
    {
        if (ck::Is_NOT_Valid(_Maw))
        { return -1.0; }

        return _Maw.Get_Location().X - _Base.X;
    }

    // The root's height over the body node (108 buried, 30 up).
    protected float64 Get_MawBodyDrop()
    {
        return _Maw.Get_Location().Z - _Maw.Get_BodyTransform().GetLocation().Z;
    }

    protected bool Get_HasMawLedger()
    {
        return ck::IsValid(_Maw) && _Maw.Has_Fragment(FMars_Fragment_RootMaw_Net);
    }

    // The copy's ledger; a default one when it has none (a row asserts Get_HasMawLedger first).
    protected FMars_Fragment_RootMaw_Net Get_MawLedger()
    {
        if (Get_HasMawLedger() == false)
        { return FMars_Fragment_RootMaw_Net(); }

        return _Maw.Get_Fragment(FMars_Fragment_RootMaw_Net);
    }

    // One sample of this machine's copy: the step since the last sample, the highest Emerge, the ledger's first
    // Emerged.
    protected void Sample_Maw()
    {
        if (Get_IsMawGone())
        { return; }

        const auto Here = _Maw.Get_Location();
        if (_MawLastSample.IsSet())
        { _MawLargestStep = Math::Max(_MawLargestStep, (Here - _MawLastSample.GetValue()).Size()); }

        _MawLastSample = Here;
        _MawHighestEmerge = Math::Max(_MawHighestEmerge, _Maw.Get_Emerge());
        if (_MawLedgerEmergedFrame < 0 && Get_HasMawLedger() && Get_MawLedger().Stance == EMars_RootMaw_Stance::Emerged)
        { _MawLedgerEmergedFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Jaw = _Maw.Get_JawOpen();
        const auto Phase = _Maw.Get_Action().Phase;
        if (Phase == EMars_RootMaw_ActionPhase::Windup)
        { _MawWidestInWindup = Math::Max(_MawWidestInWindup, Jaw); }

        if (Phase == EMars_RootMaw_ActionPhase::Recover)
        { _MawLowestInRecover = Math::Min(_MawLowestInRecover, Jaw); }

        const auto FlinchCount = _Maw.Get_Hurt().FlinchCount;
        if (FlinchCount != _MawFlinchCountSeen)
        {
            _MawFlinchCountSeen = FlinchCount;
            _MawWidestSinceFlinch = Jaw;
        }
        else
        { _MawWidestSinceFlinch = Math::Max(_MawWidestSinceFlinch, Jaw); }

        _MawEverFlinched = _MawEverFlinched || _Maw.Get_IsFlinching();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The recorded phases
    //----------------------------------------------------------------------------------------------------------------------

    // Where a phase falls in a bite: Windup, Active, Recover, None.
    private int32 Get_PhaseRank(EMars_RootMaw_ActionPhase InPhase) const
    {
        if (InPhase == EMars_RootMaw_ActionPhase::Windup)
        { return 0; }

        if (InPhase == EMars_RootMaw_ActionPhase::Active)
        { return 1; }

        if (InPhase == EMars_RootMaw_ActionPhase::Recover)
        { return 2; }

        return 3;
    }

    private int32 Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase InPhase, int32 InFrom) const
    {
        for (auto Index = InFrom; Index < _MawPhases.Num(); ++Index)
        {
            if (_MawPhases[Index].Phase == InPhase)
            { return Index; }
        }

        return -1;
    }

    // A None was recorded after a Windup.
    protected bool Get_HasMawBiteEnded() const
    {
        const auto WindupAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::Windup, 0);
        return WindupAt >= 0 && Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::None, WindupAt + 1) >= 0;
    }

    // From the first Windup to the first None after it, each phase later than the one before.
    protected bool Get_AreMawPhasesInOrder() const
    {
        const auto WindupAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::Windup, 0);
        if (WindupAt < 0)
        { return false; }

        const auto EndedAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::None, WindupAt + 1);
        if (EndedAt < 0)
        { return false; }

        for (auto Index = WindupAt + 1; Index <= EndedAt; ++Index)
        {
            if (Get_PhaseRank(_MawPhases[Index].Phase) <= Get_PhaseRank(_MawPhases[Index - 1].Phase))
            { return false; }
        }

        return true;
    }

    protected int32 Count_MawPhases(EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase) const
    {
        auto Count = 0;
        for (const auto& Recorded : _MawPhases)
        {
            if (Recorded.Action == InAction && Recorded.Phase == InPhase)
            { ++Count; }
        }

        return Count;
    }

    protected FString Describe_MawPhases() const
    {
        FString Text = "";
        for (const auto& Recorded : _MawPhases)
        { Text += f"{Recorded.Action :n}/{Recorded.Phase :n}@{Recorded.Frame},"; }

        return Text;
    }

    UFUNCTION()
    protected void Is_MawBiteEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && Get_HasMawBiteEnded());
        Sample_Maw();
    }

    // A wall-clock settle that keeps sampling the copy every frame, then InContinuation.
    protected void WaitSampling(float32 InSeconds, FName InContinuation)
    {
        _MawSampleUntil = Get_WorldSeconds() + InSeconds;
        WaitUntil(n"Is_MawSampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_MawSampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Maw();
        auto Result = OutResult;
        Result.Set(Get_WorldSeconds() >= _MawSampleUntil);
    }

    protected float64 Get_WorldSeconds()
    {
        const auto SubjectWorld = utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
        return float64(SubjectWorld.GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line and the finish
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_MawRow(FString InRow, FString InExtra)
    {
        const auto IsFound = Get_IsMawGone() == false;
        const auto Stance = IsFound ? f"{_Maw.Get_Stance() :n}" : FString("gone");
        const auto Emerge = IsFound ? _Maw.Get_Emerge() : -1.0f;
        const auto Jaw = IsFound ? _Maw.Get_JawOpen() : -1.0f;
        const auto Location = IsFound ? _Maw.Get_Location() : FVector::ZeroVector;
        const auto Travelled = IsFound ? _Maw.Get_DistanceTravelled() : -1.0;
        const auto Drop = IsFound ? Get_MawBodyDrop() : -1.0;
        FString LedgerText = "none";
        if (IsFound && Get_HasMawLedger())
        {
            const auto Ledger = Get_MawLedger();
            LedgerText = f"{Ledger.Stance :n} {Ledger.Gape} action {Ledger.Action.Kind :n}/{Ledger.Action.Phase :n}/{Ledger.Action.Generation} flinch {Ledger.Flinch.Count}/{Ledger.Flinch.FoundIn :n}/{Ledger.Flinch.From.ToString()}";
        }

        FString ActionText = "none";
        if (IsFound)
        {
            const auto Action = _Maw.Get_Action();
            const auto Hurt = _Maw.Get_Hurt();
            ActionText = f"{Action.Kind :n}/{Action.Phase :n}/{Action.Generation} elapsed {Action.PhaseElapsed} flinches {Hurt.FlinchCount}/{Hurt.FlinchFoundIn :n} flinchLeft {Hurt.FlinchLeft}";
        }

        const auto Body = IsFound && ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto Phases = Describe_MawPhases();
        const auto Line = f"[RootMawNetTest] {InRow} {Get_MachineName()} stance={Stance} emerge={Emerge} jaw={Jaw} root={Location.ToString()} drop={Drop} travelled={Travelled} largestStep={_MawLargestStep} highestEmerge={_MawHighestEmerge} ledger=[{LedgerText}] ledgerEmergedFrame={_MawLedgerEmergedFrame} onEmerged={_MawEmergedStances} onBuried={_MawBuriedStances} emergedFrame={_MawEmergedFrame} died={_MawDied} damaged={_MawDamaged} body={Body} action=[{ActionText}] phases=[{Phases}] blows={_MawBlows} widestWindup={_MawWidestInWindup} lowestRecover={_MawLowestInRecover} widestSinceFlinch={_MawWidestSinceFlinch} everFlinched={_MawEverFlinched} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    protected void Finish_MawRow(FString InRow, FString InExtra)
    {
        Log_MawRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_MawServerRow(FString InRow, FString InExtra)
    {
        Log_MawRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnMawStance(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Stance InStance)
    {
        if (InStance == EMars_RootMaw_Stance::Emerged)
        {
            _MawEmergedStances += 1;
            if (_MawEmergedFrame < 0)
            { _MawEmergedFrame = int32(utils_time::Get_FrameCounter()); }

            return;
        }

        _MawBuriedStances += 1;
    }

    UFUNCTION()
    private void OnMawActionPhase(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase)
    {
        auto Recorded = FMars_NetRootMawTest_Phase();
        Recorded.Action = InAction;
        Recorded.Phase = InPhase;
        Recorded.Frame = int32(utils_time::Get_FrameCounter());
        _MawPhases.Add(Recorded);
    }

    UFUNCTION()
    private void OnMawBlowLanded(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, FCk_Handle_HitZone InZone)
    {
        _MawBlows += 1;
    }

    UFUNCTION()
    private void OnMawDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        _MawDied += 1;
    }

    UFUNCTION()
    private void OnMawDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _MawDamaged += 1;
    }
}
