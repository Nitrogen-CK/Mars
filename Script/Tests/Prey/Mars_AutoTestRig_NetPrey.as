// The prey net tests' shared steps, on top of the pawn rig (its slab on every machine, the production pawn at the base,
// the client's viewer, handing a pawn to the remote controller and back, the pawn's Health and its signals): the server
// lays a static Jolt box for a Root Maw (its top face at the base's Z, owned by the subject, so the pawn stands on the
// slab and the Maw glides on the box) and spawns the Maw through its real entity script under the replicated spawn
// owner. Each machine finds its copy by tag near the Maw's spot, counts its OnStance(Emerged), records its
// OnActionPhase in order and samples it from the row's polled predicates. A row about the host's own pawn spawns a
// third pawn that the server's local controller possesses; the controller gets its old pawn back at the end.
UCLASS(Abstract)
class UMars_AutoTestRig_NetPrey : UMars_AutoTestRig_NetPlayerCombat
{
    default _TimeoutSeconds = 25.0f;

    // The server waits this long once its Maw reads grounded before a row's next step.
    protected const float32 k_MawStandSeconds = 2.0f;
    protected const FVector k_MawFloorHalfExtents = FVector(1500.0, 1500.0, 10.0);
    // A Maw is found within this of its spot, along the ground.
    protected const float64 k_MawNearCm = 300.0;
    // A creature's scan near the base counts what stands within this of it, along the ground.
    protected const float64 k_ScanNearCm = 1000.0;
    // The host pawn stands this far from the base on +Y.
    protected const FVector k_HostPawnOffset = FVector(0.0, 400.0, 0.0);

    protected FVector _MawSpot = FVector::ZeroVector;
    protected FCk_Handle_RootMaw _Maw;
    protected FVector _MawFoundAt = FVector::ZeroVector;
    protected EMars_RootMaw_Stance _MawStanceWhenFound = EMars_RootMaw_Stance::Buried;
    protected int32 _MawEmergedStances = 0;
    protected int32 _MawEmergedFrame = -1;
    protected TArray<FMars_NetRootMawTest_Phase> _MawPhases;
    // Frames a sampler saw first (one counter for both PIE worlds); -1 before.
    protected int32 _LocallyControlledFrame = -1;
    protected int32 _TargetIsPawnFrame = -1;
    protected int32 _FirstDamagedFrame = -1;
    protected AMars_PlayerCharacter _HostPawn;

    private float64 _PreySampleUntil = 0.0;
    private bool _IsServerHostPawn = false;
    private APlayerController _LocalController;
    private APawn _LocalPreviousPawn;

    // Both machines: the base, the Maw's spot (the base plus InMawOffset) and the pawn rig's slab.
    protected void Begin_PreyRow(FVector InBase, FVector InMawOffset)
    {
        Begin_Rig(InBase);
        _MawSpot = InBase + InMawOffset;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Server: the Maw's floor, the Maw, the host pawn
    //----------------------------------------------------------------------------------------------------------------------

    // A static Jolt box whose top face is at the base's Z, owned by the subject (it dies with the test).
    protected void Spawn_ServerMawFloor()
    {
        auto Subject = Get_SubjectEntity();
        auto Box = utils_entity_lifetime::Request_CreateEntity(Subject);
        utils_transform::Add(Box, FTransform(FRotator::ZeroRotator, _Base - FVector(0.0, 0.0, k_MawFloorHalfExtents.Z)),
            ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(k_MawFloorHalfExtents);
        auto BoxSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        BoxSpec.Set_ShapeDimensions(Shape);
        BoxSpec.Set_MotionType(ECk_MotionType::Static);
        BoxSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Box, BoxSpec);
    }

    // The Maw under the replicated spawn owner, its root Clearance above the base plus InOffset, facing +X.
    protected void Spawn_ServerMaw(FVector InOffset, FMars_RootMaw_Spec InSpec)
    {
        auto Params = UMars_RootMaw_EntityScript::Params();
        Params.SpawnTransform = FTransform(FRotator::ZeroRotator, _Base + InOffset + FVector(0.0, 0.0, utils_root_maw::Clearance));
        Params.Spec = InSpec;
        Params.WithVisuals = false;
        utils_entity_script::Request_SpawnEntity(utils_mars_net::Get_ReplicatedSpawnOwner(Get_SubjectEntity()),
            UMars_RootMaw_EntityScript, Params);
    }

    // Server: a third pawn at its spot, possessed by the server's local player controller (its old pawn is remembered).
    protected void Spawn_ServerHostPawn()
    {
        _HostPawn = DoSpawn_PawnAt(_Base + k_HostPawnOffset);
        _IsServerHostPawn = ck::IsValid(_HostPawn);
        if (_IsServerHostPawn == false)
        {
            FinishFailure("the host pawn (AMars_PlayerCharacter) did not spawn on the server");
            return;
        }

        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Controllers = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(APlayerController, Controllers);
        auto Count = 0;
        for (auto Actor : Controllers)
        {
            auto Controller = Cast<APlayerController>(Actor);
            if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController() == false)
            { continue; }

            _LocalController = Controller;
            Count += 1;
        }

        if (Count != 1)
        {
            _LocalController = nullptr;
            FinishFailure("the server's world has not exactly one local player controller");
            return;
        }

        _LocalPreviousPawn = _LocalController.GetControlledPawn();
        _LocalController.Possess(_HostPawn);
    }

    // This machine's copy of the host pawn, nearest its spot; null until it is there.
    protected AMars_PlayerCharacter Get_HostPawn()
    {
        if (ck::Is_NOT_Valid(_HostPawn))
        { _HostPawn = DoFind_PawnNear(_Base + k_HostPawnOffset); }

        return _HostPawn;
    }

    // Server: the host pawn's copy is composed with a Health and its local controller possesses it.
    protected bool Get_IsServerHostPawnReady()
    {
        const auto HostPawn = Get_HostPawn();
        if (ck::Is_NOT_Valid(HostPawn) || ck::Is_NOT_Valid(_LocalController) || HostPawn.GetController() != _LocalController)
        { return false; }

        const auto Entity = HostPawn.Get_GameplayComposedEntity();
        return ck::IsValid(Entity) && ck::IsValid(Entity.As_Health(ECk_SanityCheck::UnChecked));
    }

    UFUNCTION()
    protected void Is_ServerReadyForMaw(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(utils_mars_net::Get_HasReplicatedSpawnOwner(Get_SubjectEntity()) && Get_IsPawnComposed());
    }

    // Server: the local controller gets its old pawn back and the host pawn goes, then the pawn rig's tear down.
    protected void TearDown() override
    {
        if (ck::IsValid(_LocalController))
        {
            if (ck::IsValid(_HostPawn) && _LocalController.GetControlledPawn() == _HostPawn)
            { _LocalController.UnPossess(); }

            if (ck::IsValid(_LocalPreviousPawn) && _LocalController.GetControlledPawn() != _LocalPreviousPawn)
            { _LocalController.Possess(_LocalPreviousPawn); }
        }

        _LocalController = nullptr;
        if (_IsServerHostPawn && ck::IsValid(_HostPawn))
        { _HostPawn.DestroyActor(); }

        _IsServerHostPawn = false;
        Super::TearDown();
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Tags and scans
    //----------------------------------------------------------------------------------------------------------------------

    protected bool Get_HasSharedTag(FCk_Handle InEntity)
    {
        return ck::IsValid(InEntity) && utils_entity_tag::Has(InEntity, n"TAG_MarsSharedCombatTarget");
    }

    protected bool Get_HasLocalTag(FCk_Handle InEntity)
    {
        return ck::IsValid(InEntity) && utils_entity_tag::Has(InEntity, n"TAG_MarsCombatTarget");
    }

    // The entities a scan of InTag in this machine's world yields within k_ScanNearCm of the base, along the ground.
    protected TArray<FCk_Handle> Find_TaggedNearBase(FName InTag)
    {
        auto Found = TArray<FCk_Handle>();
        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), InTag))
        {
            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            auto Offset = utils_transform::Get_EntityCurrentLocation(Transform) - _Base;
            Offset.Z = 0.0;
            if (Offset.Size() <= k_ScanNearCm)
            { Found.Add(Candidate); }
        }

        return Found;
    }

    protected FCk_Handle Get_PawnEntity(AMars_PlayerCharacter InPawn)
    {
        return ck::IsValid(InPawn) ? InPawn.Get_GameplayComposedEntity() : FCk_Handle();
    }

    protected bool Get_IsPlayerControlled(FCk_Handle InEntity)
    {
        return ck::IsValid(InEntity) &&
            utils_net::Get_IsEntityPlayerControlled(InEntity) == ECk_Utils_Net_IsPlayerControlled_Result::IsPlayerControlled;
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Each machine: its copy of the Maw
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    protected void Is_MawFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound());
    }

    // This machine's copy near the Maw's spot has composed; the first time, its signals are recorded from here, its
    // root and stance are remembered, and the server tracks it.
    protected bool Get_IsMawFound()
    {
        if (ck::IsValid(_Maw))
        { return true; }

        for (auto Candidate : utils_entity_tag::ForEach_Entity(Get_SubjectEntity(), n"TAG_MarsRootMaw"))
        {
            const auto Transform = Candidate.As_Transform(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Transform))
            { continue; }

            auto Offset = utils_transform::Get_EntityCurrentLocation(Transform) - _MawSpot;
            Offset.Z = 0.0;
            if (Offset.Size() >= k_MawNearCm)
            { continue; }

            auto Maw = Candidate.As_RootMaw(ECk_SanityCheck::UnChecked);
            if (ck::Is_NOT_Valid(Maw))
            { continue; }

            _Maw = Maw;
            _MawFoundAt = Maw.Get_Location();
            _MawStanceWhenFound = Maw.Get_Stance();
            _Maw.BindTo_OnStance(FMars_Delegate_RootMaw_OnStance(this, n"OnPreyMawStance"));
            _Maw.BindTo_OnActionPhase(FMars_Delegate_RootMaw_OnActionPhase(this, n"OnPreyMawActionPhase"));
            if (Get_IsServer())
            { Track_ForCleanup(Candidate); }

            return true;
        }

        return false;
    }

    protected bool Get_IsMawGone()
    {
        FCk_Handle Entity = _Maw;
        return ck::Is_NOT_Valid(Entity) || utils_entity_lifetime::Get_IsPendingDestroy(Entity, ECk_EntityLifetime_DestructionPhase::BeginDestroy);
    }

    UFUNCTION()
    protected void Is_MawStanding(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && Get_IsMawGone() == false && _Maw.Get_IsGrounded());
    }

    UFUNCTION()
    protected void Is_MawEmerged(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        auto Result = OutResult;
        Result.Set(Get_IsMawFound() && Get_IsMawGone() == false && _Maw.Get_IsEmerged());
    }

    // Server: its Maw's target is the pawn's entity.
    protected bool Get_IsTargetThePawn()
    {
        if (Get_IsServer() == false || Get_IsMawGone() || ck::Is_NOT_Valid(_Player))
        { return false; }

        return _Maw.Get_Target() == _Player;
    }

    // The distance along the ground from this machine's Maw root to this machine's copy of the pawn; -1 without both.
    protected float64 Get_MawToPawn()
    {
        if (Get_IsMawGone() || ck::Is_NOT_Valid(_Pawn))
        { return -1.0; }

        auto Offset = _Pawn.GetActorLocation() - _Maw.Get_Location();
        Offset.Z = 0.0;
        return Offset.Size();
    }

    // A None was recorded after a Windup.
    protected bool Get_HasMawBiteEnded() const
    {
        const auto WindupAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::Windup, 0);
        return WindupAt >= 0 && Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::None, WindupAt + 1) >= 0;
    }

    // An Active was recorded between the first Windup and the first None after it.
    protected bool Get_HasMawActiveBeforeEnd() const
    {
        const auto WindupAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::Windup, 0);
        if (WindupAt < 0)
        { return false; }

        const auto ActiveAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::Active, WindupAt + 1);
        const auto EndedAt = Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase::None, WindupAt + 1);
        return ActiveAt >= 0 && EndedAt > ActiveAt;
    }

    protected int32 Get_FirstPhaseIndex(EMars_RootMaw_ActionPhase InPhase, int32 InFrom) const
    {
        for (auto Index = InFrom; Index < _MawPhases.Num(); ++Index)
        {
            if (_MawPhases[Index].Phase == InPhase)
            { return Index; }
        }

        return -1;
    }

    protected FString Describe_MawPhases() const
    {
        FString Text = "";
        for (const auto& Recorded : _MawPhases)
        { Text += f"{Recorded.Action :n}/{Recorded.Phase :n}@{Recorded.Frame},"; }

        return Text;
    }

    // One sample: the first frame this machine's pawn read locally controlled, its Maw targeted the pawn (server) and
    // its pawn's Health raised OnDamaged.
    protected void Sample_Prey()
    {
        const auto Frame = int32(utils_time::Get_FrameCounter());
        if (_LocallyControlledFrame < 0 && ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled())
        { _LocallyControlledFrame = Frame; }

        if (_TargetIsPawnFrame < 0 && Get_IsTargetThePawn())
        { _TargetIsPawnFrame = Frame; }

        if (_FirstDamagedFrame < 0 && _Damaged.Num() > 0)
        { _FirstDamagedFrame = Frame; }
    }

    // A wall-clock settle that keeps sampling every frame, then InContinuation.
    protected void WaitSampling(float32 InSeconds, FName InContinuation)
    {
        _PreySampleUntil = Get_WorldSeconds() + InSeconds;
        WaitUntil(n"Is_PreySampledLongEnough", InContinuation, k_SlowPolls);
    }

    UFUNCTION()
    protected void Is_PreySampledLongEnough(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        Sample_Prey();
        auto Result = OutResult;
        Result.Set(Get_WorldSeconds() >= _PreySampleUntil);
    }

    protected float64 Get_WorldSeconds()
    {
        return float64(Get_TestWorld().GetTimeSeconds());
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The log line
    //----------------------------------------------------------------------------------------------------------------------

    protected void Log_PreyRow(FString InRow, FString InExtra)
    {
        const auto Current = ck::IsValid(_Health) ? _Health.Get_Current() : -1.0f;
        const auto HasAuthority = ck::IsValid(_Player) && utils_net::Get_HasAuthority(_Player);
        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        const auto IsFound = Get_IsMawGone() == false;
        const auto Stance = IsFound ? f"{_Maw.Get_Stance() :n}" : FString("none");
        const auto Emerge = IsFound ? _Maw.Get_Emerge() : -1.0f;
        const auto Root = IsFound ? _Maw.Get_Location() : FVector::ZeroVector;
        const auto Phases = Describe_MawPhases();
        const auto Line = f"[PreyNetTest] {InRow} {Get_MachineName()} health={Current} shared={Get_HasSharedTag(_Player)} local={Get_HasLocalTag(_Player)} authority={HasAuthority} locallyControlled={IsLocal} playerControlled={Get_IsPlayerControlled(_Player)} damaged={_Damaged.Num()} maw=[stance {Stance} emerge {Emerge} root {Root.ToString()} targetIsPawn {Get_IsTargetThePawn()} toPawn {Get_MawToPawn()} emergedStances {_MawEmergedStances} stanceWhenFound {_MawStanceWhenFound :n}] phases=[{Phases}] frames=[local {_LocallyControlledFrame} target {_TargetIsPawnFrame} emerged {_MawEmergedFrame} damaged {_FirstDamagedFrame}] ensures={Get_NewEnsures()} frame={utils_time::Get_FrameCounter()} {InExtra}";
        Log(Line);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Signals
    //----------------------------------------------------------------------------------------------------------------------

    UFUNCTION()
    private void OnPreyMawStance(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Stance InStance)
    {
        if (InStance != EMars_RootMaw_Stance::Emerged)
        { return; }

        _MawEmergedStances += 1;
        if (_MawEmergedFrame < 0)
        { _MawEmergedFrame = int32(utils_time::Get_FrameCounter()); }
    }

    UFUNCTION()
    private void OnPreyMawActionPhase(FCk_Handle_RootMaw InMaw, EMars_RootMaw_Action InAction, EMars_RootMaw_ActionPhase InPhase)
    {
        auto Recorded = FMars_NetRootMawTest_Phase();
        Recorded.Action = InAction;
        Recorded.Phase = InPhase;
        Recorded.Frame = int32(utils_time::Get_FrameCounter());
        _MawPhases.Add(Recorded);
    }
}
