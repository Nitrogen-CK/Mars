// The player-combat rig: the production AMars_PlayerCharacter, spawned on a floor of its own and possessed by the test
// world's first player controller. Its entity (resolved through the actor's entity bridge), its state machine (which
// only starts under local player control), its movement component and its capsule are therefore the real ones, which a
// carrier entity cannot stand in for. The controller's previous pawn is possessed again at teardown. Each test sets
// _Origin to its own isolated spot; the floor's top face is at _Origin.Z.
UCLASS(Abstract)
class UMars_AutoTestRig_PlayerCombat : UCk_AutoTest_Base
{
    default _TimeoutSeconds = 30.0f;

    // Spawn, possession, the state machine's start and deferred probe joins outrun the default poll budget at lane
    // frame rate.
    protected const int32 k_SlowPolls = 1800;
    // Frames a held state is watched for after it is reached.
    protected const int32 k_HoldFrames = 30;

    protected FVector _Origin;
    protected FCk_Handle _Self;
    protected AMars_PlayerCharacter _Pawn;
    protected APlayerController _Controller;
    protected FCk_Handle _Player;
    protected FCk_Handle_StateMachine _Sm;

    // Root state entries since the last ResetStateCounts.
    protected int32 _DownedEntries = 0;
    protected int32 _AliveEntries = 0;

    private APawn _PreviousPawn;
    private TArray<AActor> _SpawnedActors;
    private bool _StateChangesBound = false;
    private int32 _HeldFrames = 0;
    private int32 _HoldViolations = 0;
    private FString _FirstHoldViolation;

    //----------------------------------------------------------------------------------------------------------------------
    // Spawn and teardown
    //----------------------------------------------------------------------------------------------------------------------

    // The floor, then the pawn standing on it at _Origin facing +X, possessed.
    protected void SpawnFloorAndPlayer(FCk_Handle InHandle)
    {
        SpawnFloorAndUnpossessedPawn(InHandle);
        PossessPawn();
    }

    // The floor and the pawn, which no controller possesses yet.
    protected void SpawnFloorAndUnpossessedPawn(FCk_Handle InHandle)
    {
        SpawnFloorAndUnpossessedPawnAt(InHandle, _Origin);
    }

    // The floor (top face at _Origin.Z) and the pawn with its feet at InFeet, facing +X; no controller possesses it yet.
    protected void SpawnFloorAndUnpossessedPawnAt(FCk_Handle InHandle, FVector InFeet)
    {
        _Self = InHandle;
        SpawnBlock(_Origin - FVector(0.0, 0.0, 50.0), FVector(20.0, 20.0, 1.0));

        _Controller = Gameplay::GetPlayerController(0);
        if (ck::Is_NOT_Valid(_Controller))
        {
            FinishFailure("the test world has no player controller to possess the pawn with");
            return;
        }

        _PreviousPawn = _Controller.GetControlledPawn();
        const auto HalfHeight = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight);
        _Pawn = Cast<AMars_PlayerCharacter>(SpawnActor(AMars_PlayerCharacter, InFeet + FVector(0.0, 0.0, HalfHeight + 2.0), FRotator::ZeroRotator));
        if (ck::Is_NOT_Valid(_Pawn))
        {
            FinishFailure("AMars_PlayerCharacter did not spawn");
            return;
        }
    }

    protected void PossessPawn()
    {
        if (ck::IsValid(_Controller) && ck::IsValid(_Pawn))
        { _Controller.Possess(_Pawn); }
    }

    // An engine cube (100 uu) centred at InCenter and scaled by InScale, with collision; destroyed at teardown.
    protected AStaticMeshActor SpawnBlock(FVector InCenter, FVector InScale)
    {
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        auto Block = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, InCenter));
        if (ck::Is_NOT_Valid(Block) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("a block (the engine cube) did not spawn");
            return nullptr;
        }

        Block.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        Block.StaticMeshComponent.SetStaticMesh(Cube);
        Block.SetActorScale3D(InScale);
        _SpawnedActors.Add(Block);
        return Block;
    }

    // A static Jolt box centred at InCenter, BlockAll: what a probe trace's Blocking world policy stops at.
    protected FCk_Handle SpawnJoltWall(FVector InCenter, FVector InHalfExtents)
    {
        auto Wall = utils_entity_lifetime::Request_CreateEntity(_Self);
        utils_transform::Add(Wall, FTransform(FRotator::ZeroRotator, InCenter), ECk_Replication::DoesNotReplicate);
        auto Shape = FCk_Jolt_ShapeDimensions(ECk_Jolt_ShapeType::Box);
        Shape.Set_HalfExtents(InHalfExtents);
        auto WallSpec = FCk_JoltBody_Spec(ECk_JoltBody_ShapeSource::ExplicitShape);
        WallSpec.Set_ShapeDimensions(Shape);
        WallSpec.Set_MotionType(ECk_MotionType::Static);
        WallSpec.Set_CollisionProfileName(n"BlockAll");
        utils_jolt_body::Add(Wall, WallSpec);
        return Wall;
    }

    // Gives the controller back its previous pawn and destroys everything this rig spawned. Safe to call twice.
    protected void TearDown()
    {
        if (ck::IsValid(_Controller))
        {
            if (ck::IsValid(_Pawn) && _Controller.GetControlledPawn() == _Pawn)
            { _Controller.UnPossess(); }

            if (ck::IsValid(_PreviousPawn) && _Controller.GetControlledPawn() != _PreviousPawn)
            { _Controller.Possess(_PreviousPawn); }
        }

        if (ck::IsValid(_Pawn))
        { _Pawn.DestroyActor(); }

        for (auto Actor : _SpawnedActors)
        {
            if (ck::IsValid(Actor))
            { Actor.DestroyActor(); }
        }

        _SpawnedActors.Empty();
        _Pawn = nullptr;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        TearDown();
    }

    UFUNCTION()
    protected void Step_TearDown(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        TearDown();
    }

    UFUNCTION()
    protected void Check_PlayerEntityGone(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(ck::Is_NOT_Valid(_Player));
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Readiness
    //----------------------------------------------------------------------------------------------------------------------

    // The pawn's entity is linked and composed (its state machine exists; the machine only starts under local control).
    UFUNCTION()
    protected void Check_EntityComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(false);
        if (ck::Is_NOT_Valid(_Pawn))
        { return; }

        if (ck::Is_NOT_Valid(_Player))
        { _Player = utils_owning_actor::TryGet_ActorEntityHandle(_Pawn); }

        Res.Set(ck::IsValid(_Player) && ck::IsValid(_Player.As_StateMachine(ECk_SanityCheck::UnChecked)));
    }

    // The entity is linked, its state machine has entered Alive and the character stands on the floor.
    UFUNCTION()
    protected void Check_PlayerReady(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        Res.Set(false);
        if (ck::Is_NOT_Valid(_Pawn))
        { return; }

        if (ck::Is_NOT_Valid(_Player))
        {
            _Player = utils_owning_actor::TryGet_ActorEntityHandle(_Pawn);
            if (ck::Is_NOT_Valid(_Player))
            { return; }
        }

        _Sm = _Player.As_StateMachine(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Sm))
        { return; }

        if (_StateChangesBound == false)
        {
            utils_state_machine::BindTo_OnStateChanged(_Sm, FCk_Delegate_Sm_OnStateChanged(this, n"OnStateChanged"));
            _StateChangesBound = true;
        }

        Res.Set(utils_state_machine::IsInState(_Sm, UMars_SmState_Alive) && _Pawn.CharacterMovement.IsMovingOnGround());
    }

    // The receiver is composed only on the local host's own pawn (utils_local_session): the lane's world is a listen
    // server (the project's PIE net mode), which counts as local, and the pawn is possessed by its local controller.
    UFUNCTION()
    protected void Step_AssertLocalReceiver(FCk_Handle InHandle, FInstancedStruct InPayload)
    {
        auto PawnWorld = _Pawn.GetWorld();
        const auto NetMode = PawnWorld.GetNetMode();
        ck::Trace(f"[PlayerCombat] receiver world net mode={NetMode :n} locallyControlled={_Pawn.IsLocallyControlled()}");
        Assert_True(utils_local_session::Get_IsLocalCombatWorld(PawnWorld), f"the test world is a local combat world (net mode {NetMode :n})");
        Assert_True(_Pawn.IsLocallyControlled(), "the pawn is locally controlled");
        Assert_Valid(Get_Health(), "the local player composed a Health");
        Assert_Valid(Get_Zone(), "the local player composed a HitZone");
        Assert_Valid(Get_Hurtbox(), "the local player registered one hurtbox");
        Assert_True(utils_entity_tag::Has(_Player, n"TAG_MarsCombatTarget"), "the local player carries TAG_MarsCombatTarget");
        if (ck::Is_NOT_Valid(Get_Health()) || ck::Is_NOT_Valid(Get_Zone()) || ck::Is_NOT_Valid(Get_Hurtbox()))
        { FinishFailure(f"the player has no combat receiver (net mode {NetMode :n}); nothing further can be checked"); }
    }

    // The player's hurtbox probe has joined the physics world: a sweep across the capsule's centre reports it.
    UFUNCTION()
    protected void Check_HurtboxTraceable(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        const auto Hurtbox = Get_Hurtbox();
        Res.Set(ck::IsValid(Hurtbox) && SweepAcrossPawn(PawnLocation().Z, GameplayTags::Probe_Mars_HitZone).Get_HitEntity() == Hurtbox);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // The receiver
    //----------------------------------------------------------------------------------------------------------------------

    protected FCk_Handle_Health Get_Health() const
    {
        return _Player.As_Health(ECk_SanityCheck::UnChecked);
    }

    protected FCk_Handle_HitZone Get_Zone() const
    {
        return _Player.As_HitZone(ECk_SanityCheck::UnChecked);
    }

    protected FCk_Handle_Climber Get_Climber() const
    {
        return _Player.As_Climber(ECk_SanityCheck::UnChecked);
    }

    // The zone's one registered hurtbox; invalid without exactly one.
    protected FCk_Handle Get_Hurtbox() const
    {
        const auto Zone = Get_Zone();
        if (ck::Is_NOT_Valid(Zone))
        { return FCk_Handle(); }

        const auto Hurtboxes = Zone.Get_Hurtboxes();
        return Hurtboxes.Num() == 1 ? Hurtboxes[0] : FCk_Handle();
    }

    protected void SetDownedFlag(bool InDowned)
    {
        utils_byte_attribute::Override(_Player, GameplayTags::ByteAttribute_Mars_Player_Downed, uint8(InDowned ? 1 : 0));
    }

    protected bool Get_IsDownedFlagSet() const
    {
        return utils_byte_attribute::Get_FinalValue(_Player, GameplayTags::ByteAttribute_Mars_Player_Downed) > 0;
    }

    protected bool Get_IsInDowned() const
    {
        return ck::IsValid(_Sm) && utils_state_machine::IsInState(_Sm, UMars_SmState_Downed);
    }

    protected bool Get_IsInAlive() const
    {
        return ck::IsValid(_Sm) && utils_state_machine::IsInState(_Sm, UMars_SmState_Alive);
    }

    protected EMovementMode Get_MovementMode() const
    {
        return _Pawn.CharacterMovement.MovementMode;
    }

    protected bool Get_IsMoveInputIgnored() const
    {
        return ck::IsValid(_Controller) && _Controller.IsMoveInputIgnored();
    }

    protected FVector PawnLocation() const
    {
        return _Pawn.GetActorLocation();
    }

    // The bottom of the capsule (the floor top while standing on it).
    protected float64 FeetZ() const
    {
        return PawnLocation().Z - _Pawn.CapsuleComponent.GetScaledCapsuleHalfHeight();
    }

    // A small horizontal sphere sweep across the pawn at height InZ, filtered on InProbeName, world bodies ignored and no
    // overlap notify, traced as the test entity so nothing of the player's is skipped.
    protected FCk_ShapeCast_Result SweepAcrossPawn(float64 InZ, FGameplayTag InProbeName)
    {
        const auto Location = PawnLocation();
        auto Settings = FCk_ShapeCast_Settings(
            FVector(Location.X - 200.0, Location.Y, InZ),
            FVector(Location.X + 200.0, Location.Y, InZ),
            utils_shapes::Make_Sphere(FCk_ShapeSphere_Dimensions(5.0f)),
            GameplayTag::MakeContainerFromTag(InProbeName));
        Settings.Set_OverlapNotifyPolicy(ECk_ProbeResponse_Policy::Silent);
        return utils_probe_trace::Request_SingleShapeTrace(_Self, Settings);
    }

    //----------------------------------------------------------------------------------------------------------------------
    // State tracking
    //----------------------------------------------------------------------------------------------------------------------

    protected void ResetStateCounts()
    {
        _DownedEntries = 0;
        _AliveEntries = 0;
    }

    UFUNCTION()
    protected void OnStateChanged(FCk_Handle_StateMachine InStateMachine, FCk_Sm_Payload_OnStateChanged InPayload)
    {
        const auto NewState = InPayload.Get_NewStateClass();
        if (NewState == UMars_SmState_Downed)
        {
            ++_DownedEntries;
            OnDownedEntered();
        }
        else if (NewState == UMars_SmState_Alive)
        { ++_AliveEntries; }
    }

    // Called inside OnStateChanged, the frame Downed is entered.
    protected void OnDownedEntered()
    {
    }

    //----------------------------------------------------------------------------------------------------------------------
    // Holding Downed
    //----------------------------------------------------------------------------------------------------------------------

    protected void BeginHold()
    {
        _HeldFrames = 0;
        _HoldViolations = 0;
        _FirstHoldViolation = "";
    }

    // Each frame for k_HoldFrames frames: the player stays Downed, not climbing, movement disabled.
    UFUNCTION()
    protected void Check_HeldDowned(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Res = OutResult;
        ++_HeldFrames;

        const auto Climber = Get_Climber();
        const auto Climbing = ck::IsValid(Climber) && Climber.Get_IsClimbing();
        const auto Mode = Get_MovementMode();
        if (Get_IsInDowned() == false || Climbing || Mode != EMovementMode::MOVE_None)
        {
            if (_HoldViolations == 0)
            { _FirstHoldViolation = f"frame {_HeldFrames}: downed={Get_IsInDowned()} climbing={Climbing} mode={Mode :n}"; }

            ++_HoldViolations;
        }

        Res.Set(_HeldFrames >= k_HoldFrames);
    }

    protected void AssertHeld(const FString& InWhat)
    {
        Assert_Equals_Int(_HoldViolations, 0, f"{InWhat}: the player stayed Downed, off the ladder, movement None for {k_HoldFrames} frames (first violation: {_FirstHoldViolation})");
    }
}

// The pawn-spawning tests share this runner base: each test's wrapper derives from it, so the populator places a runner
// per test and the production pawn's known spawn-time log noise is listed once.
UCLASS(Abstract)
class AMars_AutoTestRunner_PlayerCombat : ACk_AutoTestRunner
{
    default _TimeoutSeconds = 30.0f;

    UFUNCTION(BlueprintOverride)
    TArray<FString> Get_ExpectedLogErrors() const
    {
        TArray<FString> Out;
        // The production pawn attaches its hat and held-item meshes to body sockets before its body mesh is assigned.
        Out.Add("No SkeletalMesh for Component(CharacterMesh0)");
        // A headless editor without a compiled eye-plate look; the face then has logic and nothing to draw on.
        Out.Add("Look [MarsEyePlate] master material has shader compile errors");
        return Out;
    }
}
