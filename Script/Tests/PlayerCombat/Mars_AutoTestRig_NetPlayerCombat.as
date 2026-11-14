// The player-combat net tests' shared steps: the server spawns the production AMars_PlayerCharacter at the row's base;
// each machine stands it on a floor block of its own (a plain static mesh actor does not replicate, and a pawn the client
// controls moves on the client's world), finds its copy of the pawn nearest the base, takes its entity, its Health, its
// zone and its state machine, and records what its own copy raises. The server can hand a pawn to the one player
// controller in its world that is not local, and gives that controller its old pawn back at the end. A row about a pawn
// nobody controls also spawns the viewer, a second pawn beside it that the client possesses: the pawn class's net cull
// distance (filtered from the class, not the instance) keeps a pawn kilometres from the client's view off the client,
// and a client meets an uncontrolled pawn in a real session by standing near it. The server destroys what it spawned.
UCLASS(Abstract)
class UMars_AutoTestRig_NetPlayerCombat : UCk_AutoTest_NetBase
{
    default _TimeoutSeconds = 25.0f;

    protected const int32 k_SlowPolls = 5000;
    // A client asserts once the last server step has had this long to arrive.
    protected const float32 k_SettleSeconds = 1.0f;
    // The server waits this long after it finds its pawn's receiver, so the client's copy has composed.
    protected const float32 k_ComposeSeconds = 2.0f;
    // The server holds this long after its last write before it destroys the pawn and finishes.
    protected const float32 k_ServerHoldSeconds = 2.0f;
    // A pawn is found within this of its spot (the base, or the viewer's spot).
    protected const float64 k_NearCm = 150.0;
    // The viewer stands this far from the base on -Y.
    protected const FVector k_ViewerOffset = FVector(0.0, -400.0, 0.0);

    protected FVector _Base = FVector::ZeroVector;
    protected AMars_PlayerCharacter _Pawn;
    protected FCk_Handle _Player;
    protected FCk_Handle_Health _Health;
    protected FCk_Handle_HitZone _Zone;
    protected FCk_Handle_StateMachine _Sm;
    protected int32 _EnsuresAtStart = 0;

    // Applied amount of every OnDamaged this machine's copy raised.
    protected TArray<float32> _Damaged;
    protected int32 _Healed = 0;
    protected int32 _Depleted = 0;
    protected int32 _DownedEntries = 0;
    protected int32 _AliveEntries = 0;
    // The frame counter when this machine's copy last entered Downed and Alive; -1 before.
    protected int32 _DownedFrame = -1;
    protected int32 _AliveFrame = -1;

    private AStaticMeshActor _Floor;
    private bool _IsServerPawn = false;
    private APlayerController _RemoteController;
    private APawn _RemotePreviousPawn;
    private bool _StateChangesBound = false;
    protected AMars_PlayerCharacter _Viewer;
    private bool _IsServerViewer = false;

    protected void Begin_Rig(FVector InBase)
    {
        _Base = InBase;
        _EnsuresAtStart = utils_ensure::Get_EnsureCount();
        Spawn_Floor();
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

    protected UWorld Get_TestWorld()
    {
        return utils_entity_lifetime::Get_WorldForEntity(Get_SubjectEntity());
    }

    // An engine cube scaled to a 20 m slab whose top face is the base's Z.
    private void Spawn_Floor()
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Cube = Cast<UStaticMesh>(LoadObject(UStaticMesh, "/Engine/BasicShapes/Cube.Cube"));
        _Floor = Cast<AStaticMeshActor>(SpawnActor(AStaticMeshActor, _Base - FVector(0.0, 0.0, 50.0)));
        if (ck::Is_NOT_Valid(_Floor) || ck::Is_NOT_Valid(Cube))
        {
            FinishFailure("the floor block (the engine cube) did not spawn");
            return;
        }

        _Floor.StaticMeshComponent.SetMobility(EComponentMobility::Movable);
        _Floor.StaticMeshComponent.SetStaticMesh(Cube);
        _Floor.SetActorScale3D(FVector(20.0, 20.0, 1.0));
    }

    // Server: the production pawn standing at the base, facing +X, possessed by nobody.
    protected void Spawn_ServerPawn()
    {
        _Pawn = DoSpawn_PawnAt(_Base);
        _IsServerPawn = ck::IsValid(_Pawn);
        if (_IsServerPawn == false)
        { FinishFailure("AMars_PlayerCharacter did not spawn on the server"); }
    }

    // Server: the viewer at its spot, possessed by the remote controller.
    protected void Spawn_ServerViewer()
    {
        _Viewer = DoSpawn_PawnAt(_Base + k_ViewerOffset);
        _IsServerViewer = ck::IsValid(_Viewer);
        if (_IsServerViewer == false)
        {
            FinishFailure("the viewer (AMars_PlayerCharacter) did not spawn on the server");
            return;
        }

        if (Request_ServerPossessByRemote(_Viewer) == false)
        { FinishFailure("the server's world has not exactly one player controller that is not local"); }
    }

    protected AMars_PlayerCharacter DoSpawn_PawnAt(FVector InFeet)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        const auto HalfHeight = float64(mars::Mars_PlayerCharacter_Config.Body.CapsuleHalfHeight);
        return Cast<AMars_PlayerCharacter>(SpawnActor(AMars_PlayerCharacter, InFeet + FVector(0.0, 0.0, HalfHeight + 2.0), FRotator::ZeroRotator));
    }

    // Server: the test pawn's copy is composed and the viewer reads possessed by the remote controller.
    UFUNCTION()
    protected void Is_ServerReadyWithViewer(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed() && ck::IsValid(_Viewer) && ck::IsValid(_RemoteController) && _Viewer.GetController() == _RemoteController);
    }

    // This machine's copy of the viewer, nearest the viewer's spot; null until it is there.
    protected AMars_PlayerCharacter Get_Viewer()
    {
        if (ck::Is_NOT_Valid(_Viewer))
        { _Viewer = DoFind_PawnNear(_Base + k_ViewerOffset); }

        return _Viewer;
    }

    UFUNCTION()
    protected void Is_PawnComposed(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsPawnComposed());
    }

    UFUNCTION()
    protected void Is_ReceiverFound(FCk_Handle InHandle, FCk_SharedBool OutResult, FInstancedStruct InPayload)
    {
        auto Result = OutResult;
        Result.Set(Get_IsReceiverFound());
    }

    // This machine's copy of the pawn near the base has composed its gameplay entity; from then its state machine's
    // entries are recorded, and the receiver is taken as soon as it is there.
    protected bool Get_IsPawnComposed()
    {
        if (ck::Is_NOT_Valid(_Pawn))
        { _Pawn = DoFind_PawnNear(_Base); }

        if (ck::Is_NOT_Valid(_Pawn))
        { return false; }

        if (ck::Is_NOT_Valid(_Player))
        { _Player = _Pawn.Get_GameplayComposedEntity(); }

        if (ck::Is_NOT_Valid(_Player))
        { return false; }

        Bind_StateMachine();
        TryBind_Receiver();
        return true;
    }

    // The pawn's copy is composed with a Health and a zone; the first time, its Health's signals are recorded from here.
    protected bool Get_IsReceiverFound()
    {
        return Get_IsPawnComposed() && ck::IsValid(_Health);
    }

    // Called once the pawn's copy is composed: the receiver composes with the entity, so its absence ends the row.
    protected bool Require_Receiver(FString InRow)
    {
        if (ck::IsValid(_Health))
        { return true; }

        Log_Row(InRow, "receiver=missing");
        FinishFailure(f"the {Get_MachineName()}'s copy of the pawn composed without a Health and a zone");
        return false;
    }

    private void TryBind_Receiver()
    {
        if (ck::IsValid(_Health))
        { return; }

        auto Health = _Player.As_Health(ECk_SanityCheck::UnChecked);
        auto Zone = _Player.As_HitZone(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(Health) || ck::Is_NOT_Valid(Zone))
        { return; }

        _Zone = Zone;
        _Health = Health;
        _Health.BindTo_OnDamaged(FMars_Delegate_Health_OnDamaged(this, n"OnHealthDamaged"));
        _Health.BindTo_OnHealed(FMars_Delegate_Health_OnHealed(this, n"OnHealthHealed"));
        _Health.BindTo_OnDepleted(FMars_Delegate_Health_OnDepleted(this, n"OnHealthDepleted"));
    }

    // The AMars_PlayerCharacter in this machine's world nearest InSpot, within k_NearCm; null without one.
    protected AMars_PlayerCharacter DoFind_PawnNear(FVector InSpot)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Pawns = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(AMars_PlayerCharacter, Pawns);

        AMars_PlayerCharacter Found;
        auto Nearest = k_NearCm;
        for (auto Actor : Pawns)
        {
            if (ck::Is_NOT_Valid(Actor))
            { continue; }

            const auto Distance = (Actor.GetActorLocation() - InSpot).Size();
            if (Distance >= Nearest)
            { continue; }

            Found = Cast<AMars_PlayerCharacter>(Actor);
            Nearest = Distance;
        }

        return Found;
    }

    // The zone's one registered hurtbox on this machine; invalid without exactly one.
    protected FCk_Handle Get_Hurtbox()
    {
        if (ck::Is_NOT_Valid(_Zone))
        { return FCk_Handle(); }

        const auto Hurtboxes = _Zone.Get_Hurtboxes();
        return Hurtboxes.Num() == 1 ? Hurtboxes[0] : FCk_Handle();
    }

    protected bool Get_HasCombatTargetTag()
    {
        return ck::IsValid(_Player) && utils_entity_tag::Has(_Player, n"TAG_MarsCombatTarget");
    }

    protected bool Get_IsInState(TSubclassOf<UCk_SmState_EntityScript> InState)
    {
        return ck::IsValid(_Sm) && utils_state_machine::IsInState(_Sm, InState);
    }

    protected bool Get_IsCurrent(float32 InExpected)
    {
        return ck::IsValid(_Health) && Math::IsNearlyEqual(_Health.Get_Current(), InExpected, 0.01f);
    }

    // This machine's Health ledger; a default one before the receiver is found.
    protected FMars_Fragment_Health_Net Get_Ledger()
    {
        if (ck::Is_NOT_Valid(_Health))
        { return FMars_Fragment_Health_Net(); }

        return _Health.Get_Fragment(FMars_Fragment_Health_Net);
    }

    // InAmount of InDamageType straight onto this machine's copy of the zone.
    protected void Request_ZoneHit(float32 InAmount, FGameplayTag InDamageType)
    {
        _Zone.Request_Hit(FMars_Request_HitZone_Hit(FMars_DamageEvent(InAmount, InDamageType)));
    }

    // Server: hands the pawn to the one player controller in its world that is not local, found by a scan of the world's
    // player controllers. False (nothing possessed) without exactly one.
    protected bool Request_ServerPossessByRemote(APawn InPawn)
    {
        const auto WorldContext = FAngelscriptGameThreadScopeWorldContext(Get_TestWorld());
        auto Controllers = TArray<AActor>();
        Gameplay::GetAllActorsOfClass(APlayerController, Controllers);

        APlayerController Remote;
        auto Count = 0;
        for (auto Actor : Controllers)
        {
            auto Controller = Cast<APlayerController>(Actor);
            if (ck::Is_NOT_Valid(Controller) || Controller.IsLocalController())
            { continue; }

            Remote = Controller;
            Count += 1;
        }

        if (Count != 1)
        { return false; }

        _RemoteController = Remote;
        _RemotePreviousPawn = Remote.GetControlledPawn();
        Remote.Possess(InPawn);
        return true;
    }

    // Server: the remote controller gets its old pawn back. Safe to call twice.
    protected void Request_ServerReturnRemote()
    {
        if (ck::Is_NOT_Valid(_RemoteController))
        { return; }

        const auto Controlled = _RemoteController.GetControlledPawn();
        if (ck::IsValid(Controlled) && (Controlled == _Pawn || Controlled == _Viewer))
        { _RemoteController.UnPossess(); }

        if (ck::IsValid(_RemotePreviousPawn) && _RemoteController.GetControlledPawn() != _RemotePreviousPawn)
        { _RemoteController.Possess(_RemotePreviousPawn); }

        _RemoteController = nullptr;
    }

    // The row's one log line on this machine.
    protected void Log_Row(FString InRow, FString InExtra)
    {
        const auto Ledger = Get_Ledger();
        const auto IsFound = ck::IsValid(_Health);
        const auto Current = IsFound ? _Health.Get_Current() : -1.0f;
        const auto IsDepleted = IsFound && _Health.Get_IsDepleted();
        const auto Hurtboxes = ck::IsValid(_Zone) ? _Zone.Get_Hurtboxes().Num() : -1;
        const auto HasAuthority = ck::IsValid(_Player) && utils_net::Get_HasAuthority(_Player);
        const auto IsLocal = ck::IsValid(_Pawn) && _Pawn.IsLocallyControlled();
        const auto Line = f"[PlayerCombatNetTest] {InRow} {Get_MachineName()} current={Current} depleted={IsDepleted} hurtboxes={Hurtboxes} tag={Get_HasCombatTargetTag()} authority={HasAuthority} local={IsLocal} damaged={_Damaged.Num()} healed={_Healed} depletedSignals={_Depleted} downedEntries={_DownedEntries} aliveEntries={_AliveEntries} ledger=[cur {Ledger.Current} d{Ledger.DamageSerial} h{Ledger.HealSerial} x{Ledger.DepletionSerial}] ensures={Get_NewEnsures()} {InExtra}";
        Log(Line);
    }

    // Server: the hold is over; the remote controller goes back to its old pawn and the pawns and floor go.
    UFUNCTION()
    protected void OnServerHeld(FCk_Handle_Timer InTimer, FCk_Chrono InChrono, FCk_Time InDeltaT)
    {
        TearDown();
        FinishSuccess();
    }

    protected void TearDown()
    {
        Request_ServerReturnRemote();
        if (_IsServerPawn && ck::IsValid(_Pawn))
        { _Pawn.DestroyActor(); }

        if (_IsServerViewer && ck::IsValid(_Viewer))
        { _Viewer.DestroyActor(); }

        if (ck::IsValid(_Floor))
        { _Floor.DestroyActor(); }

        _Floor = nullptr;
        _IsServerPawn = false;
        _IsServerViewer = false;
    }

    UFUNCTION(BlueprintOverride)
    void DoEndPlay(FCk_Handle InHandle)
    {
        TearDown();
    }

    private void Bind_StateMachine()
    {
        if (_StateChangesBound)
        { return; }

        _Sm = _Player.As_StateMachine(ECk_SanityCheck::UnChecked);
        if (ck::Is_NOT_Valid(_Sm))
        { return; }

        utils_state_machine::BindTo_OnStateChanged(_Sm, FCk_Delegate_Sm_OnStateChanged(this, n"OnStateChanged"));
        _StateChangesBound = true;
    }

    UFUNCTION()
    private void OnStateChanged(FCk_Handle_StateMachine InStateMachine, FCk_Sm_Payload_OnStateChanged InPayload)
    {
        const auto NewState = InPayload.Get_NewStateClass();
        if (NewState == UMars_SmState_Downed)
        {
            _DownedEntries += 1;
            _DownedFrame = int32(utils_time::Get_FrameCounter());
        }
        else if (NewState == UMars_SmState_Alive)
        {
            _AliveEntries += 1;
            _AliveFrame = int32(utils_time::Get_FrameCounter());
        }
    }

    UFUNCTION()
    private void OnHealthDamaged(FCk_Handle_Health InHealth, FMars_DamageEvent InEvent, float32 InApplied, float32 InRemaining)
    {
        _Damaged.Add(InApplied);
    }

    UFUNCTION()
    private void OnHealthHealed(FCk_Handle_Health InHealth, float32 InApplied, float32 InRemaining)
    {
        _Healed += 1;
    }

    UFUNCTION()
    private void OnHealthDepleted(FCk_Handle_Health InHealth, FMars_DamageEvent InCause)
    {
        _Depleted += 1;
    }
}
