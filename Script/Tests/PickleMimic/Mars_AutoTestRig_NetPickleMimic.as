// The Pickle Mimic net tests' shared steps, on top of the strike rig (whose striker only the strike row composes): each
// machine lays its own static floor owned by its subject (a copy's walker finds its ground in this machine's world),
// the server spawns a mimic through its real entity script under the replicated spawn owner (its root Clearance above the
// floor, facing +X, without visuals, spilling nothing) and, when a row needs one, a prey stand-in owned by the subject
// (so it exists on the server only). Each machine finds its copy by tag near the base, takes its mimic, its monster's
// body Health and body zone, counts the OnStance, the OnDied and the OnSpill its own copy raises and the OnDamaged of
// its body Health, records the OnActionPhase (with its frame) and counts the OnBlowLanded its copy raises, and samples
// it from the row's polled predicates: the largest distance the root moved between two samples, the highest Rise, the
// first frame its ledger read Standing, the widest lid while its action read Windup, the lowest while it read Recover,
// the widest since its flinch count last changed, whether it ever read flinching, whether its gait ever read Failed,
// and, between Begin_FeetRecord and the row's end, its feet.
struct FMars_NetPickleMimicTest_Phase
{
    UPROPERTY()
    EMars_PickleMimic_Action Action = EMars_PickleMimic_Action::None;

    UPROPERTY()
    EMars_PickleMimic_ActionPhase Phase = EMars_PickleMimic_ActionPhase::None;

    UPROPERTY()
    int32 Frame = -1;
}

// One foot over a feet record: its highest lift over the floor, and whether it was seen swinging and then planted.
struct FMars_NetPickleMimicTest_FootRecord
{
    UPROPERTY()
    float64 HighestLift = -1000.0;

    UPROPERTY()
    bool Lifted = false;

    UPROPERTY()
    bool PlantedAgain = false;
}

UCLASS(Abstract)
class UMars_AutoTestRig_NetPickleMimic : UMars_AutoTestRig_NetStrike
{
    default _TimeoutSeconds = 25.0f;

    // The server waits this long once its mimic reads settled before a row's next step.
    protected const float32 k_StandSeconds = 2.0f;
    protected const FVector k_FloorHalfExtents = FVector(1500.0, 1500.0, 10.0);
    protected const float64 k_BodyDropTucked = 19.0;
    protected const float64 k_BodyDropStanding = 0.0;

    protected FCk_Handle_PickleMimic _Mimic;
    protected FCk_Handle_Monster _MimicMonster;
    protected FCk_Handle_Transform _PreyRoot;

    protected int32 _MimicStandingStances = 0;
    protected int32 _MimicTuckedStances = 0;
    protected int32 _MimicStandingFrame = -1;
    protected int32 _MimicDied = 0;
    protected int32 _MimicDamaged = 0;
    protected int32 _MimicSpills = 0;
    protected int32 _MimicLastSpillCount = -1;
    protected int32 _MimicLedgerStandingFrame = -1;
    protected float64 _MimicLargestStep = 0.0;
    protected float32 _MimicHighestRise = 0.0f;
    protected FVector _MimicFoundAt = FVector::ZeroVector;
    protected FCk_Handle_Health _PreyHealth;
    protected TArray<FMars_NetPickleMimicTest_Phase> _MimicPhases;
    protected int32 _MimicBlows = 0;
    protected float32 _MimicWidestInWindup = -1.0f;
    protected float32 _MimicLowestInRecover = 2.0f;
    protected float32 _MimicWidestSinceFlinch = -1.0f;
    protected bool _MimicEverFlinched = false;
    protected bool _MimicGaitEverFailed = false;
    private int32 _MimicFlinchCountSeen = 0;
    private TOptional<FVector> _MimicLastSample;
    private float64 _MimicSampleUntil = 0.0;

    // The feet record (Begin_FeetRecord to the row's end).
    protected bool _FeetRecording = false;
    protected TArray<FMars_NetPickleMimicTest_FootRecord> _FeetRecords;
    protected float64 _FeetWorstPlanted = 0.0;
    protected float64 _FeetFarthestPlantedFromRest = 0.0;
    protected float64 _FeetFarthestFromRest = 0.0;
    protected int32 _FeetDiagonalFrames = 0;
    protected int32 _FeetOtherFrames = 0;
    protected int32 _FeetFrames = 0;
    protected int32 _FeetLowestTrusted = -1;

    // A row without the striker: the base, the target point and the ensure count, and this machine's floor.
    protected void Begin_MimicRow(FVector InBase)
    {
        _Base = InBase;
        _TargetAt = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Spawn_MimicFloor();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: the floor. Server: the mimic, the prey
    //----------------------------------------------------------------------------------------------------------------------

    // A static Jolt box whose top face is at the base's Z, owned by this machine's subject (it dies with the test).
    protected void Spawn_MimicFloor()
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

    // The default spec, spilling nothing (these rows spawn no item).
    protected FMars_PickleMimic_Spec Make_RowSpec() const
    {
        auto Spec = FMars_PickleMimic_Spec();
        Spec.Vitals.SpilledPickles = 0;
        return Spec;
    }

    // The mimic under the replicated spawn owner, its root Clearance above the base, facing +X.
    protected void Spawn_ServerMimic(FMars_PickleMimic_Spec InSpec)
    {
        auto Params = UMars_PickleMimic_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + FVector(0.0, 0.0, utils_pickle_mimic::Clearance));
        Params.Spec = InSpec;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_PickleMimic_EntityScript, Params);
    }

    // The single-machine rig's prey stand-in at InOffset from the base (its root 90 up), owned by the subject: team One
    // (Hostile to the mimic), Health 100, a flesh body zone with one box hurtbox, TAG_MarsSharedCombatTarget (the tag
    // the mimic scans) last.
    protected void Spawn_ServerPrey(FVector InOffset)
    {
        auto Subject = Get_SubjectEntity();
        auto Entity = utils_entity_lifetime::Request_CreateEntity(Subject);
        _PreyRoot = utils_transform::Add(Entity, FTransform(FRotator::ZeroRotator, Get_PreyLocation(InOffset)), ECk_Replication::DoesNotReplicate);
        utils_team::Add(Entity, ECk_Team_ID::One, ECk_Replication::DoesNotReplicate);
        _PreyHealth = utils_health::Add(Entity, FMars_Health_Spec(100.0f));
        auto Zone = utils_hit_zone::Add(Entity, utils_hit_zone::Make_FleshZoneSpec(GameplayTags::HitZone_Mars_Body, 1.0f));
        utils_hit_zone::AddHurtbox_Box(Zone, _PreyRoot, FMars_HitZone_Hurtbox(FVector(35.0, 35.0, 90.0), FTransform::Identity));
        utils_entity_tag::Add(Entity, n"TAG_MarsSharedCombatTarget");
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
    protected void Hit_MimicZone(float32 InAmount)
    {
        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, GameplayTags::DamageType_Mars_Sever)));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_MimicFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound());
    }

    // This machine's copy near the base has composed; the first time, its signals are counted from here (and the server
    // tracks it).
    protected bool Get_IsMimicFound()
    {
        if (ck::IsValid(_Mimic))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsPickleMimic"))
        {
            if (Get_IsNear(Candidate, _Base) == false)
            { continue; }

            auto Mimic = Candidate.As_PickleMimic(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Mimic))
            { continue; }

            _Mimic = Mimic;
            _MimicMonster = Mimic.Get_Monster();
            _Target = Candidate;
            _Health = _MimicMonster.Get_BodyHealth();
            _Zone = _MimicMonster.Get_BodyZone();
            _MimicFoundAt = Mimic.Get_Location();
            _Mimic.BindTo_OnStance(FMars_Delegate_PickleMimic_OnStance(this, n"OnMimicStance"));
            _MimicMonster.BindTo_OnDied(FMars_Delegate_Monster_OnDied(this, n"OnMimicDied"));
            _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnMimicDamaged"));
            _Mimic.BindTo_OnActionPhase(FMars_Delegate_PickleMimic_OnActionPhase(this, n"OnMimicActionPhase"));
            _Mimic.BindTo_OnBlowLanded(FMars_Delegate_PickleMimic_OnBlowLanded(this, n"OnMimicBlowLanded"));
            _Mimic.BindTo_OnSpill(FMars_Delegate_PickleMimic_OnSpill(this, n"OnMimicSpill"));
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            Sample_Mimic();
            return true;
        }

        return false;
    }

    // Server: found, its walker ready and its surface motion grounded.
    UFUNCTION()
    protected void Is_MimicSettled(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && _Mimic.Get_IsWalkerReady() && _Mimic.Get_IsGrounded());
    }

    UFUNCTION()
    protected void Is_MimicStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && Get_IsMimicGone() == false && _Mimic.Get_IsStanding());
    }

    UFUNCTION()
    protected void Is_MimicDead(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && Get_IsMimicGone() == false && _Mimic.Get_IsDead());
    }

    UFUNCTION()
    protected void Is_MimicGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicGone());
    }

    protected bool Get_IsMimicGone()
    {
        FCk_Handle Entity = _Mimic;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    // The root's distance past the base along X (-1 until found).
    protected float64 Get_MimicPastBase()
    {
        if (Get_IsMimicGone())
        { return -1.0; }

        return _Mimic.Get_Location().X - _Base.X;
    }

    // The root's height over the body node (19 tucked, 0 standing).
    protected float64 Get_MimicBodyDrop()
    {
        return _Mimic.Get_Location().Z - _Mimic.Get_BodyTransform().GetLocation().Z;
    }

    protected bool Get_HasMimicLedger()
    {
        return Get_IsMimicGone() == false && _Mimic.Has_Fragment(FMars_Fragment_PickleMimic_Net);
    }

    // The copy's ledger; a default one when it has none (a row asserts Get_HasMimicLedger first).
    protected FMars_Fragment_PickleMimic_Net Get_MimicLedger()
    {
        if (Get_HasMimicLedger() == false)
        { return FMars_Fragment_PickleMimic_Net(); }

        return _Mimic.Get_Fragment(FMars_Fragment_PickleMimic_Net);
    }

    protected ECk_ProceduralAnimation_Status Get_MimicGaitStatus()
    {
        return utils_procedural_gait::Get_Status(_Mimic.Get_Gait());
    }

    protected int32 Get_MimicTrusted()
    {
        if (Get_IsMimicGone() || ck::Is_NOT_Valid(_Mimic.Get_Gait()))
        { return -1; }

        return utils_procedural_gait::Get_TrustedContactCount(_Mimic.Get_Gait());
    }

    // One sample of this machine's copy: the step since the last sample, the highest Rise, the ledger's first Standing,
    // the lid, the flinch, the gait and, while recording, the feet.
    protected void Sample_Mimic()
    {
        if (Get_IsMimicGone())
        { return; }

        const auto Here = _Mimic.Get_Location();
        if (_MimicLastSample.IsSet())
        { _MimicLargestStep = Math::Max(_MimicLargestStep, (Here - _MimicLastSample.GetValue()).Size()); }

        _MimicLastSample = Here;
        _MimicHighestRise = Math::Max(_MimicHighestRise, _Mimic.Get_Rise());
        if (_MimicLedgerStandingFrame < 0 && Get_HasMimicLedger() && Get_MimicLedger().Stance == EMars_PickleMimic_Stance::Standing)
        { _MimicLedgerStandingFrame = int32(utils_time::Get_FrameCounter()); }

        const auto Lid = _Mimic.Get_LidOpen();
        const auto Phase = _Mimic.Get_Action().Phase;
        if (Phase == EMars_PickleMimic_ActionPhase::Windup)
        { _MimicWidestInWindup = Math::Max(_MimicWidestInWindup, Lid); }

        if (Phase == EMars_PickleMimic_ActionPhase::Recover)
        { _MimicLowestInRecover = Math::Min(_MimicLowestInRecover, Lid); }

        const auto FlinchCount = _Mimic.Get_Hurt().FlinchCount;
        if (FlinchCount != _MimicFlinchCountSeen)
        {
            _MimicFlinchCountSeen = FlinchCount;
            _MimicWidestSinceFlinch = Lid;
        }
        else
        { _MimicWidestSinceFlinch = Math::Max(_MimicWidestSinceFlinch, Lid); }

        _MimicEverFlinched = _MimicEverFlinched || _Mimic.Get_IsFlinching();
        _MimicGaitEverFailed = _MimicGaitEverFailed || Get_MimicGaitStatus() == ECk_ProceduralAnimation_Status::Failed;

        if (_FeetRecording)
        { Sample_Feet(); }
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The feet
    //----------------------------------------------------------------------------------------------------------------------

    protected void Begin_FeetRecord()
    {
        _FeetRecording = true;
        _FeetRecords.Reset();
        for (int32 Index = 0; Index < utils_pickle_mimic::Get_LegCount(); ++Index)
        { _FeetRecords.Add(FMars_NetPickleMimicTest_FootRecord()); }
    }

    private void Sample_Feet()
    {
        const auto Feet = _Mimic.Get_Feet();
        const auto Root = _Mimic.Get_RootTransform();
        auto Swinging = TArray<bool>();
        for (int32 Index = 0; Index < Feet.Num() && Index < _FeetRecords.Num(); ++Index)
        {
            const auto Foot = Feet[Index];
            const auto Lift = Foot.Location.Z - _Base.Z;
            auto& Record = _FeetRecords[Index];
            Record.HighestLift = Math::Max(Record.HighestLift, Lift);

            auto FromRest = Foot.Location - Root.TransformPosition(utils_pickle_mimic::Get_RestFootLocal(Index));
            FromRest.Z = 0.0;
            _FeetFarthestFromRest = Math::Max(_FeetFarthestFromRest, FromRest.Size());
            if (Foot.Planted)
            {
                _FeetWorstPlanted = Math::Max(_FeetWorstPlanted, Math::Abs(Lift));
                _FeetFarthestPlantedFromRest = Math::Max(_FeetFarthestPlantedFromRest, FromRest.Size());
                Record.PlantedAgain = Record.PlantedAgain || Record.Lifted;
            }
            else
            { Record.Lifted = true; }

            Swinging.Add(Foot.Planted == false);
        }

        // Legs: 0 front-right, 1 front-left, 2 back-right, 3 back-left.
        if (Swinging.Num() == 4)
        {
            if ((Swinging[0] && Swinging[3]) || (Swinging[1] && Swinging[2]))
            { ++_FeetDiagonalFrames; }

            if ((Swinging[0] && Swinging[1]) || (Swinging[2] && Swinging[3]) || (Swinging[0] && Swinging[2]) || (Swinging[1] && Swinging[3]))
            { ++_FeetOtherFrames; }
        }

        ++_FeetFrames;
        const auto Trusted = Get_MimicTrusted();
        if (_FeetLowestTrusted < 0 || Trusted < _FeetLowestTrusted)
        { _FeetLowestTrusted = Trusted; }
    }

    // Every foot lifted more than InLift over the floor and was seen planted again.
    protected bool Get_HaveAllFeetTrotted(float64 InLift) const
    {
        if (_FeetRecords.Num() != utils_pickle_mimic::Get_LegCount())
        { return false; }

        for (const auto& Record : _FeetRecords)
        {
            if (Record.HighestLift <= InLift || Record.PlantedAgain == false)
            { return false; }
        }

        return true;
    }

    protected FString Describe_Feet() const
    {
        FString Lifts = "";
        for (const auto& Record : _FeetRecords)
        { Lifts += f"{Record.HighestLift}/{Record.Lifted}/{Record.PlantedAgain},"; }

        return f"feet=[frames {_FeetFrames} lifts {Lifts} worstPlanted {_FeetWorstPlanted} farthestPlantedFromRest {_FeetFarthestPlantedFromRest} farthestFromRest {_FeetFarthestFromRest} diagonal {_FeetDiagonalFrames} other {_FeetOtherFrames} lowestTrusted {_FeetLowestTrusted}]";
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The recorded phases
    //----------------------------------------------------------------------------------------------------------------------

    // Where a phase falls in a bite: Windup, Active, Recover, None.
    private int32 Get_PhaseRank(EMars_PickleMimic_ActionPhase InPhase) const
    {
        if (InPhase == EMars_PickleMimic_ActionPhase::Windup)
        { return 0; }

        if (InPhase == EMars_PickleMimic_ActionPhase::Active)
        { return 1; }

        if (InPhase == EMars_PickleMimic_ActionPhase::Recover)
        { return 2; }

        return 3;
    }

    private int32 Get_FirstPhaseIndex(EMars_PickleMimic_ActionPhase InPhase, int32 InFrom) const
    {
        for (auto Index = InFrom; Index < _MimicPhases.Num(); ++Index)
        {
            if (_MimicPhases[Index].Phase == InPhase)
            { return Index; }
        }

        return -1;
    }

    // A None was recorded after a Windup.
    protected bool Get_HasMimicBiteEnded() const
    {
        const auto WindupAt = Get_FirstPhaseIndex(EMars_PickleMimic_ActionPhase::Windup, 0);
        return WindupAt >= 0 && Get_FirstPhaseIndex(EMars_PickleMimic_ActionPhase::None, WindupAt + 1) >= 0;
    }

    // From the first Windup to the first None after it, each phase later than the one before.
    protected bool Get_AreMimicPhasesInOrder() const
    {
        const auto WindupAt = Get_FirstPhaseIndex(EMars_PickleMimic_ActionPhase::Windup, 0);
        if (WindupAt < 0)
        { return false; }

        const auto EndedAt = Get_FirstPhaseIndex(EMars_PickleMimic_ActionPhase::None, WindupAt + 1);
        if (EndedAt < 0)
        { return false; }

        for (auto Index = WindupAt + 1; Index <= EndedAt; ++Index)
        {
            if (Get_PhaseRank(_MimicPhases[Index].Phase) <= Get_PhaseRank(_MimicPhases[Index - 1].Phase))
            { return false; }
        }

        return true;
    }

    protected FString Describe_MimicPhases() const
    {
        FString Text = "";
        for (const auto& Recorded : _MimicPhases)
        { Text += f"{Recorded.Action :n}/{Recorded.Phase :n}@{Recorded.Frame},"; }

        return Text;
    }

    UFUNCTION()
    protected void Is_MimicBiteEnded(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsMimicFound() && Get_HasMimicBiteEnded());
        Sample_Mimic();
    }

    // A wall-clock settle that keeps sampling the copy every frame, then InContinuation.
    protected void WaitSampling(float32 InSeconds, FName InContinuation)
    {
        _MimicSampleUntil = Get_WorldSeconds() + InSeconds;
        WaitUntil(n"Is_MimicSampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_MimicSampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Mimic();
        auto Result = OutResult;
        Result.Set(Get_WorldSeconds() >= _MimicSampleUntil);
    }

    protected float64 Get_WorldSeconds()
    {
        const auto SubjectWorld = utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
        return float64(SubjectWorld.GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line and the finish
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_MimicRow(FString InRow, FString InExtra)
    {
        const auto IsFound = Get_IsMimicGone() == false;
        const auto Stance = IsFound ? f"{_Mimic.Get_Stance() :n}" : FString("gone");
        const auto Rise = IsFound ? _Mimic.Get_Rise() : -1.0f;
        const auto Lid = IsFound ? _Mimic.Get_LidOpen() : -1.0f;
        const auto Location = IsFound ? _Mimic.Get_Location() : FVector::ZeroVector;
        const auto Drop = IsFound ? Get_MimicBodyDrop() : -1.0;
        const auto Crack = IsFound ? _Mimic.Get_CrackStage() : -1;
        const auto Spilled = IsFound ? _Mimic.Get_Hurt().Spilled : false;
        const auto Gait = IsFound ? f"{Get_MimicGaitStatus() :n}" : FString("gone");
        const auto Trusted = Get_MimicTrusted();
        FString LedgerText = "none";
        if (IsFound && Get_HasMimicLedger())
        {
            const auto Ledger = Get_MimicLedger();
            LedgerText = f"{Ledger.Stance :n} {Ledger.Gape} action {Ledger.Action.Kind :n}/{Ledger.Action.Phase :n}/{Ledger.Action.Generation} flinch {Ledger.Flinch.Count}/{Ledger.Flinch.FoundIn :n}/{Ledger.Flinch.From.ToString()}";
        }

        FString ActionText = "none";
        if (IsFound)
        {
            const auto Action = _Mimic.Get_Action();
            const auto Hurt = _Mimic.Get_Hurt();
            ActionText = f"{Action.Kind :n}/{Action.Phase :n}/{Action.Generation} elapsed {Action.PhaseElapsed} flinches {Hurt.FlinchCount}/{Hurt.FlinchFoundIn :n} flinchLeft {Hurt.FlinchLeft}";
        }

        const auto Body = IsFound && ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto Phases = Describe_MimicPhases();
        const auto Feet = Describe_Feet();
        const auto Line = f"[PickleMimicNetTest] {InRow} {Get_MachineName()} stance={Stance} rise={Rise} lid={Lid} root={Location.ToString()} drop={Drop} largestStep={_MimicLargestStep} highestRise={_MimicHighestRise} ledger=[{LedgerText}] ledgerStandingFrame={_MimicLedgerStandingFrame} onStanding={_MimicStandingStances} onTucked={_MimicTuckedStances} standingFrame={_MimicStandingFrame} died={_MimicDied} damaged={_MimicDamaged} body={Body} action=[{ActionText}] phases=[{Phases}] blows={_MimicBlows} widestWindup={_MimicWidestInWindup} lowestRecover={_MimicLowestInRecover} widestSinceFlinch={_MimicWidestSinceFlinch} everFlinched={_MimicEverFlinched} crack={Crack} spills={_MimicSpills}/{_MimicLastSpillCount} spilled={Spilled} gait={Gait} trusted={Trusted} gaitEverFailed={_MimicGaitEverFailed} {Feet} ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    protected void Finish_MimicRow(FString InRow, FString InExtra)
    {
        Log_MimicRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, f"no ensure on the {Get_MachineName()}");
        FinishSuccess();
    }

    // Server: the row's log line and no ensure, then the hold after its last write before it finishes.
    protected void Hold_MimicServerRow(FString InRow, FString InExtra)
    {
        Log_MimicRow(InRow, InExtra);
        Assert_Equals_Int(Get_NewEnsures(), 0, "no ensure on the server");
        WaitSeconds(k_ServerHoldSeconds, n"OnServerHeld");
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnMimicStance(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Stance InStance)
    {
        if (InStance == EMars_PickleMimic_Stance::Standing)
        {
            _MimicStandingStances += 1;
            if (_MimicStandingFrame < 0)
            { _MimicStandingFrame = int32(utils_time::Get_FrameCounter()); }

            return;
        }

        _MimicTuckedStances += 1;
    }

    UFUNCTION()
    private void OnMimicActionPhase(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, EMars_PickleMimic_ActionPhase InPhase)
    {
        auto Recorded = FMars_NetPickleMimicTest_Phase();
        Recorded.Action = InAction;
        Recorded.Phase = InPhase;
        Recorded.Frame = int32(utils_time::Get_FrameCounter());
        _MimicPhases.Add(Recorded);
    }

    UFUNCTION()
    private void OnMimicBlowLanded(FCk_Handle_PickleMimic InMimic, EMars_PickleMimic_Action InAction, FCk_Handle_HitZone InZone)
    {
        _MimicBlows += 1;
    }

    UFUNCTION()
    private void OnMimicSpill(FCk_Handle_PickleMimic InMimic, int32 InCount)
    {
        _MimicSpills += 1;
        _MimicLastSpillCount = InCount;
    }

    UFUNCTION()
    private void OnMimicDied(FCk_Handle_Monster InMonster, FMars_DamageEvent InCause)
    {
        _MimicDied += 1;
    }

    UFUNCTION()
    private void OnMimicDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _MimicDamaged += 1;
    }
}
